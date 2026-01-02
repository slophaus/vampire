extends Node2D

@export var health_component: HealthComponent
@export var sprite: Node2D


func _ready():
	health_component.died.connect(on_died)


func on_died():
	if owner == null || not owner is Node2D:
		return

	var sprite_texture = get_sprite_texture()
	if sprite_texture != null:
		$GPUParticles2D.texture = sprite_texture

	var spawn_position = owner.global_position

	var entities = get_tree().get_first_node_in_group("effects_layer")
	if entities == null:
		entities = get_tree().current_scene
	if entities == null:
		return
	get_parent().remove_child(self)
	entities.add_child(self)

	global_position = spawn_position
	$AnimationPlayer.play("default")
	$HitRandomAudioPlayerComponent.play_random()


func get_sprite_texture() -> Texture2D:
	if sprite == null:
		return null
	if sprite is Sprite2D:
		return sprite.texture
	if sprite is AnimatedSprite2D:
		var animated_sprite := sprite as AnimatedSprite2D
		if animated_sprite.sprite_frames == null:
			return null
		return animated_sprite.sprite_frames.get_frame_texture(
			animated_sprite.animation,
			animated_sprite.frame
		)
	return null
