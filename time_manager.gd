extends Node
class_name TimeManager

# Signal to notify other systems of time changes
signal hour_passed(current_hour)
signal day_changed(new_day)
signal night_started
signal day_started

# References to main game and UI
var main_game
var time_display_label

# Time system variables
var game_hour = 8       # Start at 8 AM
var game_day = 1        # Start on day 1
var day_night_cycle = true
var time_speed = 5      # Game hours per real minute (adjust as needed)

# Day/Night threshold hours
const DAY_START_HOUR = 6
const NIGHT_START_HOUR = 18

func _ready():
	# Get reference to main game
	main_game = get_parent()
	
	# Get UI references
	time_display_label = main_game.get_node_or_null("MainContainer/TopSection/StatsContainer/LocationContainer/TimerContainer/TimeDisplayLabel")
	
	if not is_instance_valid(time_display_label):
		# Try direct path as seen in the screenshot
		time_display_label = main_game.get_node_or_null("TimerContainer/TimeDisplayLabel")
		
		if not is_instance_valid(time_display_label):
			# Final fallback - search the entire tree
			time_display_label = find_node_by_name_recursive(main_game, "TimeDisplayLabel")
			
	if not is_instance_valid(time_display_label):
		print("WARNING: TimeDisplayLabel not found!")
	else:
		# Update display initially
		update_time_display()
	
	# Configure the timer node
	var date_timer = find_node_by_name_recursive(main_game, "DateTimer")
	
	if is_instance_valid(date_timer):
		date_timer.wait_time = 60.0 / time_speed  # Convert to seconds
		date_timer.autostart = true
		date_timer.one_shot = false
		
		# Disconnect any existing connections to avoid duplicates
		if date_timer.is_connected("timeout", Callable(self, "_on_time_tick")):
			date_timer.timeout.disconnect(_on_time_tick)
			
		# Connect the timer
		date_timer.timeout.connect(_on_time_tick)
	else:
		print("WARNING: DateTimer node not found! Creating a new one.")
		var new_timer = Timer.new()
		new_timer.name = "DateTimer"
		new_timer.wait_time = 60.0 / time_speed
		new_timer.autostart = true
		new_timer.one_shot = false
		main_game.add_child(new_timer)
		new_timer.timeout.connect(_on_time_tick)

# Advances time by one hour (called by timer)
func _on_time_tick():
	# Advance time by 1 hour
	game_hour += 1
	
	# Emit the hour passed signal
	emit_signal("hour_passed", game_hour)
	
	# Check for day/night transition
	if game_hour == DAY_START_HOUR:
		emit_signal("day_started")
	elif game_hour == NIGHT_START_HOUR:
		emit_signal("night_started")
	
	# Handle day change
	if game_hour >= 24:
		game_hour = 0
		game_day += 1
		
		# Emit day changed signal
		emit_signal("day_changed", game_day)
		
		# Process daily events
		process_daily_events()
	
	# Update UI with new time
	update_time_display()
	
	# Apply time-of-day effects
	apply_time_of_day_effects()

# Updates the time display in the UI
func update_time_display():
	if is_instance_valid(time_display_label):
		# Format the time display
		var am_pm = "AM" if game_hour < 12 else "PM"
		var display_hour = game_hour
		if display_hour == 0:
			display_hour = 12
		elif display_hour > 12:
			display_hour -= 12
			
		time_display_label.text = "Day " + str(game_day) + " • " + str(display_hour) + ":00 " + am_pm
		
		# Change color based on time of day
		if game_hour >= DAY_START_HOUR and game_hour < NIGHT_START_HOUR:
			# Daytime - use normal color
			time_display_label.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			# Nighttime - use slightly blue tint
			time_display_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))

