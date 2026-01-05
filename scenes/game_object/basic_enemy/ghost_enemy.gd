extends BaseEnemy

const GHOST_WANDER_MIN_DURATION := 1.2
const GHOST_WANDER_MAX_DURATION := 2.4
const GHOST_FADE_SPEED := 1.0
const GHOST_POSSESSION_RADIUS := 28.0
const GHOST_POSSESSION_SEEK_RADIUS := 200.0
const GHOST_POSSESSION_DURATION := 8.0
const GHOST_POSSESSION_COOLDOWN := 1.0
const GHOST_OFFSCREEN_RESPAWN_DELAY := 2.5
const GHOST_RESPAWN_FADE_SPEED := 1.5

var ghost_wander_time_left := 0.0
var ghost_wander_direction := Vector2.ZERO
var ghost_fade_time := 0.0
var ghost_offscreen_time := 0.0
var ghost_respawn_fade := 1.0
var ghost_possession_target: Node2D
var ghost_possession_time_left := 0.0
var ghost_possession_cooldown := 0.0

func _ready():
	super()
	set_sprite_visibility(ghost_sprite)
	set_active_sprite(ghost_sprite)
	fireball_ability_controller.set_active(false)
	dig_ability_controller.set_active(false)
	add_to_group("ghost")
	collision_layer = 0
	collision_mask = 0


func _physics_process(delta):
	update_ghost_state(delta)
	update_possession_timer(delta)


func can_be_possessed() -> bool:
	return false


func is_invulnerable() -> bool:
	return ghost_possession_target != null


func update_ghost_state(delta: float) -> void:
	update_ghost_fade(delta)
	ghost_possession_cooldown = max(ghost_possession_cooldown - delta, 0.0)
	if ghost_possession_target != null:
		if not is_instance_valid(ghost_possession_target):
			end_ghost_possession(true, true)
			return
		ghost_possession_time_left = max(ghost_possession_time_left - delta, 0.0)
		global_position = ghost_possession_target.global_position
		if ghost_possession_time_left <= 0.0:
			end_ghost_possession()
		return

	update_ghost_offscreen(delta)
	if ghost_possession_cooldown > 0.0:
		update_ghost_wander(delta)
		velocity_component.move(self)
		update_visual_facing()
		return

	if try_start_ghost_possession():
		return

	update_ghost_seek(delta)
	velocity_component.move(self)
	update_visual_facing()


func update_ghost_fade(delta: float) -> void:
	if ghost_sprite == null:
		return
	if ghost_possession_target != null:
		visuals.modulate.a = 0.0
		return
	ghost_fade_time += delta * GHOST_FADE_SPEED
	var alpha = 0.3 + (sin(ghost_fade_time) * 0.3)
	if ghost_respawn_fade < 1.0:
		ghost_respawn_fade = min(ghost_respawn_fade + (delta * GHOST_RESPAWN_FADE_SPEED), 1.0)
	visuals.modulate.a = alpha * ghost_respawn_fade


func update_ghost_offscreen(delta: float) -> void:
	var view_rect := get_camera_view_rect()
	if view_rect.has_point(global_position):
		ghost_offscreen_time = 0.0
		return
	ghost_offscreen_time += delta
	if ghost_offscreen_time < GHOST_OFFSCREEN_RESPAWN_DELAY:
		return
	respawn_ghost_on_screen(view_rect)
	ghost_offscreen_time = 0.0


