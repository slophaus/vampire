extends CharacterBody2D

const MAX_SPEED = 125
const ACCELERATION_SMOOTHING = 25
const DAMAGE_FLASH_DURATION = 0.45
const EXPERIENCE_FLASH_DURATION = 0.1
const AIM_LASER_RANGE = 450.0
const AIM_MIN_INPUT = 0.1
const AIM_LINE_WIDTH = 2.0
const AIM_LINE_ALPHA = 0.75
const AIM_CIRCLE_ALPHA = 0.9
const AIM_CIRCLE_PADDING = 4.0

@onready var damage_interval_timer = $DamageIntervalTimer
@onready var health_component = $HealthComponent
@onready var health_bar = $HealthBar
@onready var upgrade_dots = $UpgradeDots
@onready var abilities = $Abilities
@onready var animation_player = $AnimationPlayer
@onready var visuals = $Visuals
@onready var player_color = $Visuals/player_sprite/player_color
@onready var velocity_component = $VelocityComponent

@export var player_number := 1
@export var regen_rate := 0.67

signal regenerate_started
signal regenerate_finished

var floating_text_scene = preload("res://scenes/ui/floating_text.tscn")

var colliding_enemies: Dictionary = {}
var base_speed := 0
var is_regenerating := false
var normal_visuals_modulate := Color.WHITE
var last_health := 0.0
var flash_tween: Tween
var aim_active := false
var aim_line_end := Vector2.ZERO
var aim_hit_target: Node2D
var aim_hit_radius := 0.0

const UPGRADE_DOT_SIZE := 4.0
const UPGRADE_DOT_RADIUS := 2


func _ready():
	base_speed = velocity_component.max_speed
	player_color.color = get_player_tint()
	player_color.visible = true
	visuals.modulate = Color.WHITE
	normal_visuals_modulate = visuals.modulate
	last_health = health_component.current_health
	
	$hurtbox.body_entered.connect(on_body_entered)
	$hurtbox.body_exited.connect(on_body_exited)
	damage_interval_timer.timeout.connect(on_damage_interval_timer_timeout)
	health_component.health_changed.connect(on_health_changed)
	health_component.died.connect(on_died)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)
	for ability in abilities.get_children():
		if ability.has_method("set_player_number"):
			ability.set_player_number(player_number)
	update_health_display()
	set_upgrade_dot_count(0)


func _process(delta):
	if is_regenerating:
		velocity_component.velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		animation_player.play("RESET")
		health_component.heal(regen_rate * delta)
		if health_component.current_health >= health_component.max_health:
			end_regeneration()
		aim_active = false
		aim_hit_target = null
		update()
		return

	var movement_vector = get_movement_vector()
	var direction = movement_vector.normalized()
	velocity_component.accelerate_in_direction(direction)
	velocity_component.move(self)
	
	if movement_vector.x != 0 || movement_vector.y != 0:
		animation_player.play("walk")
	else:
		animation_player.play("RESET")
	
	var move_sign = sign(movement_vector.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign, 1)

	update_aim_visuals()


func _draw() -> void:
	if not aim_active:
		return
	var line_color = get_player_tint()
	line_color.a = AIM_LINE_ALPHA
	draw_line(Vector2.ZERO, to_local(aim_line_end), line_color, AIM_LINE_WIDTH)
	if aim_hit_target != null and is_instance_valid(aim_hit_target):
		var circle_color = get_player_tint()
		circle_color.a = AIM_CIRCLE_ALPHA
		draw_circle(to_local(aim_hit_target.global_position), aim_hit_radius, circle_color)


func get_movement_vector():	
	var suffix = get_player_action_suffix()
	var x_movement = Input.get_action_strength("move_right" + suffix) - Input.get_action_strength("move_left" + suffix)
	var y_movement = Input.get_action_strength("move_down" + suffix) - Input.get_action_strength("move_up" + suffix)
	
	return Vector2(x_movement, y_movement)


func get_player_action_suffix() -> String:
	return "" if player_number <= 1 else str(player_number)


func get_aim_vector() -> Vector2:
	var suffix = get_player_action_suffix()
	var x_aim = Input.get_action_strength("aim_right" + suffix) - Input.get_action_strength("aim_left" + suffix)
	var y_aim = Input.get_action_strength("aim_down" + suffix) - Input.get_action_strength("aim_up" + suffix)
	return Vector2(x_aim, y_aim)


func update_aim_visuals() -> void:
	var aim_vector = get_aim_vector()
	if aim_vector.length() < AIM_MIN_INPUT:
		if aim_active:
			aim_active = false
			aim_hit_target = null
			update()
		return

	var aim_direction = aim_vector.normalized()
	var start = global_position
	var desired_end = start + (aim_direction * AIM_LASER_RANGE)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start, desired_end, 8)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		aim_line_end = desired_end
		aim_hit_target = null
		aim_hit_radius = 0.0
	else:
		aim_line_end = result.position
		var collider = result.collider as Node2D
		if collider != null and collider.is_in_group("enemy"):
			aim_hit_target = collider
			aim_hit_radius = get_enemy_highlight_radius(collider)
		else:
			aim_hit_target = null
			aim_hit_radius = 0.0

	aim_active = true
	update()


