extends Area2D


@export var boss_arena_scene: PackedScene = preload("res://scenes/main/boss_arena.tscn")


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if boss_arena_scene == null:
		return
	get_tree().change_scene_to_packed(boss_arena_scene)