# Process events that happen daily
func process_daily_events():
	# Log to event history
	var events_container = main_game.get_node_or_null("EventsContainer")
	if events_container and events_container.has_method("add_custom_event"):
		var summary = "A new day has begun."
		var effects = {}
		
		if main_game.debt > 0:
			var interest = int(main_game.debt * 0.1)
			summary += " Loan shark applied $" + str(interest) + " interest."
			effects["debt"] = interest
		
		if main_game.bank > 0:
			var interest = int(main_game.bank * 0.025)
			summary += " Bank added $" + str(interest) + " interest."
			effects["bank"] = interest
		
		events_container.add_custom_event("New Day", summary, effects)
	
	# Process loan interest
	if main_game.debt > 0:
		# 10% daily interest on loans
		var interest = int(main_game.debt * 0.1)
		main_game.debt += interest
		main_game.show_message("Loan Shark applied daily interest: $" + str(interest))
	
	# Process bank interest
	if main_game.bank > 0:
		# 2.5% daily interest on savings
		var interest = int(main_game.bank * 0.025)
		main_game.bank += interest
		main_game.show_message("Bank added daily interest: $" + str(interest))
	
	# Random market events
	if randf() < 0.3:  # 30% chance
		main_game.get_node("MarketSystem").update_market_prices(main_game.get_node("LocationSystem").current_location)
		main_game.update_market_display()
		main_game.show_message("Market prices have changed with the new day")
	
	# Update UI
	main_game.update_stats_display()
	main_game.has_unsaved_changes = true

# Apply effects based on time of day
func apply_time_of_day_effects():
	# Different events or modifiers can happen at different times
	var event_system = main_game.get_node_or_null("EventSystem")
	
	# More dangerous at night (higher combat chance)
	if game_hour >= 22 or game_hour < 5:
		# Nighttime is more dangerous
		if event_system:
			event_system.event_chance = 0.4  # 40% chance of random events at night
	else:
		# Daytime is safer
		if event_system:
			event_system.event_chance = 0.3  # 30% chance during day
	
	# Market closed late at night
	if game_hour >= 2 and game_hour < 6:
		var market_list = main_game.get_node_or_null("MainContainer/BottomSection/MarketContainer/MarketList")
		if market_list and market_list.get_child_count() > 0:
			# Market is closed - can't buy/sell during these hours
			market_list.clear()
			market_list.add_item(["MARKET CLOSED", "COME BACK LATER"])
	else:
		# Market is open, ensure prices are displayed
		var market_list = main_game.get_node_or_null("MainContainer/BottomSection/MarketContainer/MarketList")
		if market_list and main_game.get_node("LocationSystem").current_location != "" and (market_list.get_child_count() <= 0 or market_list.rows.size() <= 1):
			main_game.update_market_display()

# Advance time by a specific number of hours
func advance_time(hours):
	for i in range(hours):
		game_hour += 1
		
		# Emit the hour passed signal
		emit_signal("hour_passed", game_hour)
		
		# Check for day/night transition
		if game_hour == DAY_START_HOUR:
			emit_signal("day_started")
		elif game_hour == NIGHT_START_HOUR:
			emit_signal("night_started")
		
		if game_hour >= 24:
			game_hour = 0
			game_day += 1
			
			# Emit day changed signal
			emit_signal("day_changed", game_day)
			
			# Process daily events
			process_daily_events()
	
	# Update UI after all hours have been processed
	update_time_display()
	apply_time_of_day_effects()

# Returns a formatted time string
func get_time_string():
	var am_pm = "AM" if game_hour < 12 else "PM"
	var display_hour = game_hour
	if display_hour == 0:
		display_hour = 12
	elif display_hour > 12:
		display_hour -= 12
		
	return "Day " + str(game_day) + " " + str(display_hour) + ":00 " + am_pm

# Set the time (for loading saved games)
func set_time(hour, day):
	game_hour = hour
	game_day = day
	update_time_display()

# Helper function to find a node by name recursively
func find_node_by_name_recursive(node, name):
	if node.name == name:
		return node
	
	for child in node.get_children():
		var found = find_node_by_name_recursive(child, name)
		if found:
			return found
	
	return null

# Check if it's currently daytime
func is_daytime():
	return game_hour >= DAY_START_HOUR and game_hour < NIGHT_START_HOUR

# Check if a specific time period has elapsed since another time
func has_time_elapsed(start_hour, start_day, hours):
	var total_start_hours = start_day * 24 + start_hour
	var total_current_hours = game_day * 24 + game_hour
	
	return total_current_hours - total_start_hours >= hours
