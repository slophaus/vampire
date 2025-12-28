extends CharacterBody2D

@onready var visuals := $Visuals
@onready var velocity_component: VelocityComponent = $VelocityComponent


func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	apply_random_tint()


func _physics_process(delta):
	velocity_component.accelerate_to_player()
	velocity_component.move(self)

	var move_sign = sign(velocity.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign, 1)


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()


func apply_random_tint():
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	visuals.modulate = Color.from_hsv(rng.randf(), 0.2, 1.0)
