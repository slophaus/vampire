extends CharacterBody2D


const SPEED = 200.0
const JUMP_VELOCITY = -400.0
var dash_capacity: int  = 2
var dashes : int = 0
var shoot_height : float = 27

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_timer: Timer = $jump_timer
@onready var dash_timer: Timer = $dash_timer
@onready var dash_recharge_timer: Timer = $dash_recharge_timer
@onready var wall_slide_timer: Timer = $wall_slide_timer
@onready var wall_slide_cooldown_left: Timer = $wall_slide_cooldown_left
@onready var wall_slide_cooldown_right: Timer = $wall_slide_cooldown_right
@onready var wall_jump_timer: Timer = $wall_jump_timer
@onready var ball_open_ray: RayCast2D = $ball_open_ray


@onready var label: Label = $Label

@onready var coll_crouch: CollisionShape2D = $coll_crouch
@onready var coll_stand: CollisionShape2D = $coll_stand

@onready var trail: CPUParticles2D = $trail


var bullet_path = preload("res://bullet.tscn")

enum State {idle,jump,fall,run,crouch,ball,dash, wall_slide, wall_jump}
var current_state = State.ball

func _ready() -> void:
	change_state(State.ball)

func fire():
	#make bullet
	var bullet = bullet_path.instantiate()
	
	#dir
	var dir =  Input.get_vector("p1_left","p1_right","p1_up","p1_down")
	if dir.length()<.1:
		if sprite.flip_h:
			dir = Vector2.LEFT
		else:
			dir = Vector2.RIGHT
	bullet.dir = dir
	
	#pos
	bullet.pos = position
	if sprite.flip_h:
		bullet.pos.x -= 17
	else:
		bullet.pos.x += 17
		
	bullet.pos.y -= shoot_height
	
	if dir.y<0:
		bullet.pos.y -= 10
		
	if dir.y>0:
		bullet.pos.y += 15
		
	if dir.x == 0 and dir.y < 0:
		velocity.x = 0
		bullet.pos.y -= 6
		if sprite.flip_h:
			bullet.pos.x += 15
		else:
			bullet.pos.x -= 15
	
	#reparent
	get_parent().add_child(bullet)

	
	#fire state
	if current_state == State.ball or current_state == State.dash or current_state == State.crouch or current_state == State.jump or current_state == State.fall:
		#change_state(State.fire_cr)
		sprite.play("fire_cr")
	else:
		#change_state(State.fire)
		sprite.play("fire")
		
	if dir.y<0:
		sprite.play("fire_high")
	if dir.y>0:
		sprite.play("fire_low")
		
	if dir.x == 0 and dir.y < 0:
		sprite.play("fire_up")

func change_state(new_state: State):
	current_state = new_state
	match current_state:
		State.idle:
			sprite.play("idle")
			velocity.x = 0
			shoot_height = 27
			coll_crouch.disabled = false
			coll_stand.disabled = false
			trail.emitting = false
			
		State.run:
			sprite.play("run")
			shoot_height = 27
			coll_crouch.disabled = false
			coll_stand.disabled = false
			trail.emitting = false
			
		State.jump:
			sprite.play("jump")
			velocity.y = JUMP_VELOCITY
			jump_timer.start()
			shoot_height = 27
			coll_crouch.disabled = false
			coll_stand.disabled = false
			trail.emitting = false
			
		State.fall:
			sprite.play("jump")
			shoot_height = 27
			coll_crouch.disabled = false
			coll_stand.disabled = false
			trail.emitting = false
			
		State.crouch:
			sprite.play("crouch")
			shoot_height = 14
			coll_crouch.disabled = false
			coll_stand.disabled = true
			trail.emitting = false
			
		State.ball:
			sprite.play("ball")
			shoot_height = 14
			coll_crouch.disabled = true
			coll_stand.disabled = true
			trail.emitting = false
			
		State.dash:
			sprite.play("ball")
			shoot_height = 14
			coll_crouch.disabled = true
			coll_stand.disabled = true
			trail.emitting = true
			
			var direction = Input.get_vector("p1_left","p1_right","p1_up","p1_down")
			if direction.length()<.1:
				if sprite.flip_h:
					direction = Vector2.LEFT
				else:
					direction = Vector2.RIGHT
			velocity = direction * 500
			dash_timer.start()
			dash_recharge_timer.start()
			dashes -=1
		State.wall_slide:
			sprite.play("wall_slide")
			wall_slide_timer.start()
			shoot_height = 14
			coll_crouch.disabled = false
			coll_stand.disabled = false
			trail.emitting = false
			
			sprite.flip_h = !sprite.flip_h
			
		State.wall_jump:
			sprite.play("jump")

