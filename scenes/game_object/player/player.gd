extends CharacterBody2D

const MAX_SPEED = 125
const ACCELERATION_SMOOTHING = 25
const DAMAGE_FLASH_DURATION = 0.45
const EXPERIENCE_FLASH_DURATION = 0.1
const AIM_DEADZONE = 0.1
const AIM_LASER_LENGTH = 240.0
const NEAR_DEATH_RED = Color(1.0, 0.1, 0.1)

@onready var damage_interval_timer = $DamageIntervalTimer
@onready var health_component = $HealthComponent
@onready var health_bar = $HealthBar
@onready var upgrade_dots = $UpgradeDots
@onready var abilities = $Abilities
@onready var animation_player = $AnimationPlayer
@onready var visuals = $Visuals
@onready var player_sprite: AnimatedSprite2D = $Visuals/player_sprite
@onready var player_color = $Visuals/player_sprite/player_color
@onready var near_death_flash = $Visuals/player_sprite/NearDeathFlash
@onready var velocity_component = $VelocityComponent
@onready var aim_laser: Line2D = $AimLaser
@onready var player_collision_shape: CollisionShape2D = $CollisionShape2D

@export var player_number := 1
@export var regen_rate := 0.67
@export var near_death_hit_points := 2.0
@export var near_death_flash_speed := 6.0
@export var explosion_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")

signal regenerate_started
signal regenerate_finished

var floating_text_scene = preload("res://scenes/ui/floating_text.tscn")

var colliding_enemies: Dictionary = {}
var base_speed := 0
var base_max_health := 0.0
var base_health_bar_width := 0.0
var base_health_bar_left := 0.0
var is_regenerating := false
var normal_visuals_modulate := Color.WHITE
var last_health := 0.0
var flash_tween: Tween
var near_death_time := 0.0
var has_defeat_visuals := false

const UPGRADE_DOT_SIZE := 4.0
const UPGRADE_DOT_RADIUS := 2


func _ready():
	base_speed = velocity_component.max_speed
	base_max_health = health_component.max_health
	base_health_bar_width = health_bar.custom_minimum_size.x
	base_health_bar_left = health_bar.offset_left
	player_color.color = get_player_tint()
	player_color.visible = true
	if near_death_flash != null:
		near_death_flash.visible = false
	aim_laser.visible = false
	_update_aim_laser_color()
	visuals.modulate = Color.WHITE
	normal_visuals_modulate = visuals.modulate
	last_health = health_component.current_health
	
	$hurtbox.body_entered.connect(on_body_entered)
	$hurtbox.body_exited.connect(on_body_exited)
	damage_interval_timer.timeout.connect(on_damage_interval_timer_timeout)
	health_component.health_changed.connect(on_health_changed)
	health_component.died.connect(on_died)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)
	for ability in abilities.get_children():
		if ability.has_method("set_player_number"):
			ability.set_player_number(player_number)
	update_health_bar_size()
	update_health_display()
	set_upgrade_dot_count(0)
	call_deferred("_restore_persisted_state")


func _process(delta):
	if is_regenerating:
		stop_near_death_flash()
		velocity_component.velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		animation_player.play("RESET")
		aim_laser.visible = false
		health_component.heal(regen_rate * delta)
		if health_component.current_health >= health_component.max_health:
			end_regeneration()
		return

	var movement_vector = get_movement_vector()
	var direction = movement_vector.normalized()
	velocity_component.accelerate_in_direction(direction)
	velocity_component.move(self)
	_clamp_to_camera_bounds()
	
	if movement_vector.x != 0 || movement_vector.y != 0:
		animation_player.play("walk")
	else:
		animation_player.play("RESET")
	
	var move_sign = sign(movement_vector.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign, 1)
	_update_aim_laser()
	_update_near_death_flash(delta)


