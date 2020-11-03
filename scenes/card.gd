extends Node2D

var hovered = false
var dragged = false
var drag_offset

export var id = "" setget set_id
export var command = "" setget set_command
export var description = "" setget set_description
export var energy = 0 setget set_energy

var _first_argument = null
var _home_position = null
var _home_rotation = null

onready var energy_label = $Sprite/Energy

func _ready():
	set_process_unhandled_input(true)
	set_energy(energy)
	
func _process(delta):
	if game.energy >= energy:
		energy_label.modulate = Color(0.5, 1, 0.5)
	else:
		energy_label.modulate = Color(1, 1, 1)
		modulate = Color(1, 0.5, 0.5)
	
	if dragged:
		var mousepos = get_viewport().get_mouse_position()
		global_position = mousepos - drag_offset
	
	var target_scale = 1
	
	if hovered and not dragged:
		target_scale = 1.5
	
	scale = lerp(scale, Vector2(target_scale, target_scale), 10*delta)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed and hovered:
			dragged = true
			game.dragged_object = self
			_turn_on_highlights()
			$PickupSound.play()
			drag_offset = get_viewport().get_mouse_position() - global_position
			get_tree().set_input_as_handled()
			modulate.a = 0.5
		elif event.button_index == BUTTON_LEFT and !event.pressed and dragged:
			dragged = false
			game.dragged_object = null
			_turn_off_highlights()
			modulate.a = 1
			
			if "[" in command:
				move_back()
			else:
				try_play(command)
				
func _turn_on_highlights():
	var arg_regex = RegEx.new()
	arg_regex.compile("\\[(.*)\\]")
	var m = arg_regex.search(command)
	if m:
		var types = Array(m.get_string(1).split(","))
		for type in types:
			for area in get_tree().get_nodes_in_group("drop_areas"):
				area.highlight(type.strip_edges())
		
func _turn_off_highlights():
	for area in get_tree().get_nodes_in_group("drop_areas"):
		area.highlighted = false
				
func _mouse_entered():
	hovered = true
	z_index = 1

func _mouse_exited():
	hovered = false
	z_index = 0
	
func set_command(new_command):
	command = new_command
	$Label.text = command

func set_description(new_description):
	description = new_description
	$Description.text = description
	
func set_energy(new_energy):
	energy = new_energy
	if energy_label:
		energy_label.text = str(energy)

func set_id(new_id):
	id = new_id
	var texture = load("res://cards/%s.svg" % new_id)
	if texture:
		$Image.texture = texture
	
func move_back():
	position = _home_position
	rotation_degrees = _home_rotation
	$ReturnSound.play()

func dropped_on(other):
	if "[" in command:
		var argument = other.id
		if (command.begins_with("git checkout") or command.begins_with("git rebase")) and other.id.begins_with("refs/heads"):
			argument = Array(other.id.split("/")).pop_back()
			
		var arg_regex = RegEx.new()
		arg_regex.compile("\\[(.*)\\]")
		var full_command = arg_regex.sub(command, argument)
		try_play(full_command)

func try_play(full_command):
	if game.energy >= energy:
		var terminal = $"../../../..".terminal
		terminal.send_command(full_command)
		#yield(terminal, "command_done")
		$PlaySound.play()
		var particles = preload("res://scenes/card_particles.tscn").instance()
		particles.position = position
		get_parent().add_child(particles)
		move_back()
		game.energy -= energy
	else:
		move_back()
