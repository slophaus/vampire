extends Node

@export var sprite: AnimatedSprite2D
@export var outline_material: ShaderMaterial
@export var outline_color: Color = Color(1, 0, 0)
@export var outline_size: float = 2.0
@export var z_index_offset: int = -1

var outline_sprite: AnimatedSprite2D


func _ready() -> void:
	create_outline_sprite()


func _process(_delta: float) -> void:
	if outline_sprite == null or sprite == null:
		return
	sync_outline_sprite()


func set_sprite(new_sprite: AnimatedSprite2D) -> void:
	sprite = new_sprite
	create_outline_sprite()


func create_outline_sprite() -> void:
	if sprite == null:
		return
	if outline_sprite != null and outline_sprite.is_inside_tree():
		outline_sprite.queue_free()

	outline_sprite = AnimatedSprite2D.new()
	outline_sprite.name = "OutlineSprite"
	outline_sprite.material = create_material_instance()
	outline_sprite.z_index = sprite.z_index + z_index_offset
	outline_sprite.top_level = sprite.top_level

	var parent_node := sprite.get_parent()
	parent_node.add_child(outline_sprite)
	outline_sprite.owner = sprite.owner
	sync_outline_sprite()


func create_material_instance() -> ShaderMaterial:
	if outline_material == null:
		return null
	var material_instance := outline_material.duplicate()
	material_instance.set_shader_parameter("outline_color", outline_color)
	material_instance.set_shader_parameter("outline_size", outline_size)
	return material_instance


func sync_outline_sprite() -> void:
	outline_sprite.sprite_frames = sprite.sprite_frames
	outline_sprite.animation = sprite.animation
	outline_sprite.frame = sprite.frame
	outline_sprite.playing = sprite.playing
	outline_sprite.speed_scale = sprite.speed_scale
	outline_sprite.centered = sprite.centered
	outline_sprite.offset = sprite.offset
	outline_sprite.flip_h = sprite.flip_h
	outline_sprite.flip_v = sprite.flip_v
	outline_sprite.position = sprite.position
	outline_sprite.rotation = sprite.rotation
	outline_sprite.scale = sprite.scale
	outline_sprite.visible = sprite.visible
