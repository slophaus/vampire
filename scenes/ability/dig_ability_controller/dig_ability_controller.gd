extends Node

const DIGGABLE_TILE_TYPES: Array[String] = ["dirt", "filled_dirt"]

@export var dig_radius := 7.0
@export var dig_cooldown := 2.0
@export var dig_poof_scene: PackedScene = preload("res://scenes/vfx/poof.tscn")
@export var owner_group := "player"

var tile_eater: TileEater
var player_number := 1


func _ready() -> void:
	player_number = resolve_player_number()
	tile_eater = TileEater.new(self)
	tile_eater.cache_walkable_tile()
	tile_eater.tile_converted.connect(_on_tile_converted)
	$Timer.wait_time = max(dig_cooldown, 0.0)
	$Timer.timeout.connect(_on_timer_timeout)
	$Timer.start()


func _on_timer_timeout() -> void:
	var owner_actor = get_owner_actor()
	if owner_actor == null:
		return
	if owner_actor.get("is_regenerating") == true:
		return
	if owner_actor.has_method("can_attack") and not owner_actor.can_attack():
		return
	if tile_eater == null:
		return
	tile_eater.try_convert_tiles_in_radius(owner_actor.global_position, dig_radius, DIGGABLE_TILE_TYPES)


func _on_tile_converted(world_position: Vector2) -> void:
	if dig_poof_scene == null:
		return
	var poof_instance = dig_poof_scene.instantiate() as GPUParticles2D
	if poof_instance == null:
		return
	get_tree().current_scene.add_child(poof_instance)
	poof_instance.global_position = world_position
	poof_instance.emitting = true
	poof_instance.restart()
	poof_instance.finished.connect(poof_instance.queue_free)


func get_owner_actor() -> Node2D:
	var node: Node = self
	while node != null:
		if node is Node2D and node.is_in_group(owner_group):
			return node as Node2D
		node = node.get_parent()

	return get_tree().get_first_node_in_group(owner_group) as Node2D


func resolve_player_number() -> int:
	if owner_group != "player":
		return player_number
	var player = get_owner_actor()
	if player != null and player.has_method("get_player_action_suffix"):
		return player.player_number
	return player_number


func set_player_number(new_player_number: int) -> void:
	player_number = new_player_number
