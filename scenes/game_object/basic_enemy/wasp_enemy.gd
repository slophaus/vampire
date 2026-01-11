extends BaseEnemy

const WASP_WANDER_MIN_DURATION := 0.6
const WASP_WANDER_MAX_DURATION := 1.4
const WASP_STING_RANGE := 70.0
const WASP_STING_COOLDOWN := 1.2
const WASP_STING_FORCE := 450.0
const WASP_STING_WINDUP_DURATION := 0.8
const WASP_STING_RECOVER_DURATION := 1.5
const WASP_STOP_DECELERATION := 450.0

enum WaspState {
	NORMAL,
	STING_WINDUP,
	STING_RECOVER,
}

var current_state := WaspState.NORMAL
var wasp_wander_time_left := 0.0
var wasp_wander_direction := Vector2.ZERO
var wasp_sting_cooldown := 0.0
var wasp_sting_windup_left := 0.0
var wasp_sting_recover_left := 0.0
var wasp_sting_direction := Vector2.ZERO


func _ready():
	super._ready()
	set_sprite_visibility(wasp_sprite)
	set_active_sprite(wasp_sprite)
	fireball_ability_controller.set_active(false)
	dig_ability_controller.set_active(false)
	poison_spit_ability_controller.set_active(false)
	change_state(WaspState.NORMAL)


func _physics_process(delta):
	update_wasp_state(delta)
	apply_enemy_separation()
	velocity_component.move(self)
	update_visual_facing()
	update_possession_timer(delta)


func update_wasp_state(delta: float) -> void:
	wasp_sting_cooldown = max(wasp_sting_cooldown - delta, 0.0)
	match current_state:
		WaspState.STING_WINDUP:
			update_wasp_sting_windup(delta)
		WaspState.STING_RECOVER:
			update_wasp_sting_recover(delta)
		WaspState.NORMAL:
			update_wasp_normal(delta)


func update_wasp_normal(delta: float) -> void:
	update_wasp_wander(delta)
	accelerate_to_player_with_pathfinding()
	if can_start_wasp_sting():
		start_wasp_sting_windup()


func update_wasp_wander(delta: float) -> void:
	wasp_wander_time_left = max(wasp_wander_time_left - delta, 0.0)
	if wasp_wander_time_left <= 0.0 or wasp_wander_direction == Vector2.ZERO:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var angle = rng.randf_range(0.0, TAU)
		wasp_wander_direction = Vector2(cos(angle), sin(angle))
		wasp_wander_time_left = rng.randf_range(WASP_WANDER_MIN_DURATION, WASP_WANDER_MAX_DURATION)
	velocity_component.accelerate_in_direction(wasp_wander_direction)


func can_start_wasp_sting() -> bool:
	if wasp_sting_cooldown > 0.0:
		return false
	var target_player := velocity_component.cached_player
	if target_player == null:
		velocity_component.refresh_target_player(global_position)
		target_player = velocity_component.cached_player
	if target_player == null:
		return false
	return global_position.distance_to(target_player.global_position) <= WASP_STING_RANGE


func start_wasp_sting_windup() -> void:
	var target_player := velocity_component.cached_player
	if target_player != null:
		wasp_sting_direction = (target_player.global_position - global_position).normalized()
	change_state(WaspState.STING_WINDUP)


func update_wasp_sting_windup(delta: float) -> void:
	var target_player := velocity_component.cached_player
	if target_player != null:
		wasp_sting_direction = (target_player.global_position - global_position).normalized()
	wasp_sting_windup_left = max(wasp_sting_windup_left - delta, 0.0)
	velocity_component.velocity = velocity_component.velocity.move_toward(
		Vector2.ZERO,
		WASP_STOP_DECELERATION * delta
	)
	if wasp_sting_windup_left <= 0.0:
		execute_wasp_sting()


func execute_wasp_sting() -> void:
	if wasp_sting_direction != Vector2.ZERO:
		velocity_component.apply_knockback(wasp_sting_direction, WASP_STING_FORCE)
	wasp_sting_cooldown = WASP_STING_COOLDOWN
	change_state(WaspState.STING_RECOVER)


func update_wasp_sting_recover(delta: float) -> void:
	wasp_sting_recover_left = max(wasp_sting_recover_left - delta, 0.0)
	velocity_component.velocity = velocity_component.velocity.move_toward(
		Vector2.ZERO,
		WASP_STOP_DECELERATION * delta
	)
	if wasp_sting_recover_left <= 0.0:
		change_state(WaspState.NORMAL)


func change_state(new_state: WaspState) -> void:
	current_state = new_state
	match current_state:
		WaspState.NORMAL:
			pass
		WaspState.STING_WINDUP:
			wasp_sting_windup_left = WASP_STING_WINDUP_DURATION
		WaspState.STING_RECOVER:
			wasp_sting_recover_left = WASP_STING_RECOVER_DURATION