func _clamp_to_camera_bounds() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var viewport_size := get_viewport_rect().size
	var half_size := viewport_size * camera.zoom * 0.5
	var padding := _get_collision_padding()
	var min_position := camera.global_position - half_size + Vector2(padding, padding)
	var max_position := camera.global_position + half_size - Vector2(padding, padding)
	global_position = global_position.clamp(min_position, max_position)


func _get_collision_padding() -> float:
	if player_collision_shape == null:
		return 0.0
	var shape = player_collision_shape.shape
	if shape is CircleShape2D:
		return shape.radius
	if shape is RectangleShape2D:
		return max(shape.size.x, shape.size.y) * 0.5
	return 0.0


func get_movement_vector():	
	var suffix = get_player_action_suffix()
	var x_movement = Input.get_action_strength("move_right" + suffix) - Input.get_action_strength("move_left" + suffix)
	var y_movement = Input.get_action_strength("move_down" + suffix) - Input.get_action_strength("move_up" + suffix)
	
	return Vector2(x_movement, y_movement)

func get_aim_direction() -> Vector2:
	var suffix = get_player_action_suffix()
	var x_aim = Input.get_action_strength("aim_right" + suffix) - Input.get_action_strength("aim_left" + suffix)
	var y_aim = Input.get_action_strength("aim_down" + suffix) - Input.get_action_strength("aim_up" + suffix)
	var aim_vector = Vector2(x_aim, y_aim)
	if aim_vector.length() < AIM_DEADZONE:
		return Vector2.ZERO
	return aim_vector.normalized()


func get_player_action_suffix() -> String:
	return "" if player_number <= 1 else str(player_number)


func get_player_tint() -> Color:
	return GameEvents.get_player_color(player_number)


func get_persisted_state() -> Dictionary:
	return {
		"current_health": health_component.current_health,
		"max_health": health_component.max_health,
	}


func _restore_persisted_state() -> void:
	await get_tree().process_frame
	var persisted_state = GameEvents.get_player_state(player_number)
	if persisted_state.is_empty():
		return
	if persisted_state.has("max_health"):
		health_component.max_health = float(persisted_state["max_health"])
	if persisted_state.has("current_health"):
		health_component.current_health = min(float(persisted_state["current_health"]), health_component.max_health)
	update_health_bar_size()
	last_health = health_component.current_health
	health_component.health_changed.emit()


func can_attack() -> bool:
	return not is_regenerating


func _update_aim_laser() -> void:
	var aim_direction = get_aim_direction()
	if aim_direction == Vector2.ZERO:
		aim_laser.visible = false
		return
	aim_laser.visible = true
	aim_laser.points = PackedVector2Array([Vector2.ZERO, aim_direction * AIM_LASER_LENGTH])


func _update_aim_laser_color() -> void:
	var laser_color = get_player_tint()
	laser_color.a = 0.8
	aim_laser.default_color = laser_color


func check_deal_damage():
	if is_regenerating:
		return
	if colliding_enemies.is_empty() || !damage_interval_timer.is_stopped():
		return
	var contact_damage = get_contact_damage()
	if contact_damage <= 0:
		return
	health_component.damage(contact_damage)
	damage_interval_timer.start()


func update_health_display():
	health_bar.value = health_component.get_health_percent()

func update_health_bar_size() -> void:
	if health_bar == null or base_max_health <= 0.0:
		return
	var health_ratio: float = float(health_component.max_health) / base_max_health
	var width: float = max(base_health_bar_width, base_health_bar_width * health_ratio)
	health_bar.custom_minimum_size.x = width
	health_bar.offset_left = base_health_bar_left
	health_bar.offset_right = base_health_bar_left + width
	health_bar.pivot_offset = Vector2(width * 0.5, health_bar.pivot_offset.y)

#---------------------------------------------


func on_body_entered(other_body: Node2D):
	if other_body == null or not other_body.is_in_group("enemy"):
		return
	var contact_damage = other_body.get("contact_damage")
	var resolved_damage := 1.0
	if typeof(contact_damage) in [TYPE_INT, TYPE_FLOAT]:
		resolved_damage = float(contact_damage)
	colliding_enemies[other_body] = resolved_damage
	check_deal_damage()


