extends BaseEnemy

func _ready():
	super._ready()
	set_sprite_visibility(scorpion_sprite)
	set_active_sprite(scorpion_sprite)
	fireball_ability_controller.set_active(false)
	dig_ability_controller.set_active(false)
	poison_spit_ability_controller.set_active(true)


func _physics_process(delta):
	accelerate_to_player_with_pathfinding()
	apply_enemy_separation()
	velocity_component.move(self)
	update_visual_facing()
	update_possession_timer(delta)
