extends PanelContainer

# Reference to the internal scroll container and text container
var scroll_container
var event_history_text

# Maximum number of events to store (optional)
var max_events = 100

# Array to store event history
var event_history = []

func _ready():
	# Set up the container with proper styling
	custom_minimum_size = Vector2(400, 180)
	
	# Add a title label
	var title = Label.new()
	title.text = "Event History"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Create main VBox
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(vbox)
	
	# Add title to VBox
	vbox.add_child(title)
	
	# Add a separator
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Create scroll container
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(scroll_container)
	
	# Create rich text label for event history
	event_history_text = RichTextLabel.new()
	event_history_text.bbcode_enabled = true
	event_history_text.size_flags_horizontal = SIZE_EXPAND_FILL
	event_history_text.size_flags_vertical = SIZE_EXPAND_FILL
	event_history_text.scroll_following = true  # Auto-scroll to latest event
	scroll_container.add_child(event_history_text)
	
	# Connect to the event system signals
	var event_system = get_node_or_null("/root/Control/EventSystem")
	if event_system:
		if not event_system.is_connected("event_triggered", Callable(self, "_on_event_triggered")):
			event_system.connect("event_triggered", Callable(self, "_on_event_triggered"))
	else:
		# Wait for the event system to be created
		await get_tree().process_frame
		event_system = get_node_or_null("/root/Control/EventSystem")
		if event_system:
			if not event_system.is_connected("event_triggered", Callable(self, "_on_event_triggered")):
				event_system.connect("event_triggered", Callable(self, "_on_event_triggered"))

# Called when a new event is triggered
func _on_event_triggered(event_data):
	# Format event with day/time prefix
	var main_game = get_node_or_null("/root/Control")
	var time_prefix = ""
	
	if main_game and main_game.has_method("get_time_string"):
		time_prefix = main_game.get_time_string() + " - "
	elif main_game:
		# Fallback if get_time_string doesn't exist
		var am_pm = "AM" if main_game.game_hour < 12 else "PM"
		var display_hour = main_game.game_hour
		if display_hour == 0:
			display_hour = 12
		elif display_hour > 12:
			display_hour -= 12
		time_prefix = "Day " + str(main_game.game_day) + " " + str(display_hour) + ":00 " + am_pm + " - "
	
	# Format the event text
	var event_text = format_event(event_data, time_prefix)
	
	# Add to history array
	event_history.append(event_text)
	
	# Trim history if needed
	if event_history.size() > max_events:
		event_history.pop_front()
	
	# Update the display
	update_display()

# Format event data into a readable string
func format_event(event_data, time_prefix=""):
	var text = time_prefix + "[b]" + event_data.title + "[/b]: " + event_data.description
	
	# Add effects if present
	if event_data.has("effects") and event_data.effects.size() > 0:
		text += "\n[color=#88FF88]Effects:[/color] "
		
		var effects_added = 0
		for effect_type in event_data.effects:
			var effect_value = event_data.effects[effect_type]
			
			match effect_type:
				"cash":
					if effect_value > 0:
						text += "[color=#88FF88]Cash +$" + str(abs(effect_value)) + "[/color] "
					else:
						text += "[color=#FF8888]Cash -$" + str(abs(effect_value)) + "[/color] "
				"health":
					if effect_value > 0:
						text += "[color=#88FF88]Health +" + str(abs(effect_value)) + "[/color] "
					else:
						text += "[color=#FF8888]Health -" + str(abs(effect_value)) + "[/color] "
				"heat":
					if effect_value > 0:
						text += "[color=#FF8888]Heat +" + str(abs(effect_value)) + "[/color] "
					else:
						text += "[color=#88FF88]Heat -" + str(abs(effect_value)) + "[/color] "
				"reputation":
					if effect_value > 0:
						text += "[color=#88FF88]Rep +" + str(abs(effect_value)) + "[/color] "
					else:
						text += "[color=#FF8888]Rep -" + str(abs(effect_value)) + "[/color] "
			
			effects_added += 1
			if effects_added >= 3:  # Limit to 3 effects per line
				text += "\n"
				effects_added = 0
	
	return text

# Update the displayed event history
func update_display():
	event_history_text.clear()
	
	for i in range(event_history.size()):
		var event = event_history[i]
		event_history_text.append_text(event)
		
		# Add separator between events
		if i < event_history.size() - 1:
			event_history_text.append_text("\n[color=#555555]-------------------------------------------[/color]\n")

# Add a custom event to the history (for scripted game events)
func add_custom_event(title, description, effects={}):
	var event_data = {
		"title": title,
		"description": description,
		"effects": effects
	}
	_on_event_triggered(event_data)

# Clear all events (called when starting a new game)
func clear_events():
	event_history.clear()
	update_display()


# Shows a temporary system message (for UI notifications)
func show_temporary_message(text, duration = 3.0):
	# Format with current time
	var time_prefix = ""
	var main_game = get_node("/root/Control")
	
	if main_game:
		var am_pm = "AM" if main_game.game_hour < 12 else "PM"
		var display_hour = main_game.game_hour
		if display_hour == 0:
			display_hour = 12
		elif display_hour > 12:
			display_hour -= 12
		time_prefix = "[color=#888888]Day " + str(main_game.game_day) + " " + str(display_hour) + ":00 " + am_pm + "[/color] - "
	
	# Add message to top of event history with special formatting
	var message_text = time_prefix + "[color=#FFFF99][b]System Message:[/b] " + text + "[/color]"
	
	# Insert at the beginning so it appears at the top
	event_history.insert(0, message_text)
	
	# Trim history if needed
	if event_history.size() > max_events:
		event_history.pop_back()
		
	# Update the display
	update_display()
	
	# Schedule removal of the temporary message after duration (optional)
	if duration > 0:
		get_tree().create_timer(duration).timeout.connect(func(): 
			# Remove the temporary message
			if event_history.size() > 0 and event_history[0] == message_text:
				event_history.remove_at(0)
				update_display()
		)
		
