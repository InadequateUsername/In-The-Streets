extends Node
class_name LocationSystem

# Signal to notify other systems of location changes
signal location_changed(new_location)
signal travel_completed(travel_time)

# References to main game and UI
var main_game
var location_label

# Locations and their properties
var locations = {
	"Erie": {"danger": 0.1, "description": "Low crime area with moderate police presence."},
	"York": {"danger": 0.25, "description": "High crime area with heavy police presence."},
	"Kensington": {"danger": 0.2, "description": "Medium crime area with dealers on every corner."},
	"Pittsburgh": {"danger": 0.25, "description": "High crime area controlled by mobsters."},
	"Love Park": {"danger": 0.1, "description": "Popular hangout spot with light police patrols."},
	"Reading": {"danger": 0.1, "description": "Quiet area with occasional drug activity."}
}

# Current location
var current_location = ""

func _ready():
	# Get reference to main game
	main_game = get_parent()
	
	# Get UI references
	location_label = main_game.get_node_or_null("MainContainer/TopSection/StatsContainer/LocationContainer/LocationLabel")
	
	# Connect location button signals
	if main_game.has_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Erie"):
		main_game.get_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Erie").pressed.connect(func(): change_location("Erie"))
	
	if main_game.has_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/York"):
		main_game.get_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/York").pressed.connect(func(): change_location("York"))
	
	if main_game.has_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Kensington"):
		main_game.get_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Kensington").pressed.connect(func(): change_location("Kensington"))
	
	if main_game.has_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Pittsburgh"):
		main_game.get_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Pittsburgh").pressed.connect(func(): change_location("Pittsburgh"))
	
	if main_game.has_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/LovePark"):
		main_game.get_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/LovePark").pressed.connect(func(): change_location("Love Park"))
	
	if main_game.has_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Reading"):
		main_game.get_node("MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Reading").pressed.connect(func(): change_location("Reading"))

# Set the initial location
func set_initial_location(location):
	if locations.has(location):
		current_location = location
		update_location_display()
		
		# Emit signal but don't trigger travel effects
		emit_signal("location_changed", current_location)

# Update the location display in the UI
func update_location_display():
	if is_instance_valid(location_label):
		location_label.text = "Currently In: " + current_location

# Changes the player's location with associated effects
func change_location(location):
	if location == current_location or !locations.has(location):
		return false
		
	# Calculate travel time (1-2 hours)
	var hours_passed = 1 + randi() % 2
	
	# Update current location
	current_location = location
	update_location_display()
	
	# Mark that we have unsaved changes
	main_game.has_unsaved_changes = true
	
	# Emit signals
	emit_signal("location_changed", current_location)
	emit_signal("travel_completed", hours_passed)
	
	return true

# Get the danger level of the current location
func get_current_danger_level():
	if locations.has(current_location):
		return locations[current_location].danger
	return 0.1  # Default danger level

# Get the description of the current location
func get_current_description():
	if locations.has(current_location):
		return locations[current_location].description
	return "Unknown area."

# Get all available locations
func get_all_locations():
	return locations.keys()

# Check if a location exists
func location_exists(location):
	return locations.has(location)
	