func get_enemy_highlight_radius(enemy: Node2D) -> float:
	var collision_shape = enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 18.0
	var shape = collision_shape.shape
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius + AIM_CIRCLE_PADDING
	if shape is RectangleShape2D:
		var extents = (shape as RectangleShape2D).extents
		return max(extents.x, extents.y) + AIM_CIRCLE_PADDING
	if shape is CapsuleShape2D:
		var capsule = shape as CapsuleShape2D
		return max(capsule.radius, capsule.height * 0.5) + AIM_CIRCLE_PADDING
	return 18.0


func get_player_tint() -> Color:
	return GameEvents.get_player_color(player_number)


func can_attack() -> bool:
	return not is_regenerating


func check_deal_damage():
	if is_regenerating:
		return
	if colliding_enemies.is_empty() || !damage_interval_timer.is_stopped():
		return
	var contact_damage = get_contact_damage()
	if contact_damage <= 0:
		return
	health_component.damage(contact_damage)
	damage_interval_timer.start()


func update_health_display():
	health_bar.value = health_component.get_health_percent()


#---------------------------------------------


func on_body_entered(other_body: Node2D):
	if other_body == null or not other_body.is_in_group("enemy"):
		return
	var contact_damage = other_body.get("contact_damage")
	var resolved_damage := 1.0
	if typeof(contact_damage) in [TYPE_INT, TYPE_FLOAT]:
		resolved_damage = float(contact_damage)
	colliding_enemies[other_body] = resolved_damage
	check_deal_damage()


func on_body_exited(other_body: Node2D):
	if colliding_enemies.has(other_body):
		colliding_enemies.erase(other_body)


func on_damage_interval_timer_timeout():
	check_deal_damage()


func get_contact_damage() -> float:
	var max_damage := 0.0
	for damage_value in colliding_enemies.values():
		max_damage = max(max_damage, float(damage_value))
	return max_damage


func on_health_changed():
	if not is_regenerating and health_component.current_health < last_health:
		spawn_damage_text(last_health - health_component.current_health)
		GameEvents.emit_player_damaged()
		$HitRandomStreamPlayer.play_random()
		flash_visuals(Color(1, 0.3, 0.3))
	elif not is_regenerating and health_component.current_health > last_health:
		flash_visuals(Color(0.3, 1, 0.3))
	update_health_display()
	last_health = health_component.current_health


func spawn_damage_text(damage_amount: float) -> void:
	if damage_amount <= 0:
		return
	var floating_text = floating_text_scene.instantiate() as FloatingText
	get_tree().get_first_node_in_group("foreground_layer").add_child(floating_text)

	floating_text.global_position = global_position + (Vector2.UP * 16)

	var fmt_string := "%0.1f"
	if is_equal_approx(damage_amount, int(damage_amount)):
		fmt_string = "%0.0f"
	floating_text.start(fmt_string % damage_amount, Color(1, 0.3, 0.3))


func on_died():
	if is_regenerating:
		return
	is_regenerating = true
	stop_flash()
	visuals.modulate = Color.BLACK
	health_component.current_health = 0
	health_component.health_changed.emit()
	damage_interval_timer.stop()
	regenerate_started.emit()


func end_regeneration():
	is_regenerating = false
	stop_flash()
	visuals.modulate = normal_visuals_modulate
	health_component.current_health = health_component.max_health
	health_component.health_changed.emit()
	last_health = health_component.current_health
	regenerate_finished.emit()


func on_ability_upgrade_added(ability_upgrade: AbilityUpgrade, current_upgrades: Dictionary, upgrade_player_number: int):
	if upgrade_player_number != player_number:
		return
	if ability_upgrade is Ability:
		var ability = ability_upgrade as Ability
		var ability_controller = ability.ability_controller_scene.instantiate()
		if ability_controller.has_method("set_player_number"):
			ability_controller.set_player_number(player_number)
		abilities.add_child(ability_controller)
	elif ability_upgrade.id == "player_speed":
		velocity_component.max_speed = base_speed + (base_speed * current_upgrades["player_speed"]["quantity"] * 0.2)
	update_upgrade_dots(current_upgrades)


func update_upgrade_dots(current_upgrades: Dictionary) -> void:
	var total_upgrades := 0
	for upgrade_data in current_upgrades.values():
		if typeof(upgrade_data) == TYPE_DICTIONARY and upgrade_data.has("quantity"):
			total_upgrades += int(upgrade_data["quantity"])
	set_upgrade_dot_count(total_upgrades)


func set_upgrade_dot_count(count: int) -> void:
	if upgrade_dots == null:
		return
	for child in upgrade_dots.get_children():
		child.queue_free()
	if count <= 0:
		return
	var dot_color = get_player_tint()
	for i in range(count):
		var dot = Panel.new()
		dot.custom_minimum_size = Vector2(UPGRADE_DOT_SIZE, UPGRADE_DOT_SIZE)
		var dot_style = StyleBoxFlat.new()
		dot_style.bg_color = dot_color
		dot_style.set_corner_radius_all(UPGRADE_DOT_RADIUS)
		dot.add_theme_stylebox_override("panel", dot_style)
		upgrade_dots.add_child(dot)


func flash_visuals(color: Color, duration: float = DAMAGE_FLASH_DURATION) -> void:
	stop_flash()
	visuals.modulate = color
	flash_tween = create_tween()
	flash_tween.tween_property(visuals, "modulate", normal_visuals_modulate, duration) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)


func stop_flash() -> void:
	if flash_tween != null and flash_tween.is_running():
		flash_tween.kill()


func flash_experience_gain() -> void:
	flash_visuals(Color(0.3, 0.6, 1.0), EXPERIENCE_FLASH_DURATION)
