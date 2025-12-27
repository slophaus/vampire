extends CharacterBody2D

@export var spell_ability: PackedScene
@export var spell_range := 450.0
@export var spell_cooldown := 1.5
@export var spell_damage := 6.0

@onready var visuals := $Visuals
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var spell_timer: Timer = $SpellTimer


func _ready():
	$HurtboxComponent.hit.connect(on_hit)
	spell_timer.wait_time = spell_cooldown
	spell_timer.timeout.connect(on_spell_timer_timeout)


func _process(delta):
	velocity_component.accelerate_to_player()
	velocity_component.move(self)

	var move_sign = sign(velocity.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign, 1)


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()


func on_spell_timer_timeout():
	if spell_ability == null:
		return

	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var spell_instance = spell_ability.instantiate() as SpellAbility
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer")
	foreground_layer.add_child(spell_instance)
	spell_instance.hitbox_component.damage = spell_damage
	spell_instance.setup(global_position, player.global_position, spell_range)
