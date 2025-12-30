extends CharacterBody2D

const MAX_SPEED = 125
const ACCELERATION_SMOOTHING = 25
const DAMAGE_FLASH_DURATION = 0.45
const EXPERIENCE_FLASH_DURATION = 0.1

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

var colliding_damage := {}
var base_speed := 0
var is_regenerating := false
var normal_visuals_modulate := Color.WHITE
var last_health := 0.0
var flash_tween: Tween

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


func get_movement_vector():	
	var suffix = get_player_action_suffix()
	var x_movement = Input.get_action_strength("move_right" + suffix) - Input.get_action_strength("move_left" + suffix)
	var y_movement = Input.get_action_strength("move_down" + suffix) - Input.get_action_strength("move_up" + suffix)
	
	return Vector2(x_movement, y_movement)


func get_player_action_suffix() -> String:
	return "" if player_number <= 1 else str(player_number)


func get_player_tint() -> Color:
	return GameEvents.get_player_color(player_number)


func can_attack() -> bool:
	return not is_regenerating


func check_deal_damage():
	if is_regenerating:
		return
	if colliding_damage.is_empty() || !damage_interval_timer.is_stopped():
		return

	var damage_amount := 1.0
	for value in colliding_damage.values():
		if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			damage_amount = max(damage_amount, float(value))
	health_component.damage(damage_amount)
	damage_interval_timer.start()


func update_health_display():
	health_bar.value = health_component.get_health_percent()


#---------------------------------------------


func on_body_entered(other_body: Node2D):
	var damage_value = other_body.get("contact_damage")
	if typeof(damage_value) not in [TYPE_INT, TYPE_FLOAT]:
		damage_value = 1
	colliding_damage[other_body] = damage_value
	check_deal_damage()


func on_body_exited(other_body: Node2D):
	if colliding_damage.has(other_body):
		colliding_damage.erase(other_body)


func on_damage_interval_timer_timeout():
	check_deal_damage()


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
