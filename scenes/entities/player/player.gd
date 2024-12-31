extends CharacterBody3D

@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.3

@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0
# source: https://youtu.be/IOe1aGY6hXA?feature=shared

@onready var skin = $godetteSkin

@export var base_speed := 4.0
@export var run_speed := 6.0
@export var defend_speed := 2.0
var speed_modifier := 1.0

@onready var camera = $camera_controler/Camera3D
@onready var ui = $UI

var movement_input := Vector2.ZERO
var last_movement_input = Vector2(0, 1)
var defend := false:
	set(value):
		if not defend and value:
			skin.defend(true)
		if defend and not value:
			skin.defend(false)
		defend = value
var weapon_active := true:
	set(value):
		weapon_active = value
		if weapon_active:
			ui.get_node("spells").hide()
		else:
			ui.get_node("spells").show()
var health = 5:
	set(value):
		ui.update_health(value, value - health)
		health = value
		if health <= 0:
			get_tree().quit()
var energy = 100:
	set(value):
		energy = min(100, value)
		ui.update_energy(energy)
var stamina = 100:
	set(value):
		ui.update_stamina(stamina, value)
		if stamina == 100 and value < 100:
			ui.change_stamina_alpha(1.0)
		if value == 100:
			ui.change_stamina_alpha(0.0)
		stamina = clamp(value, 0, 100)

signal cast_spell(type: String, pos: Vector3, direction: Vector2, size: float)

enum spells{FIREBALL, HEAL}
var current_spell = spells.FIREBALL

func _ready() -> void:
	weapon_active = true
	skin.switch_weapon(weapon_active)
	ui.setup(health)

func _physics_process(delta: float) -> void:
	
	move_logic(delta)
	jump_logic(delta)
	ability_logic()
	#if Input.is_action_just_pressed("ui_accept"):
	#	hit()
	move_and_slide()

func move_logic(delta) -> void:
	movement_input = Input.get_vector("left", "right", "forward", "backward").rotated(-camera.global_rotation.y)
	
	var vel_2d = Vector2(velocity.x,velocity.z)
	var is_running: bool = Input.is_action_pressed("run")
	
	if movement_input != Vector2.ZERO:
		var speed = run_speed if is_running else base_speed
		speed = defend_speed if defend else speed
		
		vel_2d += movement_input * speed * delta * 8.0
		vel_2d = vel_2d.limit_length(speed) * speed_modifier
		velocity.x = vel_2d.x
		velocity.z = vel_2d.y
		skin.set_move_state('Running')
		var target_angle = -movement_input.angle() + PI/2
		skin.rotation.y = rotate_toward(skin.rotation.y, target_angle, 6.0 * delta)
	else:
		vel_2d = vel_2d.move_toward(Vector2.ZERO, base_speed * 4.0 * delta)
		velocity.x = vel_2d.x
		velocity.z = vel_2d.y
		skin.set_move_state('Idle')

	if movement_input:
		last_movement_input = movement_input.normalized()

func jump_logic(delta) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and stamina >= 20:
			velocity.y = -jump_velocity
			do_squash_and_stretch(1.2, 0.15)
			stamina -= 20
	else:
		skin.set_move_state('Jump')
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y -= gravity * delta

func ability_logic() -> void:
	
	# actual attack
	if Input.is_action_just_pressed("ability"):
		if weapon_active:
			skin.attack()
		else:
			if energy >= 20:
				skin.cast_spell()
				stop_movement(0.3, 0.8)
				energy -= 20
	# defend
	defend = Input.is_action_pressed("block")
	
	#switch between weapon and magic
	if Input.is_action_just_pressed('switch weapon') and not skin.attacking:
		weapon_active = not weapon_active
		skin.switch_weapon(weapon_active)
		do_squash_and_stretch(1.2, 0.15)
	
	if Input.is_action_just_pressed("switch spell") and not skin.attacking:
		current_spell = spells[spells.keys()[(int(current_spell) + 1) % len(spells)]]
		ui.update_spell(spells, current_spell)

func stop_movement(start_duration: float, end_duration: float):
	var tween = create_tween()
	tween.tween_property(self, "speed_modifier", 0.0, start_duration)
	tween.tween_property(self, "speed_modifier", 1.0, end_duration)

func hit():
	if not $Timers/InvulTimer.time_left:
		skin.hit()
		stop_movement(0.3, 0.3)
		health -= 1
		$Timers/InvulTimer.start()

func do_squash_and_stretch(value: float, duration: float = 0.1):
	var tween = create_tween()
	tween.tween_property(skin, "squash_and_stretch", value, duration)
	tween.tween_property(skin, "squash_and_stretch", 1.0, duration * 1.8).set_ease(Tween.EASE_OUT)

func shoot_magic(pos: Vector3) -> void:
	if current_spell == spells.FIREBALL:
		cast_spell.emit('fireball', pos, last_movement_input, 1.0)
	if current_spell == spells.HEAL:
		health += 1

func _on_energy_recovery_timer_timeout() -> void:
	energy += 1

func _on_stamina_recovery_timer_timeout() -> void:
	stamina +=1