func on_body_exited(other_body: Node2D):
	if colliding_enemies.has(other_body):
		colliding_enemies.erase(other_body)


func on_damage_interval_timer_timeout():
	check_deal_damage()


func get_contact_damage() -> float:
	var max_damage := 0.0
	for damage_value in colliding_enemies.values():
		max_damage = max(max_damage, float(damage_value))
	return max_damage


func on_health_changed():
	if not is_regenerating and health_component.current_health < last_health:
		spawn_damage_text(last_health - health_component.current_health)
		GameEvents.emit_player_damaged()
		$HitRandomStreamPlayer.play_random()
		flash_visuals(Color(1, 0.3, 0.3))
	elif not is_regenerating and health_component.current_health > last_health:
		flash_visuals(Color(0.3, 1, 0.3))
	update_health_display()
	last_health = health_component.current_health


func spawn_damage_text(damage_amount: float) -> void:
	if damage_amount <= 0:
		return
	var floating_text = floating_text_scene.instantiate() as FloatingText
	get_tree().get_first_node_in_group("foreground_layer").add_child(floating_text)

	floating_text.global_position = global_position + (Vector2.UP * 16)

	var fmt_string := "%0.1f"
	if is_equal_approx(damage_amount, int(damage_amount)):
		fmt_string = "%0.0f"
	floating_text.start(fmt_string % damage_amount, Color(1, 0.3, 0.3))


func on_died():
	if is_regenerating:
		return
	is_regenerating = true
	stop_flash()
	stop_near_death_flash()
	visuals.modulate = Color.BLACK
	if GameEvents.player_count <= 1:
		trigger_defeat_visuals()
	else:
		aim_laser.visible = false
	health_component.current_health = 0
	health_component.health_changed.emit()
	damage_interval_timer.stop()
	regenerate_started.emit()


func end_regeneration():
	is_regenerating = false
	stop_flash()
	stop_near_death_flash()
	visuals.modulate = normal_visuals_modulate
	visuals.visible = true
	health_bar.visible = true
	upgrade_dots.visible = true
	aim_laser.visible = false
	health_component.current_health = health_component.max_health
	health_component.health_changed.emit()
	last_health = health_component.current_health
	regenerate_finished.emit()

func trigger_defeat_visuals() -> void:
	if has_defeat_visuals:
		return
	has_defeat_visuals = true
	spawn_explosion()
	stop_flash()
	stop_near_death_flash()
	visuals.visible = false
	health_bar.visible = false
	upgrade_dots.visible = false
	aim_laser.visible = false


func continue_from_defeat() -> void:
	has_defeat_visuals = false
	is_regenerating = false
	stop_flash()
	stop_near_death_flash()
	visuals.modulate = normal_visuals_modulate
	visuals.visible = true
	health_bar.visible = true
	upgrade_dots.visible = true
	aim_laser.visible = false
	velocity = Vector2.ZERO
	velocity_component.velocity = Vector2.ZERO
	health_component.current_health = health_component.max_health
	health_component.health_changed.emit()
	last_health = health_component.current_health


func spawn_explosion() -> void:
	if explosion_scene == null:
		return
	var explosion_instance = explosion_scene.instantiate() as GPUParticles2D
	if explosion_instance == null:
		return
	explosion_instance.global_position = global_position
	explosion_instance.emitting = true
	explosion_instance.finished.connect(explosion_instance.queue_free)
	var effects_layer = get_tree().get_first_node_in_group("effects_layer")
	var spawn_parent = effects_layer if effects_layer != null else get_tree().current_scene
	if spawn_parent == null:
		return
	spawn_parent.add_child(explosion_instance)


