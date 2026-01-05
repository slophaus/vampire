extends BaseEnemy

func _ready():
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
