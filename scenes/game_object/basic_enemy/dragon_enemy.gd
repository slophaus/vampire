extends BaseEnemy

func _ready():
	super._ready()
	set_sprite_visibility(dragon_sprite)
	set_active_sprite(dragon_sprite)
	fireball_ability_controller.set_active(true)
	dig_ability_controller.set_active(false)
	poison_spit_ability_controller.set_active(false)


func _physics_process(delta):
	if update_dormant_state(delta):
		return
	accelerate_to_player_with_pathfinding()
	apply_enemy_separation()
	velocity_component.move(self)
	update_visual_facing()
	update_possession_timer(delta)
