extends Area2D
class_name HurtboxComponent

signal hit

@export var health_component: HealthComponent

var floating_text_scene = preload("res://scenes/ui/floating_text.tscn")


func _ready():
	area_entered.connect(on_area_entered)


func on_area_entered(other_area: Area2D):
	if not other_area is HitboxComponent:
		return

	if health_component == null:
		return

	var hitbox_component = other_area as HitboxComponent
	if should_ignore_hit(hitbox_component):
		return
	health_component.damage(hitbox_component.damage)
	hitbox_component.register_hit()
	apply_knockback(hitbox_component)

	var floating_text = floating_text_scene.instantiate() as FloatingText
	get_tree().get_first_node_in_group("foreground_layer").add_child(floating_text)

	floating_text.global_position = global_position + (Vector2.UP * 16)
	
	# cut out for brevity
	var fmt_string := "%0.1f"
	if is_equal_approx(hitbox_component.damage, int(hitbox_component.damage)):
		fmt_string = "%0.0f"
	var damage_color := Color.WHITE
	var owner_node = get_parent()
	if owner_node != null and owner_node.is_in_group("player"):
		damage_color = Color(1, 0.3, 0.3)
	floating_text.start(fmt_string % hitbox_component.damage, damage_color)
	
	hit.emit()


func should_ignore_hit(hitbox_component: HitboxComponent) -> bool:
	var owner_node = get_parent()
	if owner_node == null:
		return false

	return owner_node.get("is_regenerating") == true


func apply_knockback(hitbox_component: HitboxComponent) -> void:
	if hitbox_component.knockback <= 0:
		return

	var owner_node = get_parent() as Node2D
	if owner_node == null:
		return

	var velocity_component = owner_node.get_node_or_null("VelocityComponent") as VelocityComponent
	if velocity_component == null:
		return

	var knockback_direction = (owner_node.global_position - hitbox_component.global_position).normalized()
	velocity_component.apply_knockback(knockback_direction, hitbox_component.knockback)
