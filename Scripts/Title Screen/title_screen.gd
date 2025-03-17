extends Node
#tite_screen.gd
# Path to the main game scene
const MAIN_GAME_SCENE = "res://game.tscn"

# References to UI elements
@onready var new_game_button = $CanvasLayer/Control/MainContainer/ButtonsContainer/NewGameButton
@onready var load_game_button = $CanvasLayer/Control/MainContainer/ButtonsContainer/LoadGameButton
@onready var settings_button = $CanvasLayer/Control/MainContainer/ButtonsContainer/SettingsButton
@onready var about_us_button = $CanvasLayer/Control/MainContainer/ButtonsContainer/AboutUsButton

# Dialogs
var settings_dialog
var about_dialog
var load_dialog

func _ready():
	# Connect button signals
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	about_us_button.pressed.connect(_on_about_us_pressed)
	
	# Setup dialogs
	setup_load_dialog()
	setup_settings_dialog()
	setup_about_dialog()
	
	# Optional: Add background music
	# $BackgroundMusic.play()

func _on_new_game_pressed():
	# Set a flag in the scene tree to indicate we want a new game
	get_tree().root.set_meta("start_new_game", true)

	# Change to the main game scene
	get_tree().change_scene_to_file(MAIN_GAME_SCENE)
	
func _on_load_game_pressed():
	# Show load game dialog
	load_dialog.popup_centered(Vector2(600, 400))

func _on_settings_pressed():
	# Show settings dialog
	settings_dialog.popup_centered()

func _on_about_us_pressed():
	# Show about us dialog
	about_dialog.popup_centered()

func setup_load_dialog():
	load_dialog = FileDialog.new()
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.filters = ["*.json ; Save Files"]
	load_dialog.title = "Load Game"
	load_dialog.size = Vector2(600, 400)
	add_child(load_dialog)
	
	# Connect file selected signal
	load_dialog.file_selected.connect(_on_load_file_selected)

func _on_load_file_selected(path):
	# Change to the main game scene first
	var main_game_scene = load(MAIN_GAME_SCENE).instantiate()

	# The main issue might be that we need to properly load the scene first
	get_tree().root.add_child(main_game_scene)

	# Wait for one frame to make sure the scene is fully initialized
	await get_tree().process_frame

	# Now call the load_game_from_path function directly
	if main_game_scene.has_method("load_game_from_path"):
		main_game_scene.load_game_from_path(path)

	# Remove the title screen 
	queue_free()
	
	# Remove the current main scene (not the one we just added)
	var current_scene = get_tree().current_scene
	if current_scene != main_game_scene:
		current_scene.queue_free()

func setup_settings_dialog():
	settings_dialog = PopupPanel.new()
	settings_dialog.title = "Settings"
	settings_dialog.size = Vector2(500, 300)
	add_child(settings_dialog)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(450, 250)
	settings_dialog.add_child(vbox)
	
	# Add settings controls here
	# Example: Volume slider
	var volume_label = Label.new()
	volume_label.text = "Volume"
	vbox.add_child(volume_label)
	
	var volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.value = 80
	vbox.add_child(volume_slider)
	
	# Add more settings as needed
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(func(): settings_dialog.hide())
	vbox.add_child(close_button)

func setup_about_dialog():
	about_dialog = PopupPanel.new()
	about_dialog.title = "About Us"
	about_dialog.size = Vector2(500, 300)
	add_child(about_dialog)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(450, 250)
	about_dialog.add_child(vbox)
	
	# Add about text
	var about_label = Label.new()
	about_label.text = "In The Streets: Godot Edition\n\nDeveloped by: Soul\n\nA remake of the classic In The Streets game using Godot Engine."
	about_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(about_label)
	
	# Credits
	var credits_label = Label.new()
	credits_label.text = "\nCredits:\n- Original Dope Wars concept by John E. Dell\n- Remake Programming: Soul\n- Graphics: *\n- Music: *"
	credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(credits_label)
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(func(): about_dialog.hide())
	vbox.add_child(close_button)
