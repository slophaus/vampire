extends CharacterBody2D

@onready var visuals := $Visuals
@onready var velocity_component: VelocityComponent = $VelocityComponent

@export var stuck_distance_threshold: float = 1.5
@export var stuck_time_threshold: float = 0.6
@export var pause_duration: float = 0.4
@export var paused_tint: Color = Color.WHITE

var stuck_time := 0.0
var pause_time_left := 0.0
var base_tint := Color.WHITE


func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	apply_random_tint()
	base_tint = visuals.modulate


func _process(delta):
	if pause_time_left > 0.0:
		pause_time_left = max(0.0, pause_time_left - delta)
		visuals.modulate = paused_tint
		velocity_component.velocity = Vector2.ZERO
		velocity_component.move(self)
		if pause_time_left == 0.0:
			visuals.modulate = base_tint
		return

	var start_position = global_position
	velocity_component.accelerate_to_player()
	velocity_component.move(self)

	var move_sign = sign(velocity.x)
	if move_sign != 0:
		visuals.scale = Vector2(-move_sign, 1)

	var moved_distance = global_position.distance_to(start_position)
	if moved_distance <= stuck_distance_threshold:
		stuck_time += delta
	else:
		stuck_time = 0.0

	if stuck_time >= stuck_time_threshold:
		stuck_time = 0.0
		pause_time_left = pause_duration
		visuals.modulate = paused_tint


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()


func apply_random_tint():
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	visuals.modulate = Color.from_hsv(rng.randf(), 0.2, 1.0)