func on_ability_upgrade_added(ability_upgrade: AbilityUpgrade, current_upgrades: Dictionary, upgrade_player_number: int):
	if upgrade_player_number != player_number:
		return
	if ability_upgrade is Ability:
		var ability = ability_upgrade as Ability
		if not _has_ability_controller(ability.ability_controller_scene):
			var ability_controller = ability.ability_controller_scene.instantiate()
			if ability_controller.has_method("set_player_number"):
				ability_controller.set_player_number(player_number)
			abilities.add_child(ability_controller)
	elif ability_upgrade.id == "player_speed":
		velocity_component.max_speed = base_speed + (base_speed * current_upgrades["player_speed"]["quantity"] * 0.2)
	elif ability_upgrade.id == "player_health":
		health_component.max_health = base_max_health + (current_upgrades["player_health"]["quantity"] * 8.0)
		health_component.heal(8.0)
		update_health_bar_size()
	update_upgrade_dots(current_upgrades)


func _has_ability_controller(ability_scene: PackedScene) -> bool:
	if ability_scene == null:
		return false
	var scene_path = ability_scene.resource_path
	if scene_path.is_empty():
		return false
	for child in abilities.get_children():
		if child.scene_file_path == scene_path:
			return true
	return false


func update_upgrade_dots(current_upgrades: Dictionary) -> void:
	var total_upgrades := 0
	for upgrade_data in current_upgrades.values():
		if typeof(upgrade_data) == TYPE_DICTIONARY and upgrade_data.has("quantity"):
			total_upgrades += int(upgrade_data["quantity"])
	set_upgrade_dot_count(total_upgrades)


func set_upgrade_dot_count(count: int) -> void:
	if upgrade_dots == null:
		return
	for child in upgrade_dots.get_children():
		child.queue_free()
	if count <= 0:
		return
	var dot_color = get_player_tint()
	for i in range(count):
		var dot = Panel.new()
		dot.custom_minimum_size = Vector2(UPGRADE_DOT_SIZE, UPGRADE_DOT_SIZE)
		var dot_style = StyleBoxFlat.new()
		dot_style.bg_color = dot_color
		dot_style.set_corner_radius_all(UPGRADE_DOT_RADIUS)
		dot.add_theme_stylebox_override("panel", dot_style)
		upgrade_dots.add_child(dot)


func flash_visuals(color: Color, duration: float = DAMAGE_FLASH_DURATION) -> void:
	stop_flash()
	visuals.modulate = color
	flash_tween = create_tween()
	flash_tween.tween_property(visuals, "modulate", normal_visuals_modulate, duration) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)


func stop_flash() -> void:
	if flash_tween != null and flash_tween.is_running():
		flash_tween.kill()


func _update_near_death_flash(delta: float) -> void:
	if near_death_flash == null or health_component == null:
		return
	if health_component.current_health <= 0:
		stop_near_death_flash()
		return
	if health_component.current_health > near_death_hit_points:
		stop_near_death_flash()
		return
	near_death_flash.visible = true
	if near_death_flash.sprite_frames != player_sprite.sprite_frames:
		near_death_flash.sprite_frames = player_sprite.sprite_frames
	if near_death_flash.animation != player_sprite.animation:
		near_death_flash.play(player_sprite.animation)
	near_death_flash.frame = player_sprite.frame
	near_death_flash.frame_progress = player_sprite.frame_progress
	near_death_time += delta * near_death_flash_speed
	var pulse = (sin(near_death_time * TAU) + 1.0) * 0.5
	var flash_color = NEAR_DEATH_RED.lerp(Color.WHITE, pulse)
	flash_color.a = 0.5
	var flash_material := near_death_flash.material as ShaderMaterial
	if flash_material != null:
		flash_material.set_shader_parameter("flash_color", flash_color)


func stop_near_death_flash() -> void:
	if near_death_flash == null:
		return
	near_death_flash.visible = false
	near_death_flash.stop()
	near_death_time = 0.0


func flash_experience_gain() -> void:
	flash_visuals(Color(0.3, 0.6, 1.0), EXPERIENCE_FLASH_DURATION)
