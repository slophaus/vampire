extends CanvasLayer

signal transitioned_halfway
var skip_emit := false

@onready var rect: ColorRect = $ColorRect
@onready var material: ShaderMaterial = rect.material

enum TransitionStyle { DIAMOND, BATS }

@export var transition_style := TransitionStyle.BATS
@export var bat_texture: Texture2D = preload("res://sprites/gollum.png")
@export var bat_tile_size := 48.0
@export var bat_cluster_size := 3.0

var diamond_material: ShaderMaterial
var bats_material: ShaderMaterial


func _ready():
	diamond_material = rect.material
	bats_material = ShaderMaterial.new()
	bats_material.shader = preload("res://scenes/autoload/screen_transition_bats.gdshader")
	bats_material.set_shader_parameter("bat_texture", bat_texture)
	bats_material.set_shader_parameter("tile_size", bat_tile_size)
	bats_material.set_shader_parameter("cluster_size", bat_cluster_size)
	bats_material.set_shader_parameter("progress", 0.0)
	bats_material.set_shader_parameter("fill_in", true)
	apply_transition_style(transition_style)


func apply_transition_style(style: TransitionStyle):
	transition_style = style
	rect.material = bats_material if style == TransitionStyle.BATS else diamond_material
	material = rect.material


func set_transition_style(style: TransitionStyle):
	apply_transition_style(style)


func transition():
	rect.visible = true
	material.set_shader_parameter("fill_in", true)
	$AnimationPlayer.play("default")
	await $AnimationPlayer.animation_finished

	material.set_shader_parameter("fill_in", false)
	material.set_shader_parameter("progress", 0)
	$AnimationPlayer.play("default")
	await $AnimationPlayer.animation_finished
	rect.visible = false


func transition_to_scene(scene_path: String):
	transition()
	await transitioned_halfway
	get_tree().change_scene_to_file(scene_path)


func emit_transitioned_halfway():
	transitioned_halfway.emit()
