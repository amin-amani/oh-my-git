extends Control

var dragged = null

#var level_set = "top-down"
var level_set = "bottom-up"
var current_level = 0

onready var terminal = $HBoxContainer/RightSide/Terminal
onready var input = terminal.input
onready var output = terminal.output
onready var goal_repository = $HBoxContainer/Repositories/GoalRepository
onready var active_repository = $HBoxContainer/Repositories/ActiveRepository
onready var level_select = $HBoxContainer/RightSide/TopStuff/Menu/LevelSelect
onready var next_level_button = $HBoxContainer/RightSide/TopStuff/Menu/NextLevelButton
onready var level_name = $HBoxContainer/RightSide/TopStuff/LevelPanel/LevelName
onready var level_description = $HBoxContainer/RightSide/TopStuff/LevelPanel/Text/LevelDescription
onready var level_congrats = $HBoxContainer/RightSide/TopStuff/LevelPanel/Text/LevelCongrats

func _ready():
	# Initialize level select.
	var options = level_select.get_popup()
	repopulate_levels()
	options.connect("id_pressed", self, "load_level")
	
	# Load first level.
	load_level(0)
	input.grab_focus()
	
func list_levels():
	var levels = []
	var dir = Directory.new()
	dir.open("res://levels/%s" % level_set)
	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with(".") and file != "sequence":
			levels.append(file)

	dir.list_dir_end()
	levels.sort()
	
	var final_level_sequence = []
	
	var level_sequence = Array(game.read_file("res://levels/%s/sequence" % level_set, "").split("\n"))
	
	for level in level_sequence:
		if level == "":
			continue
		if not levels.has(level):
			push_error("Level '%s' is specified in the sequence, but could not be found" % level)
		levels.erase(level)
		final_level_sequence.push_back(level)
	
	final_level_sequence += levels
	
	return final_level_sequence

func load_level(id):
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	
	next_level_button.hide()
	level_congrats.hide()
	level_description.show()
	current_level = id
	
	var levels = list_levels()
	
	var level = levels[id]
	var level_prefix = "res://levels/%s/" % level_set
	
	var goal_repository_path = "/tmp/goal/"
	var active_repository_path = "/tmp/active/"
	var goal_script = level_prefix+level+"/goal"
	var active_script = level_prefix+level+"/start"
	
	var description_file = level_prefix+level+"/description"
	var description = game.read_file(description_file, "no description")
	
	# Surround all lines indented with four spaces with [code] tags.
	var monospace_regex = RegEx.new()
	monospace_regex.compile("\n    (.*)\n")
	description = monospace_regex.sub(description, "\n      [code]$1[/code]\n", true)
	level_description.bbcode_text = description
	
	var congrats_file = level_prefix+level+"/congrats"
	var congrats = game.read_file(congrats_file, "Good job, you solved the level!\n\nFeel free to try a few more things or click 'Next Level'.")
	level_congrats.bbcode_text = congrats
	
	level_name.text = level
	
	# We're actually destroying stuff here.
	# Make sure that active_repository is in a temporary directory.
	var expected_prefix = "/tmp"
	if active_repository_path.substr(0,4) != expected_prefix:
		push_error("Refusing to delete a directory that does not start with %s" % expected_prefix)
		get_tree().quit()
	if goal_repository_path.substr(0,4) != expected_prefix:
		push_error("Refusing to delete a directory that does not start with %s" % expected_prefix)
		get_tree().quit()
	
	# Danger zone!
	game.global_shell.run("rm -rf '%s'" % active_repository_path)
	game.global_shell.run("rm -rf '%s'" % goal_repository_path)
		
	var goal_script_content = game.read_file(goal_script, "")
	var active_script_content = game.read_file(active_script, "")
	construct_repo(active_script_content +"\n"+ goal_script_content, goal_repository_path)
	construct_repo(active_script_content, active_repository_path)
	
	goal_repository.path = goal_repository_path
	active_repository.path = active_repository_path
	
	var win_script = level_prefix+level+"/win"
	var win_script_target = game.tmp_prefix+"/win"
	var win_script_content = game.read_file(win_script, "exit 1\n")
	game.write_file(win_script_target, win_script_content)
	
	terminal.clear()
	
	# Unmute the audio after a while, so that player can hear pop sounds for
	# nodes they create.
	var t = Timer.new()
	t.wait_time = 3
	add_child(t)
	t.start()
	yield(t, "timeout")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	# FIXME: Need to clean these up when switching levels somehow.

func reload_level():
	load_level(current_level)

func load_next_level():
	current_level = (current_level + 1) % list_levels().size()
	load_level(current_level)
	
func construct_repo(script_content, path):
	# Becase in an exported game, all assets are in a .pck file, we need to put
	# the script somewhere in the filesystem.
	
	var script_path_outside = game.tmp_prefix+"/git-hydra-script"
	var script_path = "/tmp/git-hydra-script"
	game.write_file(script_path_outside, script_content)
	
	game.global_shell.run("mkdir " + path)
	game.global_shell.cd(path)
	game.global_shell.run("git init")
	game.global_shell.run("git symbolic-ref HEAD refs/heads/main")
	# Read stdin from /dev/null so that interactive commands don't block.
	game.global_shell.run("bash "+script_path+" </dev/null")
	
func show_win_status():
	next_level_button.show()
	level_description.hide()
	level_congrats.show()

func repopulate_levels():
	var options = level_select.get_popup()
	options.clear()
	for level in list_levels():
		options.add_item(level)
