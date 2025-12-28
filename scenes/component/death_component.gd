extends Node2D

@export var health_component: HealthComponent
@export var sprite: Sprite2D


func _ready():
	$GPUParticles2D.texture = sprite.texture
	health_component.died.connect(on_died)


func set_sprite(new_sprite: Sprite2D) -> void:
	sprite = new_sprite
	if $GPUParticles2D != null:
		$GPUParticles2D.texture = sprite.texture


func on_died():
	if owner == null || not owner is Node2D:
		return

	var spawn_position = owner.global_position

	var entities = get_tree().get_first_node_in_group("entities_layer")
	get_parent().remove_child(self)
	entities.add_child(self)

	global_position = spawn_position
	$AnimationPlayer.play("default")
	$HitRandomAudioPlayerComponent.play_random()
