extends BaseEnemy

func _ready():
	super()
	set_sprite_visibility(rat_sprite)
	set_active_sprite(rat_sprite)
	fireball_ability_controller.set_active(false)
	dig_ability_controller.set_active(false)


func _physics_process(delta):
	accelerate_to_player_with_pathfinding()
	apply_enemy_separation()
	velocity_component.move(self)
	update_visual_facing()
	update_possession_timer(delta)
