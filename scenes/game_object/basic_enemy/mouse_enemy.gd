extends BaseEnemy

func _ready():
	base_max_health = 10.0
	base_max_speed = 30.0
	base_acceleration = 5.0
	base_facing_multiplier = -1.0
	base_contact_damage = 1.0
	base_poison_contact_duration = 0.0
	super._ready()
	set_sprite_visibility(mouse_sprite)
	set_active_sprite(mouse_sprite)
	fireball_ability_controller.set_active(false)
	dig_ability_controller.set_active(true)
	apply_dig_level()


func _physics_process(delta):
	velocity_component.accelerate_to_player()
	apply_enemy_separation()
	velocity_component.move(self)
	update_visual_facing()
	update_possession_timer(delta)
