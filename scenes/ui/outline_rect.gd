extends ColorRect
class_name OutlineRect

@export var outline_size := 4.0
@export var outline_color := Color(0, 0, 0, 1)

@onready var shader_material := material as ShaderMaterial


func _ready() -> void:
	if shader_material != null:
		shader_material = shader_material.duplicate()
		shader_material.resource_local_to_scene = true
		material = shader_material
	_update_shader()
	resized.connect(_update_shader)


func set_outline_color(new_color: Color) -> void:
	outline_color = new_color
	_update_shader()


func _update_shader() -> void:
	if shader_material == null:
		return
	shader_material.set_shader_parameter("rect_size", size)
	shader_material.set_shader_parameter("outline_size", outline_size)
	shader_material.set_shader_parameter("outline_color", outline_color)