func _physics_process(delta: float) -> void:
	match current_state:
		State.idle:
			#stop
			velocity.x = 0
			
			#floor check
			if not is_on_floor():
				change_state(State.fall)
			
			#jump
			if Input.is_action_just_pressed("p1_jump") and is_on_floor():
				change_state(State.jump)
			
			if not Input.is_action_pressed("p1_stop"):
				if Input.is_action_pressed("p1_right"):
					change_state(State.run)
					###
					velocity.x =  lerp(velocity.x,-SPEED,.1)
					sprite.flip_h = 0
				if Input.is_action_pressed("p1_left"):
					change_state(State.run)
					###
					velocity.x =  lerp(velocity.x,-SPEED,.1)
					sprite.flip_h = 1
				if Input.is_action_pressed("p1_down"):
					change_state(State.crouch)
		State.run:
			#floor check
			if not is_on_floor():
				change_state(State.fall)
				
			# no direction
			if Input.get_vector("p1_left","p1_right","p1_up","p1_down").length() < .1:
				change_state(State.idle)
			#stop
			if Input.is_action_pressed("p1_stop"):
				change_state(State.idle)
				
			#move
			if Input.is_action_pressed("p1_right"):
				###
				velocity.x =  lerp(velocity.x,SPEED,.4)
				sprite.flip_h = 0
			if Input.is_action_pressed("p1_left"):
				###
				velocity.x =  lerp(velocity.x,-SPEED,.4)
				sprite.flip_h = 1
				
			#jump
			if Input.is_action_just_pressed("p1_jump") and is_on_floor():
				change_state(State.jump)
			
		State.jump:
			#fall
			velocity += get_gravity() * delta *.5
			
			#slow
			velocity.x *= .925
			
			#land
			if is_on_floor():
				change_state(State.idle)
				
			#move
			if Input.is_action_pressed("p1_right"):
				####
				velocity.x =  lerp(velocity.x,SPEED,.6)
				sprite.flip_h = 0
			if Input.is_action_pressed("p1_left"):
				####
				velocity.x =  lerp(velocity.x,-SPEED,.6)
				sprite.flip_h = 1
				
			if jump_timer.time_left<=0:
				change_state(State.fall)
				
			if not Input.is_action_pressed("p1_jump"):
				change_state(State.fall)
				
			#bump head
			if is_on_ceiling():
				change_state(State.fall)
				
		State.fall:
			#fall
			velocity += get_gravity() * delta
			
			#slow Y
			if velocity.y <0:
				velocity.y *=.9
				
			#slow
			velocity.x *= .925
			
			#land
			if is_on_floor():
				change_state(State.idle)
				
			#move
			if Input.is_action_pressed("p1_right"):
				###
				velocity.x =  lerp(velocity.x,SPEED,.3)
				sprite.flip_h = 0
			if Input.is_action_pressed("p1_left"):
				###
				velocity.x =  lerp(velocity.x,-SPEED,.3)
				sprite.flip_h = 1
				
			#wall slide
			if is_on_wall_only():
				if wall_slide_cooldown_left.time_left  <= 0 and sprite.flip_h:
					change_state(State.wall_slide)
				elif wall_slide_cooldown_right.time_left  <= 0 and not sprite.flip_h:
					change_state(State.wall_slide)
				
		State.crouch:
			#stop
			velocity.x = 0
			
			#floor check
			if not is_on_floor():
				change_state(State.fall)
				
			#up
			if  Input.is_action_just_pressed("p1_up"):
				change_state(State.idle)
			
			#move
			if Input.is_action_pressed("p1_right"):
				change_state(State.run)
				velocity.x =  SPEED
				sprite.flip_h = 0
			if Input.is_action_pressed("p1_left"):
				change_state(State.run)
				velocity.x =  -SPEED
				sprite.flip_h = 1
				
			if Input.is_action_just_pressed("p1_jump") and is_on_floor():
				change_state(State.jump)
				
			if Input.is_action_just_pressed("p1_down"):
				change_state(State.ball)
		State.ball:
			#fall
			velocity += get_gravity() * delta

			#slow in air
			if not is_on_floor():
				velocity.x *= .85

			#init
			trail.emitting = false
			#move
			if Input.is_action_pressed("p1_right"):
				###
				#velocity.x =  lerp(velocity.x,SPEED*1.35,.3)
				if velocity.x < 0:
					velocity.x=0
				if velocity.x < (SPEED*1.35):
					velocity.x += (SPEED*1.35) *.15
				#working pretty good. neet to add to the run. maybe make a function
				sprite.flip_h = 0
				sprite.play()
				trail.emitting = true
			if Input.is_action_pressed("p1_left"):
				###
				#velocity.x =  lerp(velocity.x,-SPEED*1.35,.3)
				if velocity.x > 0:
					velocity.x=0
				if velocity.x > -(SPEED*1.35):
					velocity.x -= (SPEED*1.35) *.15
				sprite.flip_h = 1
				sprite.play()
				trail.emitting = true
				
			if not is_on_floor():
				trail.emitting = true
				
			if not Input.is_anything_pressed():
				velocity.x =  0
				sprite.pause()

			
			if not ball_open_ray.is_colliding():
				#up
				if Input.is_action_just_pressed("p1_up"):
					change_state(State.crouch)
				#jump
				if Input.is_action_just_pressed("p1_jump") and is_on_floor():
					change_state(State.jump)
				if Input.is_action_just_pressed("p1_jump") and not is_on_floor():
					change_state(State.fall)
					
		State.dash:
			#dash time
			if dash_timer.time_left <= 0:
				change_state(State.ball)
				
			#damp
			velocity *= .965
			
			if not ball_open_ray.is_colliding():
				#jump
				if Input.is_action_just_pressed("p1_jump") and is_on_floor():
					change_state(State.jump)
			
		State.wall_slide:
			
			var wall_dir = 1
			if sprite.flip_h: wall_dir *= -1
			
			#fall
			velocity += get_gravity() * delta
			#slow Y
			velocity.y *=.8
			velocity.x *= .8
			
			#wall jumo
			if Input.is_action_just_pressed("p1_jump"):
				change_state(State.wall_jump)
				velocity.x =  wall_dir *350
				velocity.y = -500
				#sprite.flip_h = !sprite.flip_h
				wall_jump_timer.start()
				if sprite.flip_h:
					wall_slide_cooldown_right.start()
				else:
					wall_slide_cooldown_left.start()
				return
			
			#move
			if Input.is_action_pressed("p1_right"):
				velocity.x =  SPEED
			if Input.is_action_pressed("p1_left"):
				velocity.x =  -SPEED
				
			#slide timer
			if wall_slide_timer.time_left <= 0:
				change_state(State.fall)
				velocity.x =  wall_dir *100
				wall_slide_cooldown_left.start()
				wall_slide_cooldown_right.start()
				
			#other checks
			if not is_on_wall():
				change_state(State.fall)
				wall_slide_cooldown_left.start()
				wall_slide_cooldown_right.start()
			if is_on_floor():
				change_state(State.idle)
				

				
		State.wall_jump:
			#fall
			velocity += get_gravity() * delta
			
			#wall jump timer
			if wall_jump_timer.time_left <= 0:
				change_state(State.fall)
	
	#dash
	if Input.is_action_just_pressed("p1_dash") and dashes > 0:
		change_state(State.dash)
		
	#if is_on_floor() and current_state != State.dash and current_state != State.ball:
		#dashes = 3
	if is_on_floor() and dash_recharge_timer.time_left <= 0:
		dashes = dash_capacity
	
	#shoot from anywhere
	if current_state == State.ball or current_state == State.dash:
		if not ball_open_ray.is_colliding():
			if Input.is_action_just_pressed("p1_shoot"):
				fire()
	else:
		if Input.is_action_just_pressed("p1_shoot"):
			fire()
	
	
	#idle after shoot anim
	if sprite.animation == "fire" and sprite.frame == 2:
		change_state(State.idle)
	if sprite.animation == "fire_cr" and sprite.frame == 2:
		change_state(State.crouch)
		
		
	#wall slide from anywhere
	#if is_on_wall_only() and wall_slide_cooldown.time_left <= 0 and current_state != State.wall_slide:
		#change_state(State.wall_slide)
	
	move_and_slide()
	
	#update debug label
	#var disp1 = str(State.keys()[current_state])
	#var disp2 =str(dashes)
	#var disp3 =str(snapped(dash_recharge_timer.time_left,.1))
	#var disp3 =str(snapped(wall_slide_timer.time_left,.1))
	var disp1 = str(ball_open_ray.is_colliding())
	var disp2 =str(snapped(wall_slide_cooldown_left.time_left,.1))
	var disp3 =str(snapped(wall_slide_cooldown_right.time_left,.1))
	label.text =  disp1+" - "+disp2+" - "+disp3
	
