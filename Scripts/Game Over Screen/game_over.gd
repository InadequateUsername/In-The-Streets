extends Control
# Signal to tell the main game what the player wants to do
signal action_selected(action)
# Store cause of death
var death_message = "You died."
func _ready():
	# Set the cause of death if it has been passed
	print("Game over screen ready, message: " + death_message)
	
	# Set the death message text
	if has_node("GameOverScreen/ColorRect/VBoxContainer/CauseOfDeath"):
		$GameOverScreen/ColorRect/VBoxContainer/CauseOfDeath.text = death_message
	
	# We need to find the buttons in our scene
	var _buttons = []
	
	# Try to find buttons by scanning entire scene
	var new_game_button = find_node_by_name_recursive(self, "NewGameButton")
	var load_game_button = find_node_by_name_recursive(self, "LoadGameButton")
	
	# Try alternate paths if not found
	if not new_game_button:
		new_game_button = find_button_with_text("New Game")
		print("Found New Game button by text: " + str(new_game_button != null))
	
	if not load_game_button:
		load_game_button = find_button_with_text("Load Game")
		print("Found Load Game button by text: " + str(load_game_button != null))
	
	# If buttons still not found, try looking in the ButtonsContainer directly
	if not new_game_button and has_node("GameOverScreen/ColorRect/VBoxContainer/ButtonsContainer"):
		var container = $GameOverScreen/ColorRect/VBoxContainer/ButtonsContainer
		for child in container.get_children():
			if child is Button:
				if child.text == "New Game":
					new_game_button = child
				elif child.text == "Load Game":
					load_game_button = child
	
	# Try direct path to buttons shown in the screenshot
	if not new_game_button:
		new_game_button = get_node_or_null("GameOverScreen/NewGameButton")
	
	if not load_game_button:
		load_game_button = get_node_or_null("GameOverScreen/LoadGameButton")
	
	# Connect buttons if found using direct approach
	if new_game_button:
		if not new_game_button.is_connected("pressed", Callable(self, "_on_new_game_button_pressed")):
			new_game_button.pressed.connect(_on_new_game_button_pressed)
			print("Connected New Game button")
	else:
		print("WARNING: Could not find New Game button!")
	
	if load_game_button:
		if not load_game_button.is_connected("pressed", Callable(self, "_on_load_game_button_pressed")):
			load_game_button.pressed.connect(_on_load_game_button_pressed)
			print("Connected Load Game button")
	else:
		print("WARNING: Could not find Load Game button!")
# Find a node by name recursively
func find_node_by_name_recursive(node, name):
	if node.name == name:
		return node
	
	for child in node.get_children():
		var found = find_node_by_name_recursive(child, name)
		if found:
			return found
	
	return null
# Find a button by its text
func find_button_with_text(button_text):
	var all_nodes = get_all_nodes(self)
	for node in all_nodes:
		if node is Button and node.text == button_text:
			print("Found button with text: " + button_text)
			return node
	return null
# Helper function to get all nodes in the scene
func get_all_nodes(node):
	var nodes = []
	nodes.append(node)
	
	for child in node.get_children():
		nodes.append_array(get_all_nodes(child))
	
	return nodes
# The player wants to load a game
func _on_load_game_button_pressed():
	# Let main game know they want to load
	print("Load game button pressed - emitting signal")
	emit_signal("action_selected", "load")
# The player wants to start a new game
func _on_new_game_button_pressed():
	# Let main game know they want a new game
	print("New game button pressed - emitting signal")
	emit_signal("action_selected", "new_game")
# Public method to set the cause of death
func set_death_message(message):
	print("Setting death message: " + message)
	death_message = message
	# If the node is already in the tree, update it
	if has_node("GameOverScreen/ColorRect/VBoxContainer/CauseOfDeath"):
		$GameOverScreen/ColorRect/VBoxContainer/CauseOfDeath.text = message
