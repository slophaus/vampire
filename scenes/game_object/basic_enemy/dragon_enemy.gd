extends BaseEnemy

func _ready():
	base_max_health = 10.0
	base_max_speed = 45.0
	base_acceleration = 2.0
	base_facing_multiplier = 1.0
	base_contact_damage = 1.0
	base_poison_contact_duration = 0.0
	super._ready()
	set_sprite_visibility(dragon_sprite)
	set_active_sprite(dragon_sprite)
	fireball_ability_controller.set_active(true)
	dig_ability_controller.set_active(false)


func _physics_process(delta):
	accelerate_to_player_with_pathfinding()
	apply_enemy_separation()
	velocity_component.move(self)
	update_visual_facing()
	update_possession_timer(delta)
