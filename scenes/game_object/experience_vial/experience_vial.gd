extends Node2D


@onready var collision_shape_2d = $Area2D/CollisionShape2D
@onready var sprite = $Sprite2D
@onready var burn_particles = $BurnParticles
@onready var flame_particles = $Flame
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var expire_timer = $ExpireTimer

@export var lifetime := 8.0
@export var expire_shrink_duration := 0.2
@export var burn_scale := Vector2(1.2, 1.2)

var collected_player: Node2D
var is_collecting := false
var is_expiring := false



func _ready():
	$Area2D.area_entered.connect(on_area_entered)
	expire_timer.timeout.connect(on_expire_timeout)
	expire_timer.start(lifetime)
	burn_particles.texture = sprite.texture
	burn_particles.emitting = false
	burn_particles.scale = Vector2(0.2, 0.2)
	flame_particles.emitting = true
	flame_particles.scale = Vector2(0.2, 0.2)
	var flame_animation = animation_player.get_animation("flame_velocity")
	if flame_animation != null and lifetime > 0.0:
		animation_player.speed_scale = flame_animation.length / lifetime
	animation_player.play("flame_velocity")


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
	burn_particles.scale = sprite.scale
	burn_particles.emitting = true
	burn_particles.restart()
	var tween = create_tween()
	tween.set_parallel()
	tween.tween_property(sprite, "scale", Vector2.ZERO, expire_shrink_duration) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	tween.tween_property(burn_particles, "scale", burn_scale, expire_shrink_duration) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.tween_callback(queue_free)
