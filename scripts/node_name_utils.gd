extends Node
class_name NodeNameUtils

static func get_base_name_from_scene(scene_path: String, fallback_name: String = "node") -> String:
	if scene_path == "":
		return fallback_name
	return scene_path.get_file().get_basename().to_lower()


static func assign_unique_name(node: Node, parent_node: Node, base_name: String) -> void:
	if node == null or parent_node == null or base_name == "":
		return
	var index := 1
	var candidate := "%s%d" % [base_name, index]
	while parent_node.has_node(candidate):
		index += 1
		candidate = "%s%d" % [base_name, index]
	node.name = candidate
