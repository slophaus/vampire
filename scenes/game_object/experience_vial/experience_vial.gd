extends Node2D


@onready var collision_shape_2d = $Area2D/CollisionShape2D
@onready var sprite = $Sprite2D
@onready var burn_particles = $BurnParticles
@onready var expire_timer = $ExpireTimer

@export var lifetime := 8.0
@export var expire_shrink_duration := 0.2
@export var burn_scale := Vector2(1.2, 1.2)
@export var flame_rise_offset := Vector2(0.0, -18.0)
@export var flame_start_scale := Vector2(0.2, 0.2)

var collected_player: Node2D
var is_collecting := false
var is_expiring := false
var lifetime_tween: Tween
var burn_start_position: Vector2



func _ready():
	$Area2D.area_entered.connect(on_area_entered)
	expire_timer.timeout.connect(on_expire_timeout)
	expire_timer.start(lifetime)
	burn_particles.texture = sprite.texture
	burn_particles.one_shot = false
	burn_particles.emitting = true
	burn_particles.scale = flame_start_scale
	burn_start_position = burn_particles.position
	lifetime_tween = create_tween()
	lifetime_tween.set_parallel()
	lifetime_tween.tween_property(sprite, "scale", Vector2.ZERO, lifetime) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	lifetime_tween.tween_property(burn_particles, "scale", burn_scale, lifetime) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	lifetime_tween.tween_property(burn_particles, "position", burn_start_position + flame_rise_offset, lifetime) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)


func tween_collect(percent: float, start_position: Vector2):
	var player = collected_player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	
	global_position = start_position.lerp(player.global_position, percent)
	
	var direction_from_start = player.global_position - start_position

	var target_rotation = direction_from_start.angle() + deg_to_rad(90)
	rotation = lerp_angle(rotation, target_rotation, 1 - exp(-2 * get_process_delta_time()))


func collect():
	var player = collected_player
	if player == null or not is_instance_valid(player) or player.is_regenerating:
		queue_free()
		return
	GameEvents.emit_experience_vial_collected(0.25)
	if player.has_method("flash_experience_gain"):
		player.flash_experience_gain()
	if lifetime_tween != null:
		lifetime_tween.kill()
	queue_free()


func disable_collision():
	collision_shape_2d.disabled = true


func on_area_entered(other_area: Area2D):
	if is_collecting or is_expiring:
		return
	var player = other_area.get_parent() as Node2D
	if player == null || not player.is_in_group("player"):
		return
	if player.is_regenerating:
		return
	is_collecting = true
	collected_player = player
	Callable(disable_collision).call_deferred()
	expire_timer.stop()
	
	var tween = create_tween()
	tween.set_parallel()
	tween.tween_method(tween_collect.bind(global_position), 0.0, 1.0, .5) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.05).set_delay(0.45)
	tween.chain()
	tween.tween_callback(collect)
	
	$RandomAudioStreamPlayer2DComponent.play_random()


func on_expire_timeout() -> void:
	expire()


func expire() -> void:
	if is_expiring or is_collecting:
		return
	is_expiring = true
	disable_collision()
	if lifetime_tween != null:
		lifetime_tween.kill()
	burn_particles.emitting = true
	burn_particles.position = burn_start_position + flame_rise_offset
	burn_particles.scale = burn_scale
	var tween = create_tween()
	tween.tween_interval(expire_shrink_duration)
	tween.tween_callback(queue_free)
