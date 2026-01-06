extends BaseEnemy

const SPIDER_BURST_DURATION := 0.3
const SPIDER_REST_DURATION := 1.2
const SPIDER_STOP_DECELERATION := 600.0
const SPIDER_JUMP_RANGE := 150.0
const SPIDER_JUMP_COOLDOWN := 1.1
const SPIDER_JUMP_FORCE := 400.0
const SPIDER_JUMP_WINDUP_DURATION := 0.2
const SPIDER_JUMP_BLINK_SPEED := 8.0

var spider_burst_time_left := 0.0
var spider_rest_time_left := 0.0
var spider_jump_cooldown := 0.0
var spider_jump_windup_left := 0.0
var spider_jump_blink_time := 0.0
var spider_jump_direction := Vector2.ZERO

func _ready():
	super._ready()
	set_sprite_visibility(spider_sprite)
	set_active_sprite(spider_sprite)
	fireball_ability_controller.set_active(false)
	dig_ability_controller.set_active(false)


func _physics_process(delta):
	update_spider_movement(delta)
	apply_enemy_separation()
	velocity_component.move(self)
	update_visual_facing()
	update_possession_timer(delta)


func update_spider_movement(delta: float) -> void:
	spider_jump_cooldown = max(spider_jump_cooldown - delta, 0.0)
	if spider_jump_windup_left > 0.0:
		spider_jump_windup_left = max(spider_jump_windup_left - delta, 0.0)
		spider_jump_blink_time += delta
		update_spider_jump_blink()
		velocity_component.velocity = velocity_component.velocity.move_toward(
			Vector2.ZERO,
			SPIDER_STOP_DECELERATION * delta
		)
		if spider_jump_windup_left <= 0.0:
			execute_spider_jump()
		return
	if spider_rest_time_left > 0.0:
		spider_rest_time_left = max(spider_rest_time_left - delta, 0.0)
		velocity_component.velocity = velocity_component.velocity.move_toward(
			Vector2.ZERO,
			SPIDER_STOP_DECELERATION * delta
		)
		return

	if spider_burst_time_left > 0.0:
		spider_burst_time_left = max(spider_burst_time_left - delta, 0.0)
		accelerate_to_player_with_pathfinding()
		if spider_burst_time_left <= 0.0:
			spider_rest_time_left = SPIDER_REST_DURATION
		return

	start_spider_burst()


func start_spider_burst() -> void:
	var target_player := velocity_component.cached_player
	if target_player == null:
		velocity_component.refresh_target_player(global_position)
		target_player = velocity_component.cached_player
	if target_player == null:
		spider_burst_time_left = SPIDER_BURST_DURATION
		return
	if can_spider_jump(target_player):
		start_spider_jump_windup(target_player)
		return
	spider_burst_time_left = SPIDER_BURST_DURATION


func can_spider_jump(target_player: Node2D) -> bool:
	if spider_jump_cooldown > 0.0:
		return false
	return global_position.distance_to(target_player.global_position) <= SPIDER_JUMP_RANGE


func start_spider_jump_windup(target_player: Node2D) -> void:
	spider_jump_direction = (target_player.global_position - global_position).normalized()
	spider_jump_windup_left = SPIDER_JUMP_WINDUP_DURATION
	spider_jump_blink_time = 0.0
	update_spider_jump_blink()


func execute_spider_jump() -> void:
	update_spider_jump_blink_strength(0.0)
	if spider_jump_direction == Vector2.ZERO:
		spider_rest_time_left = SPIDER_REST_DURATION
		return
	velocity_component.apply_knockback(spider_jump_direction, SPIDER_JUMP_FORCE)
	spider_jump_cooldown = SPIDER_JUMP_COOLDOWN
	spider_rest_time_left = SPIDER_REST_DURATION


func update_spider_jump_blink() -> void:
	var blink_value := 0.5 + 0.5 * sin(spider_jump_blink_time * TAU * SPIDER_JUMP_BLINK_SPEED)
	update_spider_jump_blink_strength(blink_value)


func update_spider_jump_blink_strength(strength: float) -> void:
	if spider_sprite == null:
		return
	var blink_material := spider_sprite.material as ShaderMaterial
	if blink_material == null:
		return
	blink_material.set_shader_parameter("lerp_percent", strength)