func respawn_ghost_on_screen(view_rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spawn_x = rng.randf_range(view_rect.position.x, view_rect.position.x + view_rect.size.x)
	var spawn_y = rng.randf_range(view_rect.position.y, view_rect.position.y + view_rect.size.y)
	global_position = Vector2(spawn_x, spawn_y)
	ghost_fade_time = 0.0
	ghost_respawn_fade = 0.0


func get_camera_view_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var viewport_size := get_viewport_rect().size
	if camera == null:
		return Rect2(Vector2.ZERO, viewport_size)
	var half_size := viewport_size * camera.zoom * 0.5
	var min_position := camera.global_position - half_size
	return Rect2(min_position, half_size * 2.0)


func update_ghost_wander(delta: float) -> void:
	ghost_wander_time_left = max(ghost_wander_time_left - delta, 0.0)
	if ghost_wander_time_left <= 0.0 or ghost_wander_direction == Vector2.ZERO:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var angle = rng.randf_range(0.0, TAU)
		ghost_wander_direction = Vector2(cos(angle), sin(angle))
		ghost_wander_time_left = rng.randf_range(GHOST_WANDER_MIN_DURATION, GHOST_WANDER_MAX_DURATION)
	velocity_component.accelerate_in_direction(ghost_wander_direction)


func update_ghost_seek(delta: float) -> void:
	var target = find_nearby_possession_target(GHOST_POSSESSION_SEEK_RADIUS)
	if target != null:
		var direction = target.global_position - global_position
		if direction.length_squared() > 0.001:
			velocity_component.accelerate_in_direction(direction.normalized())
		return
	update_ghost_wander(delta)


func try_start_ghost_possession() -> bool:
	if ghost_possession_cooldown > 0.0:
		return false
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and global_position.distance_to(player.global_position) <= GHOST_POSSESSION_RADIUS:
		if player.has_method("start_ghost_possession"):
			player.call("start_ghost_possession", GHOST_POSSESSION_DURATION, velocity_component.max_speed)
			start_ghost_possession(player, GHOST_POSSESSION_DURATION)
			return true

	var nearest_enemy = find_nearby_enemy_to_possess()
	if nearest_enemy != null:
		nearest_enemy.call("start_enemy_possession", GHOST_POSSESSION_DURATION)
		start_ghost_possession(nearest_enemy, GHOST_POSSESSION_DURATION)
		return true
	return false


func find_nearby_enemy_to_possess() -> Node2D:
	var closest_enemy: Node2D
	var closest_distance := GHOST_POSSESSION_RADIUS
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self:
			continue
		if enemy.is_in_group("ghost"):
			continue
		if enemy.has_method("can_be_possessed") and not enemy.call("can_be_possessed"):
			continue
		var enemy_node = enemy as Node2D
		if enemy_node == null:
			continue
		var distance = global_position.distance_to(enemy_node.global_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_enemy = enemy_node
	return closest_enemy


func find_nearby_possession_target(radius: float) -> Node2D:
	var closest_target: Node2D
	var closest_distance := radius
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.has_method("start_ghost_possession"):
		var distance = global_position.distance_to(player.global_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_target = player

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self:
			continue
		if enemy.is_in_group("ghost"):
			continue
		if enemy.has_method("can_be_possessed") and not enemy.call("can_be_possessed"):
			continue
		var enemy_node = enemy as Node2D
		if enemy_node == null:
			continue
		var enemy_distance = global_position.distance_to(enemy_node.global_position)
		if enemy_distance <= closest_distance:
			closest_distance = enemy_distance
			closest_target = enemy_node
	return closest_target


func start_ghost_possession(target: Node2D, duration: float) -> void:
	ghost_possession_target = target
	ghost_possession_time_left = duration
	visuals.modulate.a = 0.0
	ghost_offscreen_time = 0.0


func end_ghost_possession(force_peak_visibility: bool = false, start_cooldown: bool = false) -> void:
	ghost_possession_target = null
	ghost_possession_time_left = 0.0
	if start_cooldown:
		ghost_possession_cooldown = GHOST_POSSESSION_COOLDOWN
	respawn_ghost_on_screen(get_camera_view_rect())
	ghost_offscreen_time = 0.0
	if force_peak_visibility:
		ghost_fade_time = PI * 0.5
		ghost_respawn_fade = 1.0
		update_ghost_fade(0.0)
