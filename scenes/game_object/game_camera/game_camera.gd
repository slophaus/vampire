extends Camera2D

var target_position = Vector2.ZERO
@onready var average_point: Node2D = $AveragePoint


func _ready():
	make_current()
	average_point.top_level = true
	average_point.global_position = global_position


func _process(delta):
	acquire_target()
	global_position = global_position.lerp(target_position, 1.0 - exp(-delta * 20))
	average_point.global_position = target_position


func acquire_target():
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		var summed_position = Vector2.ZERO
		for player in player_nodes:
			summed_position += (player as Node2D).global_position
		target_position = summed_position / float(player_nodes.size())
