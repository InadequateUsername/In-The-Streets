extends Control

#==============================================================================
# GAME CONSTANTS AND CONFIGURATIONS
#==============================================================================

# Preloaded scenes
const CellphoneUI = preload("res://Scripts/Cellphone/cellphone_ui.tscn")
const GameOverScreen = preload("res://game_over.tscn")

# File paths
var save_file_path = "user://in_the_streets_save.json"

#==============================================================================
# PLAYER STATS
#==============================================================================

# Base player stats
var cash = 2000
var bank = 0
var debt = 5000
var health = 100
var heat = 0                # Police attention
var max_heat = 100
var reputation = 0          # Reputation in the drug world
var max_reputation = 100
var has_unsaved_changes = false

#==============================================================================
# TIME SYSTEM
#==============================================================================

# Time system variables
var game_hour = 8       # Start at 8 AM
var game_day = 1        # Start on day 1
var day_night_cycle = true
var time_speed = 5      # Game hours per real minute (adjust as needed)
var time_display_label

#==============================================================================
# INVENTORY SYSTEM
#==============================================================================

# Guns and weapons
var guns = 0
var equipped_weapon = ""
var owned_weapons = {}

# Weapons configuration
var weapons = {
	"Pistol": {"price": 1000, "durability": 100, "damage": 10, "rep_required": 0},
	"Shotgun": {"price": 2500, "durability": 80, "damage": 25, "rep_required": 20},
	"Uzi": {"price": 3500, "durability": 90, "damage": 15, "rep_required": 30},
	"Assault Rifle": {"price": 5000, "durability": 95, "damage": 35, "rep_required": 50},
	"Sniper Rifle": {"price": 7000, "durability": 85, "damage": 60, "rep_required": 75}
}

# Medical supplies
var medical_supplies = {
	"Bandages": {"price": 50, "qty": 0, "health_restore": 15}
}

#==============================================================================
# Location System
#==============================================================================

# Current location
var current_location = ""

#==============================================================================
# UI DIALOGS & REFERENCES
#==============================================================================

# Dialog references
var save_dialog
var load_dialog
var market_dialog
var bank_dialog
var loan_shark_dialog
var gun_dealer_dialog
var weapon_inventory_dialog
var combat_dialog

# UI control references
@onready var cash_label = $MainContainer/TopSection/StatsContainer/CashRow/CashValue
@onready var health_progress = $MainContainer/TopSection/StatsContainer/HealthContainer/HealthRow/HealthBar
@onready var market_list = $MainContainer/BottomSection/MarketContainer/MarketList
@onready var inventory_list = $MainContainer/BottomSection/InventoryContainer/InventoryList
@onready var location_label = $MainContainer/TopSection/StatsContainer/LocationContainer/LocationLabel
@onready var capacity_label = $MainContainer/BottomSection/InventoryContainer/PanelContainer/CapacityLabel
@onready var heat_value = $MainContainer/TopSection/StatsContainer/HeatRow/HeatValue
@onready var reputation_value = $MainContainer/TopSection/StatsContainer/RepRow/RepValue

# Input fields for dialogs
var quantity_slider
var loan_amount_input
var loan_amount = 0
var bank_amount_input
var bank_amount = 0
var confirm_button
var cancel_button
var payback_button
var borrow_button
var deposit_button
var withdraw_button

# Helper variables
var message_label
var message_timer = 0
var message_duration = 3.0  # How long messages stay on screen
var auto_save = true
var cellphone_instance

#==============================================================================
# COMBAT SYSTEM
#==============================================================================

var in_combat = false
var enemy_health = 0
var enemy_name = ""
var enemy_damage = 0
var enemy_initial_health = 0
var game_over = false

#==============================================================================
# EVENT SYSTEM
#==============================================================================

var event_system

#==============================================================================
# INITIALIZATION AND MAIN GAME LOOP
#==============================================================================

func _ready():
	# Check if we're coming from the title screen with a "new game" flag
	var start_new = false
	if get_tree().root.has_meta("start_new_game") and get_tree().root.get_meta("start_new_game"):
		# Clear the flag
		get_tree().root.set_meta("start_new_game", false)
		start_new = true
		print("New game flag detected from title screen")
	
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Create inventory system
	var inventory_system = Node.new()
	inventory_system.name = "InventorySystem"
	inventory_system.set_script(load("res://inventory_system.gd"))
	add_child(inventory_system)
	
	# Connect to the inventory system's signals
	$InventorySystem.inventory_changed.connect(_on_inventory_changed)
	$InventorySystem.capacity_changed.connect(_on_capacity_changed)
	$InventorySystem.drug_purchased.connect(_on_drug_purchased)
	$InventorySystem.drug_sold.connect(_on_drug_sold)
	
	# Connect to the market system's signals
	$MarketSystem.connect("market_updated", Callable(self, "_on_market_updated"))
	$MarketSystem.connect("market_event_triggered", Callable(self, "_on_market_event_triggered"))
	
	# Set up UI elements and systems
	setup_message_system()
	setup_file_dialogs()
	setup_bank_dialog()
	setup_loan_shark_dialog()
	setup_cellphone()
	setup_time_system()
	# Connect bank button
	if has_node("MainContainer/BottomSection/ActionButtons/GridContainer/BankButton"):
		$MainContainer/BottomSection/ActionButtons/GridContainer/BankButton.pressed.connect(show_bank_dialog)
	
	if has_node("MainContainer/BottomSection/ActionButtons/GridContainer/BackpackButton"):
		var backpack_button = $MainContainer/BottomSection/ActionButtons/GridContainer/BackpackButton
		# Disconnect any existing connections to avoid duplicates
		if backpack_button.is_connected("pressed", Callable(self, "show_weapon_inventory")):
			backpack_button.disconnect("pressed", Callable(self, "show_weapon_inventory"))
		# Connect the button
		backpack_button.pressed.connect(show_weapon_inventory)
		print("Connected backpack button")
	else:
		print("WARNING: BackpackButton not found in expected path")
		# Try to find it elsewhere in the scene tree
		var all_nodes = get_all_nodes(self)
		for node in all_nodes:
			if node is Button and (node.name == "BackpackButton" or "Backpack" in node.text):
				node.pressed.connect(show_weapon_inventory)
				print("Found and connected alternative backpack button")
				break
	
	# Connect game buttons
	if has_node("MainContainer/BottomSection/GameButtons/Spacer/NewGameButton"):
		$MainContainer/BottomSection/GameButtons/Spacer/NewGameButton.pressed.connect(start_new_game)
	
	if has_node("MainContainer/BottomSection/GameButtons/Spacer/SaveGameButton"):
		$MainContainer/BottomSection/GameButtons/Spacer/SaveGameButton.pressed.connect(save_game)
	
	if has_node("MainContainer/BottomSection/GameButtons/Spacer/LoadGameButton"):
		$MainContainer/BottomSection/GameButtons/Spacer/LoadGameButton.pressed.connect(load_game)

	# Initialize UI display 
	update_stats_display()
	
	# Setup event history
	setup_event_history()
	
	# Initialize the lists with proper sizing
	initialize_lists()
	
	# Connect location button signals
	$MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Erie.pressed.connect(func(): change_location("Erie"))
	$MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/York.pressed.connect(func(): change_location("York"))
	$MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Kensington.pressed.connect(func(): change_location("Kensington"))
	$MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Pittsburgh.pressed.connect(func(): change_location("Pittsburgh"))
	$MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/LovePark.pressed.connect(func(): change_location("Love Park"))
	$MainContainer/TopSection/StatsContainer/LocationContainer/LocationButtons/Reading.pressed.connect(func(): change_location("Reading"))
	
	# Connect CellphoneButton
	if has_node("MainContainer/BottomSection/ActionButtons/GridContainer/CellphoneButton"):
		$MainContainer/BottomSection/ActionButtons/GridContainer/CellphoneButton.pressed.connect(func(): show_cellphone())
	
	var real_path = ProjectSettings.globalize_path(save_file_path)
	print("Save file absolute path: " + real_path)
	
	setup_event_system()
	
	# If we should start a new game (from title screen), do that directly
	if start_new:
		new_game()
	else:
		# Otherwise try to load the game on startup
		var loaded = auto_load_game()
		if not loaded:
			# If no save file, start a new game
			new_game()
	
	print("Game initialization complete")

func _process(delta):
	# Handle message timeout
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_label.visible = false

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Close request received!")
		if auto_save:
			print("Auto-save is enabled, attempting to save...")
			# Directly save without any await
			_direct_save_no_wait()
		print("Quitting game...")
		get_tree().quit()

func _direct_save_no_wait():
	var save_data = {
		"player": {
			"cash": int(cash),
			"bank": int(bank), 
			"debt": int(debt),
			"guns": int(guns),
			"health": int(health),
			"current_capacity": int($InventorySystem.current_capacity),
			"heat": int(heat),
			"reputation": int(reputation),
			"weapons": {},  # Will fill separately
			"equipped_weapon": equipped_weapon,
			"medical_supplies": {}  # Will fill separately
		},
		"location": current_location,
		"time": {
			"game_hour": int(game_hour),
			"game_day": int(game_day)
		},
		"drugs": {}
	}

	# Get drugs from inventory system
	var drugs_data = $InventorySystem.get_drug_data()
	for drug_name in drugs_data:
		save_data["drugs"][drug_name] = {
			"price": int(drugs_data[drug_name]["price"]),
			"qty": int(drugs_data[drug_name]["qty"])
		}

	# Convert owned_weapons to a simple serializable format
	for weapon_name in owned_weapons:
		save_data["player"]["weapons"][weapon_name] = {
			"durability": int(owned_weapons[weapon_name].durability),
			"damage": int(owned_weapons[weapon_name].damage)
		}

	# Convert medical supplies to a simple serializable format
	for item_name in medical_supplies:
		save_data["player"]["medical_supplies"][item_name] = {
			"price": int(medical_supplies[item_name].price),
			"qty": int(medical_supplies[item_name].qty),
			"health_restore": int(medical_supplies[item_name].health_restore)
		}
	
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
		print("Game auto-saved successfully to: " + save_file_path)
	else:
		var error_code = FileAccess.get_open_error()
		print("Failed to auto-save game. Error code: " + str(error_code) + " - " + _get_file_error_message(error_code))

#==============================================================================
# MESSAGE SYSTEM
#==============================================================================

# Sets up the message display system for game notifications
func setup_message_system():
	# Still create the message_label as a fallback
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.custom_minimum_size = Vector2(400, 50)
	message_label.visible = false  # Start hidden
	add_child(message_label)
	
	# Rest of the setup remains the same...
	message_label.anchor_bottom = 1.0
	message_label.anchor_right = 1.0
	message_label.anchor_left = 0.0
	message_label.offset_bottom = -20
	
	message_label.add_theme_color_override("font_color", Color.WHITE)
	
	var panel = Panel.new()
	message_label.add_child(panel)
	panel.show_behind_parent = true
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.2)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)

# Shows a message to the player for a specified duration
func show_message(text, duration = 3.0):
	# Always log to EventsContainer
	var events_container = get_node_or_null("EventsContainer")
	if events_container and events_container.has_method("show_temporary_message"):
		events_container.show_temporary_message(text, duration)
	
	# Check if this is a message that should still show as a popup
	var show_as_popup = false
	
	# List of keywords that indicate important messages that should still pop up
	var important_keywords = ["combat", "attacked", "ambushed", "fight", "encounter", "shady", "defeated"]
	
	# Check if any keywords are in the message
	for keyword in important_keywords:
		if keyword.to_lower() in text.to_lower():
			show_as_popup = true
			break
	
	# Show popup for important messages
	if show_as_popup:
		message_label.text = text
		message_label.visible = true
		message_timer = duration

#==============================================================================
# UI UPDATE FUNCTIONS
#==============================================================================

# Updates all player stats displays in the UI
func update_stats_display():
	cash_label.text = str(int(cash))
	health_progress.value = int(health)
	heat_value.text = str(int(heat))
	reputation_value.text = str(int(reputation))

func update_market_display():
	market_list.clear()
	
	if current_location.is_empty():
		return
	
	# Get current prices from MarketSystem
	var drug_prices = $MarketSystem.get_current_prices()

	market_list.set_columns(["Drug", "Price"], [0.6, 0.4])

	for drug_name in drug_prices:
		if drug_name != "event_drug":  # Skip internal marker
			market_list.add_item([drug_name, "$" + str(drug_prices[drug_name])])

# Initializes market and inventory lists with proper sizing
func initialize_lists():
	$MainContainer/BottomSection/MarketContainer/MarketList.custom_minimum_size = Vector2(0, 200)
	$MainContainer/BottomSection/InventoryContainer/InventoryList.custom_minimum_size = Vector2(0, 200)
	
	await get_tree().process_frame
	
	var market_container = $MainContainer/BottomSection/MarketContainer
	var inventory_container = $MainContainer/BottomSection/InventoryContainer
	
	market_list.size = Vector2(market_container.size.x, 200)
	inventory_list.size = Vector2(inventory_container.size.x, 200)
	
	update_market_display()

# Updates drug prices and handles events when changing location
func change_location(location):
	# Time passes when changing locations (1-2 hours)
	var hours_passed = 1 + randi() % 2
	advance_time(hours_passed)

	# Show time passage message
	show_message("Traveling took " + str(hours_passed) + " hours")

	# Update current location
	current_location = location
	location_label.text = "Currently In: " + location

	# Update prices when changing location
	$MarketSystem.update_market_prices(location)

	# Mark that we have unsaved changes
	has_unsaved_changes = true

	# Check for NON-HARMFUL events only
	if event_system:
		event_system.check_for_travel_event(location)
	
	# Keep the combat chance calculation, but we'll modify it to be less harmful
	var combat_chance = 0.1  # Base 10% chance

	if location in ["York", "Pittsburgh"]:
		combat_chance = 0.25  # 25% chance
	elif location in ["Kensington"]:
		combat_chance = 0.2  # 20% chance

	# Log to event history
	var events_container = get_node_or_null("EventsContainer")
	if events_container and events_container.has_method("add_custom_event"):
		events_container.add_custom_event("Location Change", 
			"You traveled to " + location + ".",
			{"time": hours_passed})

	# Roll for ambush
	var roll = randf()
	
	if roll < combat_chance:
		# Re-enable these lines to trigger combat:
		await get_tree().create_timer(1.0).timeout
		start_combat()

#==============================================================================
# BUYING/SELLING SYSTEM
#==============================================================================
	
	# Add this new function to trigger a police event when heat reaches maximum
# Updated trigger_police_event function that uses the game's existing event system
func trigger_police_event():
	# Reset heat to zero
	heat = 0
	update_stats_display()
	show_message("The police are onto you! Heat reset to 0")
	
	# Define possible police events
	var police_events = [
		{
			"title": "Police Raid",
			"description": "The police raid your current location! You barely escape, but lose some of your drugs and cash.",
			"effects": {
				"cash": -int(cash * 0.2),  # Lose 20% of cash
				"inventory": -0.5,  # Lose 50% of inventory
				"health": -10
			}
		},
		{
			"title": "Drug Bust",
			"description": "You're caught in a drug bust! You manage to talk your way out, but the police take your drugs as evidence.",
			"effects": {
				"inventory": -0.5,  # Lose 50% of inventory
			}
		},
		{
			"title": "Police Chase",
			"description": "Police spot you selling and give chase! You escape, but drop some of your stash in the process.",
			"effects": {
				"inventory": -0.2,  # Lose 20% of inventory
				"health": -15,
				"cash": -int(cash * 0.1)  # Lose 10% of cash
			}
		},
		{
			"title": "Anonymous Tip",
			"description": "Someone gave the police an anonymous tip about you. You're searched but they find nothing substantial.",
			"effects": {
				"cash": -500,  # Small bribe/fine
			}
		},
		{
			"title": "Undercover Sting",
			"description": "You accidentally try to sell to an undercover cop! You run away, but lose your drugs and get injured.",
			"effects": {
				"inventory": -0.4,  # Lose 40% of inventory
				"health": -25
			}
		}
	]
	
	# Select a random police event
	var random_index = randi() % police_events.size()
	var selected_event = police_events[random_index]
	
	# Use the event_system to process the event
	if event_system:
		event_system.process_event(selected_event, self)
	else:
		# Fallback if event_system is null
		show_message(selected_event.title + ": " + selected_event.description)
		
		# Apply effects manually
		if "cash" in selected_event.effects:
			add_cash(selected_event.effects.cash)
		
		if "health" in selected_event.effects:
			add_health(selected_event.effects.health)
			
		if "reputation" in selected_event.effects:
			add_reputation(selected_event.effects.reputation)
			
		if "inventory" in selected_event.effects and selected_event.effects.inventory < 0:
			# Reduce inventory
			if selected_event.effects.has("inventory") and selected_event.effects.inventory < 0:
				var reduction = abs(selected_event.effects.inventory)
				$InventorySystem.reduce_inventory(reduction)
			
			# Update capacity
			$InventorySystem.calculate_current_capacity()
			$InventorySystem.update_inventory_display()


#==============================================================================
# BLACK MARKET/MEDICAL SUPPLIES
#==============================================================================

# Sets up the market dialog for medical supplies
func setup_market_dialog():
	market_dialog = PopupPanel.new()
	market_dialog.title = "Black Market"
	add_child(market_dialog)
	
	# Set size limits for consistency with other menus
	market_dialog.min_size = Vector2(350, 350)
	market_dialog.max_size = Vector2(450, 450)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 350)
	market_dialog.add_child(vbox)
	
	# Title with emoji
	var title_container = HBoxContainer.new()
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(title_container)
	
	var market_emoji = Label.new()
	market_emoji.text = "💊"  # Pill emoji for black market
	market_emoji.add_theme_font_size_override("font_size", 24)
	title_container.add_child(market_emoji)
	
	var title_label = Label.new()
	title_label.text = "Black Market"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color("#FF5555"))
	title_container.add_child(title_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = "Get your supplies here. No questions asked."
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_label)
	
	# Separator
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Cash display with icon
	var info_container = VBoxContainer.new()
	info_container.name = "InfoContainer"
	vbox.add_child(info_container)
	
	# Cash display with icon
	var cash_container = HBoxContainer.new()
	cash_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_container.add_child(cash_container)
	
	var cash_icon = Label.new()
	cash_icon.text = "💵"  # Cash emoji
	cash_icon.add_theme_font_size_override("font_size", 20)
	cash_container.add_child(cash_icon)
	
	var market_cash_label = Label.new()
	market_cash_label.name = "CashLabel"
	cash_label.text = "Your Cash: $" + str(int(cash))
	cash_label.add_theme_font_size_override("font_size", 16)
	cash_container.add_child(cash_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer1)
	
	# Items panel
	var items_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#333333")
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color("#666666")
	panel_style.set_corner_radius_all(5)
	items_panel.add_theme_stylebox_override("panel", panel_style)
	items_panel.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(items_panel)
	
	var items_vbox = VBoxContainer.new()
	items_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	items_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	items_vbox.custom_minimum_size = Vector2(0, 180)
	items_panel.add_child(items_vbox)
	
	# Items title
	var items_title = Label.new()
	items_title.text = "MEDICAL SUPPLIES"
	items_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_title.add_theme_font_size_override("font_size", 16)
	items_title.add_theme_color_override("font_color", Color("#00AAFF"))
	items_vbox.add_child(items_title)
	
	# Create bandages container
	var bandage_container = HBoxContainer.new()
	bandage_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bandage_container.size_flags_horizontal = SIZE_EXPAND_FILL
	items_vbox.add_child(bandage_container)
	
	# Bandage icon
	var bandage_icon = Label.new()
	bandage_icon.text = "🩹"  # Bandage emoji
	bandage_icon.add_theme_font_size_override("font_size", 20)
	bandage_container.add_child(bandage_icon)
	
	# Bandage info
	var bandage_info = VBoxContainer.new()
	bandage_info.size_flags_horizontal = SIZE_EXPAND_FILL
	bandage_container.add_child(bandage_info)
	
	var bandage_name = Label.new()
	bandage_name.text = "Bandages"
	bandage_name.add_theme_font_size_override("font_size", 16)
	bandage_info.add_child(bandage_name)
	
	# IMPORTANT: Make sure this node is directly in the VBoxContainer
	var bandage_desc = Label.new()
	bandage_desc.name = "BandageDesc"
	bandage_desc.text = "Price: $" + str(medical_supplies["Bandages"]["price"]) + " | Restores " + str(medical_supplies["Bandages"]["health_restore"]) + " HP\nYou have: " + str(medical_supplies["Bandages"]["qty"])
	bandage_info.add_child(bandage_desc)
	
	# Buy button
	var buy_button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = "Buy"
	buy_button.custom_minimum_size = Vector2(80, 40)
	buy_button.pressed.connect(func(): buy_bandages_from_dialog())
	bandage_container.add_child(buy_button)
	
	# Add additional items for sale here (if any)
	
	# Health tip
	var health_tip = Label.new()
	health_tip.text = "Tip: Use bandages to restore health after combat"
	health_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_tip.add_theme_font_size_override("font_size", 12)
	health_tip.add_theme_color_override("font_color", Color("#AAAAAA"))
	items_vbox.add_child(health_tip)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	close_button.pressed.connect(func(): 
		market_dialog.hide()
		# Show cellphone popup when closing
		if is_instance_valid(cellphone_instance):
			cellphone_instance.get_node("Popup").popup_centered()
	)
	vbox.add_child(close_button)

# Shows the black market dialog
func show_market():
	# Create dialog if it doesn't exist
	if not is_instance_valid(market_dialog):
		setup_market_dialog()
		await get_tree().process_frame  # Wait a frame for initialization

	# First, properly hide the phone if it's visible
	if is_instance_valid(cellphone_instance):
		cellphone_instance.hide()
		cellphone_instance.get_node("Popup").hide()
		if cellphone_instance.has_node("ClickBlocker"):
			cellphone_instance.get_node("ClickBlocker").visible = false

	# Update cash display
	var info_container = market_dialog.get_child(0).get_node_or_null("InfoContainer")
	if info_container:
		for child in info_container.get_children():
			if child is HBoxContainer:
				for subchild in child.get_children():
					if subchild is Label and subchild.name == "CashLabel":
						subchild.text = "Your Cash: $" + str(int(cash))
	
	# Find the bandage description in the items panel
	var vbox = market_dialog.get_child(0)
	var items_panel = null
	
	# Find the items panel
	for child in vbox.get_children():
		if child is Panel:
			items_panel = child
			break
	
	if items_panel:
		var items_vbox = items_panel.get_child(0)
		if items_vbox:
			# Look for the bandage container
			for child in items_vbox.get_children():
				if child is HBoxContainer:
					# Look for the bandage info
					for subchild in child.get_children():
						if subchild is VBoxContainer:
							for desc_child in subchild.get_children():
								if desc_child is Label and desc_child.name == "BandageDesc":
									desc_child.text = "Price: $" + str(medical_supplies["Bandages"]["price"]) + " | Restores " + str(medical_supplies["Bandages"]["health_restore"]) + " HP\nYou have: " + str(medical_supplies["Bandages"]["qty"])
							
					for btn_child in child.get_children():
						if btn_child is Button and btn_child.name == "BuyButton":
							btn_child.disabled = cash < medical_supplies["Bandages"]["price"]
	
	# Show the dialog
	market_dialog.popup_centered()

# Buys bandages from the market dialog
func buy_bandages_from_dialog():
	var price = medical_supplies["Bandages"]["price"]
	
	if cash >= price:
		cash -= price
		medical_supplies["Bandages"]["qty"] += 1
		
		# Update UI
		update_stats_display()
		show_message("Purchased bandages for $" + str(price))
		
		# Refresh market dialog with the updated information
		show_market()
	else:
		show_message("Not enough cash to buy bandages")

# Function to use bandages from the backpack
func use_bandages_from_backpack():
	if medical_supplies["Bandages"]["qty"] > 0:
		if health < 100:
			medical_supplies["Bandages"]["qty"] -= 1
			var health_restore = medical_supplies["Bandages"]["health_restore"]
			
			# Apply health but don't exceed max
			var old_health = health
			health = min(health + health_restore, 100)
			var actual_restore = health - old_health
			
			# Update UI
			update_stats_display()
			show_message("Used bandages and restored " + str(actual_restore) + " health")
			
			# Refresh backpack display
			show_weapon_inventory()
		else:
			show_message("You're already at full health")
	else:
		show_message("You don't have any bandages")

#==============================================================================
# BANKING SYSTEM
#==============================================================================

# Sets up the bank dialog UI
func setup_bank_dialog():
	bank_dialog = PopupPanel.new()
	bank_dialog.title = "Bank Operations"
	add_child(bank_dialog)
	
	# Set size limits for consistency with other menus
	bank_dialog.min_size = Vector2(350, 350)
	bank_dialog.max_size = Vector2(450, 450)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 350)
	bank_dialog.add_child(vbox)
	
	# Title
	var title_label = Label.new()
	title_label.text = "Soulioli Banking"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color("#0077FF"))  # Blue for banking
	vbox.add_child(title_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = "Secure your cash and manage your finances.\nNo questions asked."
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_label)
	
	# Separator
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Info container
	var info_container = VBoxContainer.new()
	info_container.name = "InfoContainer"
	info_container.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(info_container)
	
	# Cash display with icon
	var cash_container = HBoxContainer.new()
	cash_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_container.add_child(cash_container)
	
	var cash_icon = Label.new()
	cash_icon.text = "💵"  # Cash emoji
	cash_icon.add_theme_font_size_override("font_size", 20)
	cash_container.add_child(cash_icon)
	
	var cash_display = Label.new()
	cash_display.name = "Cash Display"
	cash_display.text = "Cash: $" + str(int(cash))
	cash_display.add_theme_font_size_override("font_size", 16)
	cash_container.add_child(cash_display)
	
	# Bank display with icon
	var bank_container = HBoxContainer.new()
	bank_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_container.add_child(bank_container)
	
	var bank_icon = Label.new()
	bank_icon.text = "🏦"  # Bank emoji
	bank_icon.add_theme_font_size_override("font_size", 20)
	bank_container.add_child(bank_icon)
	
	var bank_display = Label.new()
	bank_display.name = "Bank Display"
	bank_display.text = "Bank: $" + str(int(bank))
	bank_display.add_theme_font_size_override("font_size", 16)
	bank_container.add_child(bank_display)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	info_container.add_child(spacer1)
	
	# Transaction container
	var transaction_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#333333")
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color("#666666")
	panel_style.set_corner_radius_all(5)
	transaction_panel.add_theme_stylebox_override("panel", panel_style)
	transaction_panel.custom_minimum_size = Vector2(0, 120)
	info_container.add_child(transaction_panel)
	
	var transaction_vbox = VBoxContainer.new()
	transaction_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	transaction_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	transaction_vbox.custom_minimum_size = Vector2(0, 100)
	transaction_panel.add_child(transaction_vbox)
	
	# Transaction title
	var transaction_title = Label.new()
	transaction_title.text = "TRANSACTION"
	transaction_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transaction_title.add_theme_font_size_override("font_size", 16)
	transaction_title.add_theme_color_override("font_color", Color("#0077FF"))
	transaction_vbox.add_child(transaction_title)
	
	# Amount input container
	var input_container = HBoxContainer.new()
	input_container.alignment = BoxContainer.ALIGNMENT_CENTER
	input_container.custom_minimum_size = Vector2(0, 40)
	transaction_vbox.add_child(input_container)
	
	var input_label = Label.new()
	input_label.text = "Amount: $"
	input_container.add_child(input_label)
	
	bank_amount_input = LineEdit.new()
	bank_amount_input.placeholder_text = "Enter amount"
	bank_amount_input.text = "100"  # Default amount
	bank_amount_input.custom_minimum_size = Vector2(120, 0)
	input_container.add_child(bank_amount_input)
	
	bank_amount_input.text_changed.connect(func(new_text):
		if new_text.is_valid_int():
			bank_amount = int(new_text)
		else:
			bank_amount_input.text = str(bank_amount)
	)
	
	# Button container
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.custom_minimum_size = Vector2(0, 40)
	transaction_vbox.add_child(button_container)
	
	deposit_button = Button.new()
	deposit_button.text = "Deposit"
	deposit_button.custom_minimum_size = Vector2(100, 35)
	button_container.add_child(deposit_button)
	
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(10, 0)
	button_container.add_child(button_spacer)
	
	withdraw_button = Button.new()
	withdraw_button.text = "Withdraw"
	withdraw_button.custom_minimum_size = Vector2(100, 35)
	button_container.add_child(withdraw_button)
	
	# Final spacing
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)
	
	# Footer - shows interest rate info
	var footer = Label.new()
	footer.text = "Interest Rate: 2.5% Daily"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color("#AAAAAA"))
	vbox.add_child(footer)
	
	# Close button - making it bigger and more visible
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	vbox.add_child(close_button)
	
	deposit_button.pressed.connect(func(): deposit_money())
	withdraw_button.pressed.connect(func(): withdraw_money())
	
	close_button.pressed.connect(func(): 
		bank_dialog.hide()
		if is_instance_valid(cellphone_instance):
			cellphone_instance.get_node("Popup").popup_centered()
	)

# Shows the bank dialog with updated information
func show_bank_dialog():
	if not is_instance_valid(bank_dialog):
		setup_bank_dialog()
		return
	
	# First, properly hide the phone if it's visible
	if is_instance_valid(cellphone_instance):
		cellphone_instance.hide()
		cellphone_instance.get_node("Popup").hide()
		if cellphone_instance.has_node("ClickBlocker"):
			cellphone_instance.get_node("ClickBlocker").visible = false
	
	# Update the cash and bank displays
	var info_container = bank_dialog.get_child(0).get_node_or_null("InfoContainer")
	if info_container:
		for child in info_container.get_children():
			if child is HBoxContainer:
				for subchild in child.get_children():
					if subchild is Label and subchild.name == "Cash Display":
						subchild.text = "Cash: $" + str(int(cash))
					elif subchild is Label and subchild.name == "Bank Display":
						subchild.text = "Bank: $" + str(int(bank))
	
	# Show the dialog
	bank_dialog.popup_centered()

# Deposits money to the bank
func deposit_money():
	var amount = bank_amount
	
	if amount <= 0:
		show_message("Amount must be greater than 0")
		return
		
	if amount > cash:
		show_message("You don't have enough cash")
		return
		
	cash -= amount
	bank += amount
	
	update_stats_display()
	show_message("Deposited $" + str(amount) + " to bank")
	
	# Update the display in the bank dialog
	var info_container = bank_dialog.get_child(0).get_node_or_null("InfoContainer")
	if info_container:
		for child in info_container.get_children():
			if child is HBoxContainer:
				for subchild in child.get_children():
					if subchild is Label and subchild.name == "Cash Display":
						subchild.text = "Cash: $" + str(int(cash))
					elif subchild is Label and subchild.name == "Bank Display":
						subchild.text = "Bank: $" + str(int(bank))
	
	has_unsaved_changes = true

# Withdraws money from the bank
func withdraw_money():
	var amount = bank_amount
	
	if amount <= 0:
		show_message("Amount must be greater than 0")
		return
		
	if amount > bank:
		show_message("You don't have enough money in the bank")
		return
		
	bank -= amount
	cash += amount
	
	update_stats_display()
	show_message("Withdrew $" + str(amount) + " from bank")
	
	# Update the display in the bank dialog
	var info_container = bank_dialog.get_child(0).get_node_or_null("InfoContainer")
	if info_container:
		for child in info_container.get_children():
			if child is HBoxContainer:
				for subchild in child.get_children():
					if subchild is Label and subchild.name == "Cash Display":
						subchild.text = "Cash: $" + str(int(cash))
					elif subchild is Label and subchild.name == "Bank Display":
						subchild.text = "Bank: $" + str(int(bank))
	
	has_unsaved_changes = true

#==============================================================================
# LOAN SHARK SYSTEM
#==============================================================================

# Sets up the loan shark dialog UI
func setup_loan_shark_dialog():
	loan_shark_dialog = PopupPanel.new()
	loan_shark_dialog.title = "Loan Shark"
	add_child(loan_shark_dialog)
	
	# Set size limits for consistency with other menus
	loan_shark_dialog.min_size = Vector2(350, 350)
	loan_shark_dialog.max_size = Vector2(450, 450)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 350)
	loan_shark_dialog.add_child(vbox)
	
	# Title
	var title_label = Label.new()
	title_label.text = "Loan Shark Operations"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color("#FF5555"))  # Red for loan shark
	vbox.add_child(title_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = "Need cash fast? We're here to help.\nInterest is non-negotiable."
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_label)
	
	# Separator
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Info container
	var info_container = VBoxContainer.new()
	info_container.name = "InfoContainer"
	info_container.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(info_container)
	
	# Cash display with icon
	var cash_container = HBoxContainer.new()
	cash_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_container.add_child(cash_container)
	
	var cash_icon = Label.new()
	cash_icon.text = "💵"  # Cash emoji
	cash_icon.add_theme_font_size_override("font_size", 20)
	cash_container.add_child(cash_icon)
	
	var cash_display = Label.new()
	cash_display.name = "Cash Display"
	cash_display.text = "Cash: $" + str(int(cash))
	cash_display.add_theme_font_size_override("font_size", 16)
	cash_container.add_child(cash_display)
	
	# Debt display with icon
	var debt_container = HBoxContainer.new()
	debt_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_container.add_child(debt_container)
	
	var debt_icon = Label.new()
	debt_icon.text = "🔴"  # Red circle emoji for debt
	debt_icon.add_theme_font_size_override("font_size", 20)
	debt_container.add_child(debt_icon)
	
	var debt_display = Label.new()
	debt_display.name = "Debt Display"
	debt_display.text = "Current Debt: $" + str(int(debt))
	debt_display.add_theme_font_size_override("font_size", 16)
	debt_container.add_child(debt_display)
	
	# Interest rate display
	var interest_container = HBoxContainer.new()
	interest_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_container.add_child(interest_container)
	
	var interest_icon = Label.new()
	interest_icon.text = "⚠️"  # Warning emoji for interest
	interest_icon.add_theme_font_size_override("font_size", 20)
	interest_container.add_child(interest_icon)
	
	var interest_display = Label.new()
	interest_display.name = "Interest Display"
	interest_display.text = "Interest Rate: 10% Daily"
	interest_display.add_theme_font_size_override("font_size", 16)
	interest_display.add_theme_color_override("font_color", Color("#FF8888"))  # Light red for warning
	interest_container.add_child(interest_display)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	info_container.add_child(spacer1)
	
	# Transaction panel - with improved centering
	var transaction_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#333333")
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color("#666666")
	panel_style.set_corner_radius_all(5)
	transaction_panel.add_theme_stylebox_override("panel", panel_style)
	transaction_panel.custom_minimum_size = Vector2(0, 120)
	transaction_panel.size_flags_horizontal = SIZE_EXPAND_FILL  # Ensure panel uses full width
	info_container.add_child(transaction_panel)
	
	var transaction_vbox = VBoxContainer.new()
	transaction_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	transaction_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	transaction_vbox.custom_minimum_size = Vector2(0, 100)
	transaction_vbox.alignment = VBoxContainer.ALIGNMENT_CENTER  # Center content vertically
	transaction_panel.add_child(transaction_vbox)
	
	# Transaction title
	var transaction_title = Label.new()
	transaction_title.text = "TRANSACTION"
	transaction_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transaction_title.add_theme_font_size_override("font_size", 16)
	transaction_title.add_theme_color_override("font_color", Color("#FF5555"))
	transaction_vbox.add_child(transaction_title)
	
	# Amount input container - improved alignment
	var input_container = HBoxContainer.new()
	input_container.alignment = BoxContainer.ALIGNMENT_CENTER  # Center horizontally
	input_container.custom_minimum_size = Vector2(0, 40)
	input_container.size_flags_horizontal = SIZE_EXPAND_FILL
	transaction_vbox.add_child(input_container)
	
	var input_label = Label.new()
	input_label.text = "Amount: $"
	input_container.add_child(input_label)
	
	loan_amount_input = LineEdit.new()
	loan_amount_input.placeholder_text = "Enter amount"
	loan_amount_input.text = "100"  # Default amount
	loan_amount_input.custom_minimum_size = Vector2(120, 0)
	input_container.add_child(loan_amount_input)
	
	loan_amount_input.text_changed.connect(func(new_text):
		if new_text.is_valid_int():
			loan_amount = int(new_text)
		else:
			loan_amount_input.text = str(loan_amount)
	)
	
	# Button container - improved alignment
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER  # Center horizontally
	button_container.custom_minimum_size = Vector2(0, 40)
	button_container.size_flags_horizontal = SIZE_EXPAND_FILL
	transaction_vbox.add_child(button_container)
	
	payback_button = Button.new()
	payback_button.text = "Pay Debt"
	payback_button.custom_minimum_size = Vector2(100, 35)
	button_container.add_child(payback_button)
	
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(10, 0)
	button_container.add_child(button_spacer)
	
	borrow_button = Button.new()
	borrow_button.text = "Borrow"
	borrow_button.custom_minimum_size = Vector2(100, 35)
	button_container.add_child(borrow_button)
	
	# Warning label
	var warning_label = Label.new()
	warning_label.text = "Max borrowing limit: $10,000"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 12)
	warning_label.add_theme_color_override("font_color", Color("#FF8888"))
	transaction_vbox.add_child(warning_label)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)
	
	# Close button - making it bigger and more visible
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	vbox.add_child(close_button)
	
	payback_button.pressed.connect(func(): pay_debt())
	borrow_button.pressed.connect(func(): borrow_money())
	
	close_button.pressed.connect(func(): 
		loan_shark_dialog.hide()
		if is_instance_valid(cellphone_instance):
			cellphone_instance.get_node("Popup").popup_centered()
	)

# Shows the loan shark dialog
func show_loan_shark():
	if not is_instance_valid(loan_shark_dialog):
		setup_loan_shark_dialog()
		return
	
	# First, properly hide the phone if it's visible
	if is_instance_valid(cellphone_instance):
		cellphone_instance.hide()
		cellphone_instance.get_node("Popup").hide()
		if cellphone_instance.has_node("ClickBlocker"):
			cellphone_instance.get_node("ClickBlocker").visible = false
	
	# Update the cash and debt displays
	var info_container = loan_shark_dialog.get_child(0).get_node_or_null("InfoContainer")
	if info_container:
		for child in info_container.get_children():
			if child is HBoxContainer:
				for subchild in child.get_children():
					if subchild is Label and subchild.name == "Cash Display":
						subchild.text = "Cash: $" + str(int(cash))
					elif subchild is Label and subchild.name == "Debt Display":
						subchild.text = "Current Debt: $" + str(int(debt))
	
	# Show the dialog
	loan_shark_dialog.popup_centered()

# Pays back loan shark debt
func pay_debt():
	var amount = loan_amount
	
	if amount <= 0:
		show_message("Amount must be greater than 0")
		return
		
	if amount > cash:
		show_message("You don't have enough cash")
		return
		
	if amount > debt:
		show_message("You're trying to pay more than you owe")
		return
		
	cash -= amount
	debt -= amount
	
	update_stats_display()
	show_message("Paid $" + str(amount) + " to Loan Shark")
	
	# Update the display in the loan shark dialog
	var info_container = loan_shark_dialog.get_child(0).get_node_or_null("InfoContainer")
	if info_container:
		for child in info_container.get_children():
			if child is HBoxContainer:
				for subchild in child.get_children():
					if subchild is Label and subchild.name == "Cash Display":
						subchild.text = "Cash: $" + str(int(cash))
					elif subchild is Label and subchild.name == "Debt Display":
						subchild.text = "Current Debt: $" + str(int(debt))
	
	has_unsaved_changes = true

# Borrows money from the loan shark
func borrow_money():
	var amount = loan_amount
	
	if amount <= 0:
		show_message("Amount must be greater than 0")
		return
	
	var max_borrow = 10000
	if amount > max_borrow:
		show_message("Loan Shark won't lend more than $" + str(max_borrow) + " at once")
		return
	
	cash += amount
	debt += amount
	
	update_stats_display()
	show_message("Borrowed $" + str(amount) + " from Loan Shark")
	
	# Update the display in the loan shark dialog
	var info_container = loan_shark_dialog.get_child(0).get_node_or_null("InfoContainer")
	if info_container:
		for child in info_container.get_children():
			if child is HBoxContainer:
				for subchild in child.get_children():
					if subchild is Label and subchild.name == "Cash Display":
						subchild.text = "Cash: $" + str(int(cash))
					elif subchild is Label and subchild.name == "Debt Display":
						subchild.text = "Current Debt: $" + str(int(debt))
	
	has_unsaved_changes = true
	#==============================================================================
# CELLPHONE SYSTEM
#==============================================================================

# Sets up the cellphone UI
func setup_cellphone():
	cellphone_instance = CellphoneUI.instantiate()
	add_child(cellphone_instance)
	
	# Ensure the phone is properly hidden at startup
	cellphone_instance.hide()
	
	# Connect signal
	cellphone_instance.contact_selected.connect(_on_cellphone_contact_selected)

# Shows the cellphone UI
func show_cellphone():
	if cellphone_instance:
		# Use the custom show_phone method
		cellphone_instance.show_phone()

# Handles contact selection from the cellphone
func _on_cellphone_contact_selected(contact_name):
	match contact_name:
		"Loan Shark":
			show_loan_shark()
		"Gun Dealer":
			# Make sure the cellphone is properly hidden first
			if is_instance_valid(cellphone_instance):
				cellphone_instance.is_phone_active = false
				cellphone_instance.hide()
				if cellphone_instance.has_node("Popup"):
					cellphone_instance.get_node("Popup").hide()
				if cellphone_instance.has_node("ClickBlocker"):
					cellphone_instance.get_node("ClickBlocker").visible = false
			
			# Then show gun dealer
			show_gun_dealer()
		"Police Info":
			show_police_info()
		"Market":
			# Make sure the cellphone is properly hidden first
			if is_instance_valid(cellphone_instance):
				cellphone_instance.is_phone_active = false
				cellphone_instance.hide()
				if cellphone_instance.has_node("Popup"):
					cellphone_instance.get_node("Popup").hide()
				if cellphone_instance.has_node("ClickBlocker"):
					cellphone_instance.get_node("ClickBlocker").visible = false
			
			# Then show market
			show_market()
		"Soulioli Banking":
			# Important: Hide the cellphone entirely, not just the popup
			if is_instance_valid(cellphone_instance):
				cellphone_instance.is_phone_active = false
				cellphone_instance.hide()
				if cellphone_instance.has_node("Popup"):
					cellphone_instance.get_node("Popup").hide()
				if cellphone_instance.has_node("ClickBlocker"):
					cellphone_instance.get_node("ClickBlocker").visible = false
			
			show_bank_dialog()
		"Save Game":
			# Hide the cellphone
			if is_instance_valid(cellphone_instance):
				cellphone_instance.is_phone_active = false
				cellphone_instance.hide()
				if cellphone_instance.has_node("Popup"):
					cellphone_instance.get_node("Popup").hide()
				if cellphone_instance.has_node("ClickBlocker"):
					cellphone_instance.get_node("ClickBlocker").visible = false
					
			# Print the absolute file path to help debug
			var absolute_path = ProjectSettings.globalize_path(save_file_path)
			print("Attempting to save game to: " + absolute_path)
			
			# Instead of implementing save logic directly, call the existing save_game function
			# with false parameter to prevent showing the dialog
			save_game()
		"Load Game":
			# Hide the cellphone
			if is_instance_valid(cellphone_instance):
				cellphone_instance.is_phone_active = false
				cellphone_instance.hide()
				if cellphone_instance.has_node("Popup"):
					cellphone_instance.get_node("Popup").hide()
				if cellphone_instance.has_node("ClickBlocker"):
					cellphone_instance.get_node("ClickBlocker").visible = false
			
			# Call the load function
			load_game()
			
		"New Game":
			# Hide the cellphone
			if is_instance_valid(cellphone_instance):
				cellphone_instance.is_phone_active = false
				cellphone_instance.hide()
				if cellphone_instance.has_node("Popup"):
					cellphone_instance.get_node("Popup").hide()
				if cellphone_instance.has_node("ClickBlocker"):
					cellphone_instance.get_node("ClickBlocker").visible = false
			
			# Show confirmation dialog for starting a new game
			start_new_game()

# Shows police information via the cellphone
func show_police_info():
	var message = "Police activity in different locations:\n"
	message += "- High: York, Pittsburgh\n"
	message += "- Medium: Erie, Kensington\n"
	message += "- Low: Love Park, Reading\n"
	message += "\nCurrent location: " + current_location
	
	cellphone_instance.update_message(message)
	show_message("Police are active in " + current_location)

#==============================================================================
# WEAPONS AND GUN DEALER SYSTEM
#==============================================================================

# Sets up the gun dealer dialog UI
func setup_gun_dealer_dialog():
	gun_dealer_dialog = PopupPanel.new()
	gun_dealer_dialog.title = "Gun Dealer"
	add_child(gun_dealer_dialog)
	
	# Set size limits to ensure dialog fits on screen
	gun_dealer_dialog.min_size = Vector2(350, 400)
	gun_dealer_dialog.max_size = Vector2(450, 500)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 400)
	gun_dealer_dialog.add_child(vbox)
	
	# Title with emoji
	var title_container = HBoxContainer.new()
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(title_container)
	
	var gun_emoji = Label.new()
	gun_emoji.text = "🔫"  # Gun emoji
	gun_emoji.add_theme_font_size_override("font_size", 24)
	title_container.add_child(gun_emoji)
	
	var title_label = Label.new()
	title_label.text = "Underground Weapons"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color("#FF5555"))
	title_container.add_child(title_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = "Quality hardware, no questions asked.\nHigher reputation unlocks better weapons."
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_label)
	
	# Separator
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Cash and reputation display
	var info_container = VBoxContainer.new()
	info_container.name = "InfoContainer"
	vbox.add_child(info_container)
	
	# Cash display with icon
	var cash_container = HBoxContainer.new()
	cash_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_container.add_child(cash_container)
	
	var cash_icon = Label.new()
	cash_icon.text = "💵"  # Cash emoji
	cash_icon.add_theme_font_size_override("font_size", 20)
	cash_container.add_child(cash_icon)
	
	var bank_cash_label = Label.new()
	bank_cash_label.name = "CashDisplay"
	cash_label.text = "Your Cash: $" + str(int(cash))
	cash_label.add_theme_font_size_override("font_size", 16)
	cash_container.add_child(cash_label)
	
	# Reputation display with icon
	var rep_container = HBoxContainer.new()
	rep_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_container.add_child(rep_container)
	
	var rep_icon = Label.new()
	rep_icon.text = "⭐"  # Star emoji for reputation
	rep_icon.add_theme_font_size_override("font_size", 20)
	rep_container.add_child(rep_icon)
	
	var rep_label = Label.new()
	rep_label.name = "RepLabel"
	rep_label.text = "Reputation: " + str(reputation) + "/" + str(max_reputation)
	rep_label.add_theme_font_size_override("font_size", 16)
	rep_container.add_child(rep_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer1)
	
	# Weapon info container - styled panel
	var weapon_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#333333")
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color("#666666")
	panel_style.set_corner_radius_all(5)
	weapon_panel.add_theme_stylebox_override("panel", panel_style)
	weapon_panel.custom_minimum_size = Vector2(0, 220)
	vbox.add_child(weapon_panel)
	
	var weapon_info_container = VBoxContainer.new()
	weapon_info_container.name = "WeaponInfoContainer"
	weapon_info_container.size_flags_horizontal = SIZE_EXPAND_FILL
	weapon_info_container.size_flags_vertical = SIZE_EXPAND_FILL
	weapon_info_container.custom_minimum_size = Vector2(0, 200)
	weapon_panel.add_child(weapon_info_container)
	
	# Weapon selection title
	var weapon_title = Label.new()
	weapon_title.text = "WEAPONS"
	weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_title.add_theme_font_size_override("font_size", 16)
	weapon_title.add_theme_color_override("font_color", Color("#FF5555"))
	weapon_info_container.add_child(weapon_title)
	
	# Available weapon label
	var available_label = Label.new()
	available_label.name = "AvailableLabel"
	available_label.text = "Select Weapon:"
	available_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	available_label.add_theme_font_size_override("font_size", 16)
	weapon_info_container.add_child(available_label)
	
	# Weapon details
	var details_label = Label.new()
	details_label.name = "DetailsLabel"
	details_label.text = "Price: $--\nDamage: --\nDurability: --\nReputation Required: --"
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_info_container.add_child(details_label)
	
	# Status message
	var status_label = Label.new()
	status_label.name = "StatusLabel" 
	status_label.text = ""
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_info_container.add_child(status_label)
	
	# Button container
	var button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon_info_container.add_child(button_container)
	
	# Spacing
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)
	
	# Close button - making it bigger and more visible
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	close_button.pressed.connect(func(): 
		gun_dealer_dialog.hide()
		# Show cellphone popup when closing
		if is_instance_valid(cellphone_instance):
			cellphone_instance.get_node("Popup").popup_centered()
	)
	vbox.add_child(close_button)

# Shows the gun dealer dialog
func show_gun_dealer():
	# Initialize gun dealer dialog if it doesn't exist
	if not is_instance_valid(gun_dealer_dialog):
		setup_gun_dealer_dialog()
	
	# Make sure dialog exists after setup
	if not is_instance_valid(gun_dealer_dialog):
		print("Failed to create Gun Dealer dialog")
		return
	
	# Update cash and reputation displays
	var dialog_container = gun_dealer_dialog.get_child(0)
	if not dialog_container:
		print("VBox container not found in gun_dealer_dialog")
		return
		
	var info_container = dialog_container.get_node_or_null("InfoContainer")
	if info_container:
		for child in info_container.get_children():
			if child is HBoxContainer:
				for subchild in child.get_children():
					if subchild is Label and subchild.name == "CashLabel":
						subchild.text = "Your Cash: $" + str(int(cash))
					elif subchild is Label and subchild.name == "RepLabel":
						subchild.text = "Reputation: " + str(int(reputation)) + "/" + str(max_reputation)
	
	# Find the weapon panel
	var weapon_panel = null
	for child in dialog_container.get_children():
		if child is Panel:
			weapon_panel = child
			break
	
	if not weapon_panel:
		print("Weapon panel not found")
		return
		
	var weapon_info_container = weapon_panel.get_node_or_null("WeaponInfoContainer")
	if not weapon_info_container:
		print("WeaponInfoContainer not found in panel")
		return
	
	# Find all weapons available based on reputation
	var available_weapons = []
	for weapon_name in weapons:
		if reputation >= weapons[weapon_name]["rep_required"]:
			available_weapons.append(weapon_name)
	
	# If no weapons are available (shouldn't happen since Pistol has 0 rep requirement)
	if available_weapons.size() == 0:
		available_weapons.append("Pistol")  # Fallback
	
	# Get highest tier weapon the player qualifies for based on reputation
	available_weapons.sort_custom(func(a, b): return weapons[a]["rep_required"] > weapons[b]["rep_required"])
	var best_weapon = available_weapons[0]
	
	# Create dropdown for weapon selection
	var dropdown_container = weapon_info_container.get_node_or_null("DropdownContainer")
	if is_instance_valid(dropdown_container):
		dropdown_container.queue_free()
	
	dropdown_container = HBoxContainer.new()
	dropdown_container.name = "DropdownContainer"
	dropdown_container.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon_info_container.add_child(dropdown_container)
	weapon_info_container.move_child(dropdown_container, 2)  # Position after the title
	
	# Add dropdown itself
	var weapon_dropdown = OptionButton.new()
	weapon_dropdown.name = "WeaponDropdown"
	
	# Add all unlocked weapons to dropdown
	var selected_index = 0
	for i in range(available_weapons.size()):
		var weapon = available_weapons[i]
		weapon_dropdown.add_item(weapon)
		
		# If player owns this weapon, add an indicator
		if owned_weapons.has(weapon):
			weapon_dropdown.set_item_text(i, weapon + " (Owned)")
		
		# Set the best weapon as default selected
		if weapon == best_weapon:
			selected_index = i
	
	weapon_dropdown.select(selected_index)
	weapon_dropdown.custom_minimum_size = Vector2(180, 30)
	dropdown_container.add_child(weapon_dropdown)
	
	# Connect dropdown signal - using a temporary weapon name variable for the callback
	var temp_weapons = available_weapons.duplicate()
	weapon_dropdown.item_selected.connect(func(index): 
		if index >= 0 and index < temp_weapons.size():
			update_weapon_display(temp_weapons[index])
	)
	
	# Display initial weapon
	update_weapon_display(best_weapon)
	
	# Show the dialog
	gun_dealer_dialog.popup_centered()

# Updates the weapon display with details for the selected weapon
func update_weapon_display(weapon_name):
	if not weapons.has(weapon_name):
		print("Error: Weapon not found in weapons dictionary: ", weapon_name)
		return
	
	# Get main vbox
	var vbox = gun_dealer_dialog.get_child(0)

	# Find weapon panel
	var weapon_panel = null
	for child in vbox.get_children():
		if child is Panel:
			weapon_panel = child
			break
	
	if not weapon_panel:
		print("Weapon panel not found")
		return
	
	# Get weapon info container
	var weapon_info_container = weapon_panel.get_node_or_null("WeaponInfoContainer")
	if not weapon_info_container:
		print("WeaponInfoContainer not found")
		return
	
	# Get button container
	var button_container = weapon_info_container.get_node_or_null("ButtonContainer")
	if not button_container:
		print("ButtonContainer not found in WeaponInfoContainer")
		return
	
	# Clear buttons
	for child in button_container.get_children():
		child.queue_free()
	
	var weapon_data = weapons[weapon_name]

	# Safely access dictionary properties
	var price = weapon_data["price"] if weapon_data.has("price") else 0
	var damage = weapon_data["damage"] if weapon_data.has("damage") else 0
	var rep_required = weapon_data["rep_required"] if weapon_data.has("rep_required") else 0

	# Update available weapon label
	var available_label = weapon_info_container.get_node_or_null("AvailableLabel")
	if available_label:
		available_label.text = "Selected Weapon: " + weapon_name
	
	# Update weapon details
	var details_label = weapon_info_container.get_node_or_null("DetailsLabel")
	if details_label:
		details_label.text = "Price: $" + str(price) + "\n"
		details_label.text += "Damage: " + str(damage) + "\n"
		details_label.text += "Durability: 100%\n"
		details_label.text += "Reputation Required: " + str(rep_required)
	
	# Update status message and add appropriate buttons
	var status_label = weapon_info_container.get_node_or_null("StatusLabel")
	if not status_label:
		print("StatusLabel not found")
		return
	
	# Check if player already owns this weapon
	if owned_weapons.has(weapon_name):
		status_label.text = "You already own this weapon."

		# Only offer repair if durability is less than 100%
		if owned_weapons[weapon_name]["durability"] < 100:
			status_label.text += "\nYour " + weapon_name + " is at " + str(int(owned_weapons[weapon_name]["durability"])) + "% durability."

			# Add repair button
			var repair_price = int(price * 0.3 * (1 - owned_weapons[weapon_name]["durability"]/100.0))
			var repair_button = Button.new()
			repair_button.text = "Repair ($" + str(repair_price) + ")"
			repair_button.custom_minimum_size = Vector2(150, 40)

			# Create a reference to the weapon_name for the closure
			var weapon_to_repair = weapon_name
			repair_button.pressed.connect(func(): repair_weapon_from_dialog(weapon_to_repair))
			button_container.add_child(repair_button)
	else:
		# Check if player meets reputation requirements
		if reputation >= rep_required:
			# Player meets rep requirements
			if cash >= price:
				status_label.text = "You have enough cash to buy this weapon."

				# Add buy button
				var buy_button = Button.new()
				buy_button.text = "Buy " + weapon_name
				buy_button.custom_minimum_size = Vector2(150, 40)

				# Create a reference to the weapon_name for the closure
				var weapon_to_buy = weapon_name
				buy_button.pressed.connect(func(): buy_weapon_from_dialog(weapon_to_buy))
				button_container.add_child(buy_button)
			else:
				status_label.text = "You need $" + str(price - cash) + " more to buy this weapon."
		else:
			status_label.text = "You need " + str(rep_required - reputation) + " more reputation to unlock this weapon."

# Function to buy weapon from dialog
func buy_weapon_from_dialog(weapon_name):
	if weapons.has(weapon_name):
		var weapon_price = weapons[weapon_name].price
		
		if cash >= weapon_price:
			cash -= weapon_price
			
			# Add weapon to inventory
			owned_weapons[weapon_name] = {
				"durability": 100,
				"damage": weapons[weapon_name].damage
			}
			guns += 1  # Increment gun counter
			
			# Update UI
			update_stats_display()
			show_message("Purchased " + weapon_name + " for $" + str(weapon_price))
			
			# Equip the weapon automatically
			equipped_weapon = weapon_name
			show_message("Equipped " + weapon_name)
			
			# Refresh gun dealer dialog
			show_gun_dealer()
		else:
			show_message("Not enough cash to buy " + weapon_name)
	else:
		show_message("Weapon not available")

# Function to repair weapon from dialog
func repair_weapon_from_dialog(weapon_name):
	if owned_weapons.has(weapon_name):
		var current_durability = owned_weapons[weapon_name].durability
		
		if current_durability < 100:
			var repair_price = int(weapons[weapon_name].price * 0.3 * (1 - current_durability/100.0))
			
			if cash >= repair_price:
				cash -= repair_price
				owned_weapons[weapon_name].durability = 100
				
				# Update UI
				update_stats_display()
				show_message("Repaired " + weapon_name + " for $" + str(repair_price))
				
				# Refresh gun dealer dialog
				show_gun_dealer()
			else:
				show_message("Not enough cash for repairs")
		else:
			show_message("This weapon doesn't need repairs")
	else:
		show_message("You don't own this weapon")

# Sets up the weapon inventory dialog
func setup_weapon_inventory_dialog():
	print("Setting up weapon inventory dialog")
	
	# Check if dialog already exists
	if is_instance_valid(weapon_inventory_dialog):
		weapon_inventory_dialog.queue_free()
		await get_tree().process_frame
	
	weapon_inventory_dialog = PopupPanel.new()
	weapon_inventory_dialog.title = "Backpack"
	add_child(weapon_inventory_dialog)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(350, 350)  # Made taller to accommodate both weapons and medical supplies
	weapon_inventory_dialog.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Your Equipment"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	# Scrollable container for items
	var scroll = ScrollContainer.new() 
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(330, 250)
	vbox.add_child(scroll)
	
	# Container for weapon items
	var weapon_container = VBoxContainer.new()
	weapon_container.name = "WeaponContainer"
	weapon_container.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(weapon_container)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# Close button - FIXED to simply close without opening phone
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	
	# Modified callback that just hides the dialog without showing the phone
	close_button.pressed.connect(func(): 
		if is_instance_valid(weapon_inventory_dialog):
			weapon_inventory_dialog.hide()
	)
	
	vbox.add_child(close_button)
	
	print("Weapon inventory dialog setup complete")

# Shows the weapon inventory dialog
func show_weapon_inventory():
	print("Show weapon inventory called")
	
	# Setup dialog if it doesn't exist
	if not is_instance_valid(weapon_inventory_dialog):
		setup_weapon_inventory_dialog()
		# After setup, wait a frame then continue
		await get_tree().process_frame
	
	# Get the main VBox container with more error checking
	var vbox = null
	if is_instance_valid(weapon_inventory_dialog) and weapon_inventory_dialog.get_child_count() > 0:
		vbox = weapon_inventory_dialog.get_child(0)
	
	if not is_instance_valid(vbox):
		print("ERROR: VBox not found in weapon_inventory_dialog")
		# Try to recreate the dialog
		setup_weapon_inventory_dialog()
		await get_tree().process_frame
		if weapon_inventory_dialog.get_child_count() > 0:
			vbox = weapon_inventory_dialog.get_child(0)
		else:
			show_message("Error: Could not display backpack")
			return
	
	# Find the ScrollContainer
	var scroll = null
	for child in vbox.get_children():
		if child is ScrollContainer:
			scroll = child
			break
	
	if not is_instance_valid(scroll):
		print("ERROR: ScrollContainer not found in VBoxContainer")
		show_message("Error: Could not display backpack contents")
		return
	
	# Find or create the WeaponContainer
	var weapon_container = null
	for child in scroll.get_children():
		if child.name == "WeaponContainer":
			weapon_container = child
			break
	
	if not is_instance_valid(weapon_container):
		print("WeaponContainer not found, creating a new one")
		weapon_container = VBoxContainer.new()
		weapon_container.name = "WeaponContainer"
		weapon_container.size_flags_horizontal = SIZE_EXPAND_FILL
		scroll.add_child(weapon_container)
	
	# Clear existing weapon items
	for child in weapon_container.get_children():
		child.queue_free()
	
	# Check if we have any weapons or medical supplies
	if owned_weapons.size() == 0 and medical_supplies["Bandages"]["qty"] == 0:
		var no_items = Label.new()
		no_items.text = "Your backpack is empty."
		weapon_container.add_child(no_items)
	else:
		# Add a section title for weapons if we have any
		if owned_weapons.size() > 0:
			var weapons_title = Label.new()
			weapons_title.text = "WEAPONS"
			weapons_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			weapons_title.add_theme_font_size_override("font_size", 16)
			weapons_title.add_theme_color_override("font_color", Color("#FFAA00"))  # Yellow headers
			weapon_container.add_child(weapons_title)
			
			# Create a panel for each weapon
			for weapon_name in owned_weapons:
				var weapon_panel = Panel.new()
				var panel_style = StyleBoxFlat.new()
				panel_style.bg_color = Color("#333333")
				panel_style.set_border_width_all(1)
				panel_style.border_color = Color("#666666")
				panel_style.set_corner_radius_all(5)
				weapon_panel.add_theme_stylebox_override("panel", panel_style)
				weapon_panel.custom_minimum_size = Vector2(0, 70)
				
				var weapon_vbox = VBoxContainer.new()
				weapon_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
				weapon_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
				weapon_panel.add_child(weapon_vbox)
				
				# Weapon name
				var name_label = Label.new()
				name_label.text = weapon_name
				name_label.add_theme_font_size_override("font_size", 16)
				weapon_vbox.add_child(name_label)
				
				# Durability
				var durability = owned_weapons[weapon_name].durability
				var durability_bar = ProgressBar.new()
				durability_bar.min_value = 0
				durability_bar.max_value = 100
				durability_bar.value = durability
				
				# Color based on durability
				var fill_style = StyleBoxFlat.new()
				if durability > 70:
					fill_style.bg_color = Color("#00AA00")  # Green
				elif durability > 30:
					fill_style.bg_color = Color("#AAAA00")  # Yellow
				else:
					fill_style.bg_color = Color("#AA0000")  # Red
				
				durability_bar.add_theme_stylebox_override("fill", fill_style)
				weapon_vbox.add_child(durability_bar)
				
				# Damage
				var damage_label = Label.new()
				damage_label.text = "Damage: " + str(owned_weapons[weapon_name].damage)
				weapon_vbox.add_child(damage_label)
				
				# Add equip button
				var hbox = HBoxContainer.new()
				weapon_vbox.add_child(hbox)
				
				var equip_button = Button.new()
				equip_button.text = "Equip"
				var this_weapon = weapon_name # Create a copy for the closure
				equip_button.pressed.connect(func(): equip_weapon(this_weapon))
				
				# Disable if already equipped
				if equipped_weapon == weapon_name:
					equip_button.disabled = true
					equip_button.text = "Equipped"
				
				hbox.add_child(equip_button)
				
				weapon_container.add_child(weapon_panel)
				
				# Add some spacing
				if weapon_name != owned_weapons.keys()[-1]:
					var separator = HSeparator.new()
					weapon_container.add_child(separator)
		
		# Add medical supplies section if we have any bandages
		if medical_supplies["Bandages"]["qty"] > 0:
			# Add separator if we had weapons
			if owned_weapons.size() > 0:
				var big_separator = HSeparator.new()
				big_separator.custom_minimum_size = Vector2(0, 20)
				weapon_container.add_child(big_separator)
			
			# Add a section title for medical supplies
			var medical_title = Label.new()
			medical_title.text = "MEDICAL ITEMS"
			medical_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			medical_title.add_theme_font_size_override("font_size", 16)
			medical_title.add_theme_color_override("font_color", Color("#00AAFF"))
			weapon_container.add_child(medical_title)
			
			# Create bandages panel
			var bandage_panel = Panel.new()
			var panel_style = StyleBoxFlat.new()
			panel_style.bg_color = Color("#333333")
			panel_style.set_border_width_all(1)
			panel_style.border_color = Color("#666666")
			panel_style.set_corner_radius_all(5)
			bandage_panel.add_theme_stylebox_override("panel", panel_style)
			bandage_panel.custom_minimum_size = Vector2(0, 70)
			
			var bandage_vbox = VBoxContainer.new()
			bandage_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
			bandage_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
			bandage_panel.add_child(bandage_vbox)
			
			# Bandages name
			var name_label = Label.new()
			name_label.text = "Bandages"
			name_label.add_theme_font_size_override("font_size", 16)
			bandage_vbox.add_child(name_label)
			
			# Quantity and healing info
			var info_label = Label.new()
			info_label.text = "Quantity: " + str(medical_supplies["Bandages"]["qty"]) + " | Heals: " + str(medical_supplies["Bandages"]["health_restore"]) + " HP"
			bandage_vbox.add_child(info_label)
			
			# Current health display
			var health_label = Label.new()
			health_label.text = "Current Health: " + str(int(health)) + "/100"
			bandage_vbox.add_child(health_label)
			
			# Add use button
			var hbox = HBoxContainer.new()
			bandage_vbox.add_child(hbox)
			
			var use_button = Button.new()
			use_button.text = "Use Bandage"
			use_button.pressed.connect(func(): use_bandages_from_backpack())
			
			# Disable if already at full health or no bandages
			if health >= 100:
				use_button.disabled = true
				use_button.text = "Full Health"
			elif medical_supplies["Bandages"]["qty"] <= 0:
				use_button.disabled = true
				use_button.text = "None Available"
			
			hbox.add_child(use_button)
			
			weapon_container.add_child(bandage_panel)
	
	# Show dialog with updated title
	if is_instance_valid(weapon_inventory_dialog):
		weapon_inventory_dialog.title = "Backpack"
		weapon_inventory_dialog.popup_centered()
	else:
		print("ERROR: weapon_inventory_dialog is invalid")
		show_message("Error: Could not open backpack")

	# Equips a weapon
func equip_weapon(weapon_name):
	if owned_weapons.has(weapon_name):
		equipped_weapon = weapon_name
		show_message("Equipped " + weapon_name)
		
		# Refresh weapon inventory display
		show_weapon_inventory()

# Uses a weapon during combat
func use_weapon():
	if equipped_weapon != "" and owned_weapons.has(equipped_weapon):
		# Reduce durability with each use
		owned_weapons[equipped_weapon].durability -= randf_range(1, 5)
		
		# Ensure durability doesn't go below 0
		if owned_weapons[equipped_weapon].durability < 0:
			owned_weapons[equipped_weapon].durability = 0
		
		# Check if weapon is broken
		if owned_weapons[equipped_weapon].durability <= 0:
			show_message("Your " + equipped_weapon + " is broken and needs repair!")
			return 0
		
		# Return damage based on weapon and current durability
		var base_damage = owned_weapons[equipped_weapon].damage
		var durability_factor = owned_weapons[equipped_weapon].durability / 100.0
		
		# Weapon is less effective when durability is low
		return int(base_damage * durability_factor)
	
	# No weapon equipped or doesn't exist
	return 0

#==============================================================================
# COMBAT SYSTEM
#==============================================================================

# Function to setup combat dialog
func setup_combat_dialog():
	combat_dialog = PopupPanel.new()
	combat_dialog.title = "Combat"
	add_child(combat_dialog)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 300)  # Made taller for better readability
	combat_dialog.add_child(vbox)
	
	# Enemy info
	var enemy_info = Label.new()
	enemy_info.name = "EnemyInfo"
	enemy_info.text = "Enemy info will appear here"
	enemy_info.add_theme_font_size_override("font_size", 16)
	vbox.add_child(enemy_info)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer1)
	
	# Player info
	var player_info = Label.new()
	player_info.name = "PlayerInfo"
	player_info.text = "Player info will appear here"
	player_info.add_theme_font_size_override("font_size", 16)
	vbox.add_child(player_info)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)
	
	# Combat status
	var combat_status = Label.new()
	combat_status.name = "CombatStatus"
	combat_status.text = "Combat started!"
	combat_status.add_theme_font_size_override("font_size", 14)
	combat_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(combat_status)
	
	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer3)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_container)
	
	var attack_button = Button.new()
	attack_button.text = "Attack"
	attack_button.custom_minimum_size = Vector2(100, 40)
	attack_button.pressed.connect(func(): player_attack())
	button_container.add_child(attack_button)
	
	var spacer_buttons = Control.new()
	spacer_buttons.custom_minimum_size = Vector2(20, 0)
	button_container.add_child(spacer_buttons)
	
	var run_button = Button.new()
	run_button.text = "Run"
	run_button.custom_minimum_size = Vector2(100, 40)
	run_button.pressed.connect(func(): attempt_run())
	button_container.add_child(run_button)

# Fixed start_combat function
func start_combat():
	# Only start combat if not already in combat
	if in_combat:
		return
	
	print("Starting combat...")
	
	# Setup combat dialog if it doesn't exist
	if not is_instance_valid(combat_dialog):
		setup_combat_dialog()
		# Need to wait for dialog to be set up
		await get_tree().process_frame
	
	in_combat = true
	
	# Choose enemy based on location
	var enemies = {
		"Erie": {"name": "Street Thug", "health": 30, "damage": 5},
		"York": {"name": "Gang Member", "health": 50, "damage": 10},
		"Kensington": {"name": "Drug Dealer", "health": 40, "damage": 8},
		"Pittsburgh": {"name": "Mobster", "health": 60, "damage": 15},  # Increased damage
		"Love Park": {"name": "Corrupt Cop", "health": 70, "damage": 15},
		"Reading": {"name": "Junkie", "health": 20, "damage": 3}
	}
	
	# Default to Erie enemy if current location not found
	var location_enemies = enemies["Erie"]
	if enemies.has(current_location):
		location_enemies = enemies[current_location]
	
	# Set enemy stats
	enemy_name = location_enemies.name
	enemy_health = location_enemies.health
	enemy_initial_health = location_enemies.health  # Store initial health
	enemy_damage = location_enemies.damage
	
	print("Enemy initialized: " + enemy_name + " with " + str(enemy_health) + " health and " + str(enemy_damage) + " damage")
	
	# Update combat dialog
	update_combat_dialog()
	
	# Show dialog
	combat_dialog.popup_centered()
	
	# Add a slight delay before the first enemy attack
	await get_tree().create_timer(0.5).timeout
	
	# Enemy gets the first attack in an ambush
	enemy_attack()
	
	var events_container = get_node_or_null("EventsContainer")
	if events_container and events_container.has_method("add_custom_event"):
		events_container.add_custom_event("Combat Started", 
		"You were ambushed by a " + enemy_name + " in " + current_location + "!",
		{"health": 0})

# Modified enemy attack for faster damage
func enemy_attack():
	if not in_combat:
		return
	
	# Calculate damage with a slight variation
	var damage_taken = int(enemy_damage * randf_range(0.8, 1.2))
	
	# Apply damage to player
	health -= damage_taken
	
	# Update combat status
	var combat_status = combat_dialog.get_child(0).get_node("CombatStatus")
	combat_status.text = enemy_name + " attacks you for " + str(damage_taken) + " damage!"
	
	# Update UI
	update_stats_display()
	update_combat_dialog()
	
	# For testing purposes: make death happen faster when health is low
	if health < 30:
		damage_taken = int(enemy_damage * 2.5)  # Extra damage when low health
		health -= damage_taken
		combat_status.text += "\n" + enemy_name + " lands a critical hit for " + str(damage_taken) + " additional damage!"
	
	# Check if player is defeated - immediately end combat if so
	if health <= 0:
		# Add defeated message
		combat_status.text += "\nYou have been defeated!"
		
		# Give the player time to read the message before ending combat
		await get_tree().create_timer(1.5).timeout
		end_combat(false)

# Function to update combat dialog
func update_combat_dialog():
	if not is_instance_valid(combat_dialog):
		return
	
	var vbox = combat_dialog.get_child(0)
	
	# Update enemy info
	var enemy_info = vbox.get_node("EnemyInfo")
	enemy_info.text = enemy_name + "\nHealth: " + str(enemy_health)
	
	# Update player info
	var player_info = vbox.get_node("PlayerInfo")
	var weapon_info = ""
	if equipped_weapon != "":
		weapon_info = "\nEquipped: " + equipped_weapon
		if owned_weapons.has(equipped_weapon):
			weapon_info += " (" + str(int(owned_weapons[equipped_weapon].durability)) + "% durability)"
	
	player_info.text = "You\nHealth: " + str(health) + weapon_info

# Function for player attack
func player_attack():
	if not in_combat:
		return
	
	var damage_dealt = 5  # Base damage without weapon
	
	# Add weapon damage if equipped
	var weapon_damage = use_weapon()
	damage_dealt += weapon_damage
	
	# Apply damage to enemy
	enemy_health -= round(damage_dealt)
	
	# Update combat status
	var combat_status = combat_dialog.get_child(0).get_node("CombatStatus")
	
	if weapon_damage > 0:
		combat_status.text = "You attack with your " + equipped_weapon + " for " + str(damage_dealt) + " damage!"
	else:
		combat_status.text = "You attack with your fists for " + str(damage_dealt) + " damage!"
	
	# Check if enemy is defeated
	if enemy_health <= 0:
		end_combat(true)
		return
	
	# Enemy attacks back
	await get_tree().create_timer(1.0).timeout
	enemy_attack()

# Function to attempt running from combat
func attempt_run():
	# 50% chance to escape
	if randf() < 0.5:
		var combat_status = combat_dialog.get_child(0).get_node("CombatStatus")
		combat_status.text = "You successfully escaped!"
		
		await get_tree().create_timer(1.0).timeout
		end_combat(false)
	else:
		var combat_status = combat_dialog.get_child(0).get_node("CombatStatus")
		combat_status.text = "Failed to escape!"
		
		# Enemy gets a free attack
		await get_tree().create_timer(1.0).timeout
		enemy_attack()

# Function to end combat
func end_combat(victory):
	# Clear combat flag
	in_combat = false

	# Close combat dialog first to prevent UI issues
	combat_dialog.hide()
	
	var events_container = get_node_or_null("EventsContainer")
	if events_container and events_container.has_method("add_custom_event"):
		if victory:
			var cash_reward = int(enemy_initial_health * 10 * (1 + randf()))
			events_container.add_custom_event("Combat Victory", 
				"You defeated the " + enemy_name + " and found $" + str(cash_reward) + "!",
				{"cash": cash_reward})
		else:
			if health <= 0:
				events_container.add_custom_event("Combat Defeat", 
					"You were defeated by the " + enemy_name + ".",
					{"health": -health})  # Negative of current health to show how much was lost
			else:
				var cash_lost = int(cash * 0.3)
				events_container.add_custom_event("Escaped Combat", 
					"You managed to escape from the " + enemy_name + " but lost $" + str(cash_lost) + ".",
					{"cash": -cash_lost})

			# Penalty for running away
			var cash_lost = int(cash * 0.3)
			cash -= cash_lost
			
			# Lose some drugs
			var drugs_data = get_drugs()
			var drugs_to_remove = []
			for drug_name in drugs_data:
				if drugs_data[drug_name]["qty"] > 0:
					drugs_to_remove.append(drug_name)

			if drugs_to_remove.size() > 0:
				var random_drug = drugs_to_remove[randi() % drugs_to_remove.size()]
				var lost_amount = int(drugs_data[random_drug]["qty"] * 0.5)
				$InventorySystem.remove_drug(random_drug, lost_amount)
				
				show_message("You lost $" + str(cash_lost) + " and " + str(lost_amount) + " " + random_drug)
			else:
				show_message("You lost $" + str(cash_lost))
			
			# Reset health to minimum if it's low
			if health < 10:
				health = 10

			update_stats_display()
			$InventorySystem.update_inventory_display()

#==============================================================================
# EVENT SYSTEM
#==============================================================================

# Sets up the event system
func setup_event_system():
	# Create event system
	event_system = Node.new()
	event_system.set_script(load("res://Scripts/Events/event_system.gd"))
	event_system.name = "EventSystem"
	add_child(event_system)

	# Connect the event signal
	event_system.connect("event_triggered", _on_event_triggered)

# Handles event triggers from the event system
func _on_event_triggered(event_data):
	# Use popup if available, otherwise fall back to the message system
	show_message(event_data.title + ": " + event_data.description, 5.0)

	# Apply event effects
	event_system.process_event(event_data, self)
	
	# Add this code to log events to the EventsContainer
	var events_container = get_node_or_null("EventsContainer")
	if events_container and events_container.has_method("add_custom_event"):
		events_container.add_custom_event(event_data.title, event_data.description, event_data.effects)

#==============================================================================
# PLAYER STAT MODIFIERS
#==============================================================================

# Add heat (police attention)
func add_heat(amount):
	# Update the heat variable
	heat += amount

	# Keep heat within valid range (0-100)
	heat = clamp(heat, 0, max_heat)

	# Show appropriate message
	if amount > 0:
		show_message("Police attention increased by " + str(amount))
	else:
		show_message("Police attention decreased by " + str(abs(amount)))

	# Update UI
	update_stats_display()
	has_unsaved_changes = true

# Add reputation in the drug world
func add_reputation(amount):
	# Update the reputation variable
	reputation += amount

	# Keep reputation within valid range (0-100)
	reputation = clamp(reputation, 0, max_reputation)

	# Show appropriate message
	if amount > 0:
		show_message("Your reputation increased by " + str(amount))
	else:
		show_message("Your reputation decreased by " + str(abs(amount)))

	# Update UI
	update_stats_display()
	has_unsaved_changes = true

# Add game time
func add_time(hours):
	# Show time passage message
	show_message(str(hours) + " hours have passed")

	# In a future update, you might implement a proper time system:
	# game_time += hours
	# if game_time >= 24:
	#     game_time = 0
	#     day += 1
	# update_time_display()

	has_unsaved_changes = true

# Add cash
func add_cash(amount):
	# Update player's cash
	cash += amount

	# Show a message based on whether gaining or losing money
	if amount > 0:
		show_message("You gained $" + str(amount))
	else:
		show_message("You lost $" + str(abs(amount)))

	# Update the UI
	update_stats_display()

	# Mark that we have unsaved changes
	has_unsaved_changes = true

# Add health
func add_health(amount):
	# Update player's health
	health += amount

	# Ensure health stays within valid range (0-100)
	health = clamp(health, 0, 100)

	# Show a message based on health change
	if amount > 0:
		show_message("Your health increased by " + str(amount))
	else:
		show_message("Your health decreased by " + str(abs(amount)))

	# Update the UI
	update_stats_display()

	# Mark that we have unsaved changes
	has_unsaved_changes = true

#==============================================================================
# GAME STATE MANAGEMENT
#==============================================================================

# Starts a new game with default values
# Starts a new game with default values
func new_game():
	cash = 2000
	bank = 0
	debt = 5000
	guns = 0
	health = 100
	heat = 0      # Reset heat
	reputation = 0  # Reset reputation
	has_unsaved_changes = false
	
	# Reset time to 8 AM on day 1
	game_hour = 8
	game_day = 1
	update_time_display()
	
	# Reset weapons inventory
	owned_weapons.clear()  # Remove all weapons
	equipped_weapon = ""   # Unequip any weapon
	
	$InventorySystem.reset_inventory()
	
	# Reset game over state if needed
	game_over = false
	
	# Reset capacity
	$InventorySystem.current_capacity = 0

	# Set starting location
	current_location = "Kensington"
	location_label.text = "Currently In:  " + current_location
	medical_supplies = {
		"Bandages": {"price": 50, "qty": 0, "health_restore": 15}
	}
	
		# Clear and initialize event history
	var events_container = get_node_or_null("EventsContainer")
	if events_container and events_container.has_method("clear_events"):
		events_container.clear_events()
		events_container.add_custom_event("New Game Started", 
			"Welcome to In The Streets! You start in " + current_location + " with $" + str(cash) + ".",
			{"cash": cash})
	
	# Show welcome message
	show_message("Welcome to " + current_location)

	# Update all UI elements
	update_stats_display()
	update_market_display()
	$InventorySystem.update_inventory_display()
	show_message("New game started!")

# Confirms starting a new game
func start_new_game():
	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "Are you sure you want to start a new game? All unsaved progress will be lost."
	confirmation.title = "Start New Game"
	add_child(confirmation)
	
	confirmation.confirmed.connect(func():
		new_game()
	)
	
	confirmation.popup_centered()

# Triggers game over screen
func trigger_game_over(cause_of_death = ""):
	# Set game over state
	game_over = true

	# Create death message
	var message = ""
	if cause_of_death.is_empty():
		message = "You died from your injuries."
	else:
		message = "You were defeated by " + cause_of_death
	
	print("Triggering game over: " + message)  # Debug message

	# Create game over scene instance
	var game_over_screen = GameOverScreen.instantiate()

	# Set death message before adding to tree
	game_over_screen.death_message = message

	# Connect signal for tracking actions
	if not game_over_screen.is_connected("action_selected", Callable(self, "_on_game_over_action")):
		game_over_screen.connect("action_selected", _on_game_over_action)
	
	# Add to the tree
	add_child(game_over_screen)
	
	# Hide other UI elements that we know can be hidden
	if has_node("MainContainer"):
		$MainContainer.visible = false
	
	# Make sure game over screen is visible
	game_over_screen.visible = true

# Debug command to force game over for testing
func force_game_over():
	health = 0
	trigger_game_over("Debug Command")

# Handles action selection on game over
func _on_game_over_action(action):
	print("Game over action received: " + action)

	# Get the game_over_screen reference - might be a direct child now
	var game_over_screen = get_node_or_null("GameOverScreen")
	
	# If not found as direct child, try to find it in the scene tree
	if not game_over_screen:
		for child in get_children():
			if child.name == "GameOverScreen":
				game_over_screen = child
				break
	
	# If found, remove it
	if game_over_screen:
		game_over_screen.queue_free()
	
	# Show the main game again
	if has_node("MainContainer"):
		$MainContainer.visible = true
	
	# Reset game over state
	game_over = false
	
	# Process the action
	if action == "new_game":
		print("Starting new game after game over")
		new_game()  # Call your new game function
	elif action == "load":
		print("Loading game after game over")
		load_game()  # Call your load game function

#==============================================================================
# SAVE/LOAD SYSTEM
#==============================================================================

# Sets up the file dialogs for saving and loading
func setup_file_dialogs():
	save_dialog = FileDialog.new()
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.filters = ["*.json ; JSON Files"]
	save_dialog.title = "Save Game"
	save_dialog.current_path = "user://in_the_streets_save.json"
	add_child(save_dialog)
	
	save_dialog.file_selected.connect(_on_save_dialog_file_selected)
	
	load_dialog = FileDialog.new()
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.filters = ["*.json ; JSON Files"]
	load_dialog.title = "Load Game"
	load_dialog.current_path = "user://in_the_streets_save.json"
	add_child(load_dialog)
	
	load_dialog.file_selected.connect(_on_load_dialog_file_selected)

# Saves the game
func save_game(show_dialog = true):
	if show_dialog:
		save_dialog.popup_centered(Vector2(800, 600))
		return

	# Direct save without dialog
	print("Direct save started, saving to: " + save_file_path)
	show_message("Attempting to save game...", 3.0)
	
	# Create save data with proper type conversion
	var save_data = {
		"player": {
			"cash": int(cash),
			"bank": int(bank),
			"debt": int(debt),
			"guns": int(guns),
			"health": int(health),
			"current_capacity": int($InventorySystem.current_capacity),
			"heat": int(heat),
			"reputation": int(reputation),
			"weapons": {},  # Will fill this separately
			"equipped_weapon": equipped_weapon,
			"medical_supplies": {}  # Will fill this separately
		},
		"location": current_location,
		"time": {
			"game_hour": int(game_hour),
			"game_day": int(game_day)
		},
		"drugs": {}
	}

	# Convert owned_weapons to a simple serializable format
	for weapon_name in owned_weapons:
		save_data["player"]["weapons"][weapon_name] = {
			"durability": int(owned_weapons[weapon_name].durability),
			"damage": int(owned_weapons[weapon_name].damage)
		}

	# Convert medical supplies to a simple serializable format
	for item_name in medical_supplies:
		save_data["player"]["medical_supplies"][item_name] = {
			"price": int(medical_supplies[item_name].price),
			"qty": int(medical_supplies[item_name].qty),
			"health_restore": int(medical_supplies[item_name].health_restore)
		}

	# Add drug data
	var drugs_data = get_drugs()
	for drug_name in drugs_data:
		save_data["drugs"][drug_name] = {
			"price": int(drugs_data[drug_name]["price"]),
			"qty": int(drugs_data[drug_name]["qty"])
	}
	
	has_unsaved_changes = false

	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
		print("Game saved successfully to: " + save_file_path)
		show_message("Game saved successfully!", 3.0)
	else:
		var error_code = FileAccess.get_open_error()
		var error_message = _get_file_error_message(error_code)
		print("Failed to save game. Error code: " + str(error_code) + " - " + error_message)
		show_message("Save failed: " + error_message, 5.0)

func _get_file_error_message(error_code):
	match error_code:
		ERR_FILE_NOT_FOUND: return "File not found"
		ERR_FILE_BAD_DRIVE: return "Bad drive"
		ERR_FILE_BAD_PATH: return "Bad path"
		ERR_FILE_NO_PERMISSION: return "No permission"
		ERR_FILE_ALREADY_IN_USE: return "File already in use"
		ERR_FILE_CANT_OPEN: return "Can't open file"
		ERR_FILE_CANT_WRITE: return "Can't write to file"
		ERR_FILE_CANT_READ: return "Can't read from file"
		ERR_FILE_UNRECOGNIZED: return "Unrecognized file"
		ERR_FILE_CORRUPT: return "Corrupt file"
		ERR_FILE_MISSING_DEPENDENCIES: return "Missing dependencies"
		ERR_FILE_EOF: return "End of file"
		_: return "Unknown error"

# Handles file selection from the save dialog
func _on_save_dialog_file_selected(path):
	var save_data = {
		"player": {
			"cash": int(cash),
			"bank": int(bank),
			"debt": int(debt),
			"guns": int(guns),
			"health": int(health),
			"current_capacity": int($InventorySystem.current_capacity),
			"heat": int(heat),
			"reputation": int(reputation),
			"weapons": {},  # Will fill separately
			"equipped_weapon": equipped_weapon,
			"medical_supplies": {}  # Will fill separately
		},
		"location": current_location,
		"time": {
			"game_hour": int(game_hour),
			"game_day": int(game_day)
		},
		"drugs": {}
	}

	# Convert owned_weapons to a serializable format
	for weapon_name in owned_weapons:
		save_data["player"]["weapons"][weapon_name] = {
			"durability": int(owned_weapons[weapon_name].durability),
			"damage": int(owned_weapons[weapon_name].damage)
		}

	# Convert medical supplies to a serializable format
	for item_name in medical_supplies:
		save_data["player"]["medical_supplies"][item_name] = {
			"price": int(medical_supplies[item_name].price),
			"qty": int(medical_supplies[item_name].qty),
			"health_restore": int(medical_supplies[item_name].health_restore)
		}

	# Get drugs data from InventorySystem
	var drugs_data = get_drugs()
	for drug_name in drugs_data:
		save_data["drugs"][drug_name] = {
			"price": int(drugs_data[drug_name]["price"]),
			"qty": int(drugs_data[drug_name]["qty"])
		}
	
	has_unsaved_changes = false

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
		show_message("Game saved successfully to: " + path)
	else:
		show_message("Failed to save game: " + str(FileAccess.get_open_error()))

# Loads the game
func load_game():
	print("Manual load requested from: " + save_file_path)
	
	# Using popup dialog
	if not get_tree().paused:
		load_dialog.popup_centered(Vector2(800, 600))
		return false
	
	# Loading directly
	if not FileAccess.file_exists(save_file_path):
		print("ERROR: Cannot load, file doesn't exist at: " + save_file_path)
		return false
	
	return load_game_from_path(save_file_path)

# Auto-loads game on startup
func auto_load_game():
	print("Auto-loading game from: " + save_file_path)
	print("Absolute path: " + ProjectSettings.globalize_path(save_file_path))

	if not FileAccess.file_exists(save_file_path):
		print("ERROR: Save file doesn't exist at: " + save_file_path)
		return false

	return load_game_from_path(save_file_path)

# Loads game from a specific path
func load_game_from_path(path):
	has_unsaved_changes = false
	
	print("Attempting to load from: " + path)
	show_message("Loading game...", 3.0)
	
	if not FileAccess.file_exists(path):
		var message = "No save file found at " + path
		print(message)
		show_message(message, 3.0)
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		var error_code = FileAccess.get_open_error()
		var message = "Failed to open save file: " + _get_file_error_message(error_code)
		print(message)
		show_message(message, 3.0)
		return false
		
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)

	if error != OK:
		var message = "Failed to parse save data: " + json.get_error_message() + " at line " + str(json.get_error_line())
		print(message)
		show_message(message, 3.0)
		return false
	
	var save_data = json.get_data()
	
	# Load player data
	if save_data.has("player"):
		cash = int(save_data["player"]["cash"])
		bank = int(save_data["player"]["bank"])
		debt = int(save_data["player"]["debt"])
		guns = int(save_data["player"]["guns"])
		health = int(save_data["player"]["health"])
		heat = int(save_data["player"]["heat"])
		reputation = int(save_data["player"]["reputation"])
		
		# Load weapons
		owned_weapons.clear()
		if save_data["player"].has("weapons"):
			for weapon_name in save_data["player"]["weapons"]:
				owned_weapons[weapon_name] = {
					"durability": int(save_data["player"]["weapons"][weapon_name]["durability"]),
					"damage": int(save_data["player"]["weapons"][weapon_name]["damage"])
				}
		
		# Load equipped weapon
		if save_data["player"].has("equipped_weapon"):
			equipped_weapon = save_data["player"]["equipped_weapon"]
		
		# Load medical supplies
		if save_data["player"].has("medical_supplies"):
			for item_name in save_data["player"]["medical_supplies"]:
				if medical_supplies.has(item_name):
					medical_supplies[item_name]["price"] = int(save_data["player"]["medical_supplies"][item_name]["price"])
					medical_supplies[item_name]["qty"] = int(save_data["player"]["medical_supplies"][item_name]["qty"])
					medical_supplies[item_name]["health_restore"] = int(save_data["player"]["medical_supplies"][item_name]["health_restore"])
	
	# Load location
	if save_data.has("location"):
		current_location = save_data["location"]
		location_label.text = "Currently In: " + current_location
	
	# Load time data
	if save_data.has("time"):
		game_hour = int(save_data["time"]["game_hour"])
		game_day = int(save_data["time"]["game_day"])
	
	# Now set the drug data
	if save_data.has("drugs"):
		$InventorySystem.set_drug_data(save_data["drugs"])
	
	# Update all UI elements
	update_stats_display()
	update_time_display()
	update_market_display()
	$InventorySystem.update_inventory_display()
	
	show_message("Game loaded successfully!", 3.0)
	return true
	
# Handle load dialog file selection
func _on_load_dialog_file_selected(path):
	load_game_from_path(path)

func deselect_all():
	if is_instance_valid(market_list):
		market_list.selected_index = -1

	if is_instance_valid(inventory_list):
		inventory_list.selected_index = -1
		
# Helper function to get all nodes in a scene
func get_all_nodes(node):
	var nodes = []
	nodes.append(node)
	
	for child in node.get_children():
		nodes.append_array(get_all_nodes(child))
	
	return nodes



#==============================================================================
# Timer Functions
#==============================================================================
# Add this function to initialize the time system in _ready() after other initializations
func setup_time_system():
	# Use the existing TimeDisplayLabel node you've already added
	time_display_label = get_node_or_null("MainContainer/TopSection/StatsContainer/LocationContainer/TimerContainer/TimeDisplayLabel")
	
	if not is_instance_valid(time_display_label):
		# Try direct path as seen in the screenshot
		time_display_label = get_node_or_null("TimerContainer/TimeDisplayLabel")
		
		if not is_instance_valid(time_display_label):
			# Final fallback - search the entire tree
			time_display_label = find_node_by_name_recursive(self, "TimeDisplayLabel")
			
	if not is_instance_valid(time_display_label):
		print("WARNING: TimeDisplayLabel not found!")
		return
	
	# Update display initially
	update_time_display()
	
	# Configure the timer node
	var date_timer = get_node_or_null("DateTimer")
	if not is_instance_valid(date_timer):
		date_timer = find_node_by_name_recursive(self, "DateTimer")
	
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
		print("WARNING: DateTimer node not found! Time system won't function.")

# The rest of the time system functions remain the same
func _on_time_tick():
	# Advance time by 1 hour
	game_hour += 1
	
	# Handle day change
	if game_hour >= 24:
		game_hour = 0
		game_day += 1
		
		# Process daily events
		process_daily_events()
	
	# Update UI with new time
	update_time_display()
	
	# Apply time-of-day effects
	apply_time_of_day_effects()

# Add this function to handle each timer tick
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
		if game_hour >= 6 and game_hour < 18:
			# Daytime - use normal color
			time_display_label.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			# Nighttime - use slightly blue tint
			time_display_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))

# Helper function to find a node by name recursively
func find_node_by_name_recursive(node, name):
	if node.name == name:
		return node
	
	for child in node.get_children():
		var found = find_node_by_name_recursive(child, name)
		if found:
			return found
	
	return null

# Add this function to process events that happen daily
func process_daily_events():
	
		# Log to event history
	var events_container = get_node_or_null("EventsContainer")
	if events_container and events_container.has_method("add_custom_event"):
		var summary = "A new day has begun."
		var effects = {}
		
		if debt > 0:
			var interest = int(debt * 0.1)
			summary += " Loan shark applied $" + str(interest) + " interest."
			effects["cash"] = 0  # Not directly affecting cash, but record it
		
		if bank > 0:
			var interest = int(bank * 0.025)
			summary += " Bank added $" + str(interest) + " interest."
			effects["cash"] = 0  # Not directly affecting cash, but record it
		
		events_container.add_custom_event("New Day", summary, effects)
	# Process loan interest
	if debt > 0:
		# 10% daily interest on loans
		var interest = int(debt * 0.1)
		debt += interest
		show_message("Loan Shark applied daily interest: $" + str(interest))
	
	# Process bank interest
	if bank > 0:
		# 2.5% daily interest on savings
		var interest = int(bank * 0.025)
		bank += interest
		show_message("Bank added daily interest: $" + str(interest))
	
	# Random market events
	if randf() < 0.3:  # 30% chance
		$MarketSystem.update_market_prices(current_location)
		update_market_display()
		show_message("Market prices have changed with the new day")
	
	# Update UI
	update_stats_display()

# Add this function to apply effects based on time of day
func apply_time_of_day_effects():
	# Different events or modifiers can happen at different times
	
	# More dangerous at night (higher combat chance)
	if game_hour >= 22 or game_hour < 5:
		# Nighttime is more dangerous
		event_system.event_chance = 0.4  # 40% chance of random events at night
	else:
		# Daytime is safer
		event_system.event_chance = 0.3  # 30% chance during day
	
	# Market closed late at night
	if game_hour >= 2 and game_hour < 6:
		if market_list and market_list.get_child_count() > 0:
			# Market is closed - can't buy/sell during these hours
			market_list.clear()
			market_list.add_item(["MARKET CLOSED", "COME BACK LATER"])
	else:
		# Market is open, ensure prices are displayed
		if current_location != "" and (market_list.get_child_count() <= 0 or market_list.rows.size() <= 1):
			update_market_display()

# Add this helper function to advance time by a specific number of hours
func advance_time(hours):
	for i in range(hours):
		game_hour += 1
		if game_hour >= 24:
			game_hour = 0
			game_day += 1
			process_daily_events()
	
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
	
func setup_event_history():
	# Get reference to the EventsContainer
	var events_container = $EventsContainer
	
	if not events_container:
		print("WARNING: EventsContainer not found!")
		return
	
	# Attach the event_history.gd script if not already attached
	if not events_container.has_method("clear_events"):
		events_container.set_script(load("res://event_history.gd"))
	
	# Make sure it's visible
	events_container.visible = true
	
	# Keep this line to ensure proper z-ordering
	move_child(events_container, get_child_count() - 1)









#######################################################
# NEW CODE

#######################################################
# INVENTORY SYSTEM
#######################################################


func buy_drugs():
	$InventorySystem.buy_drugs()

func sell_drugs():
	$InventorySystem.sell_drugs()

func _on_inventory_changed():
	# Any additional logic when inventory changes
	has_unsaved_changes = true

func _on_capacity_changed(current, max_capacity):
	# Update any UI that shows capacity
	pass

func _on_drug_purchased(drug_name, quantity, cost):
	# Any additional logic after drug purchase
	var events_container = get_node_or_null("EventsContainer")
	if events_container and events_container.has_method("add_custom_event"):
		events_container.add_custom_event("Purchase", 
			"Bought " + str(quantity) + " " + drug_name + " for $" + str(cost),
			{"cash": -cost})

func _on_drug_sold(drug_name, quantity, revenue):
	# Any additional logic after drug sale
	var events_container = get_node_or_null("EventsContainer")
	if events_container and events_container.has_method("add_custom_event"):
		events_container.add_custom_event("Sale", 
			"Sold " + str(quantity) + " " + drug_name + " for $" + str(revenue),
			{"cash": revenue})

# Get drugs data from InventorySystem
func get_drugs():
	return $InventorySystem.get_drug_data()

# Get base drug prices from InventorySystem
func get_base_drug_prices():
	return $MarketSystem.base_drug_prices

# Update drug price in InventorySystem
func set_drug_price(drug_name, price):
	# Update in MarketSystem (source of truth)
	$MarketSystem.set_drug_price(drug_name, price)

	# Also update in InventorySystem (display copy)
	var drugs_data = $InventorySystem.get_drug_data()
	if drugs_data.has(drug_name):
		drugs_data[drug_name]["price"] = price
		
#######################################################
# MARKET SYSTEM
#######################################################

func _on_market_updated(drug_prices):
	# Update market display
	update_market_display()
	for drug_name in drug_prices:
		if drug_name != "event_drug":  # Skip internal marker
			$InventorySystem.update_drug_price(drug_name, drug_prices[drug_name])
			
			
			
func _on_market_event_triggered(event_data):
	# Show event notification
	show_message(event_data.message)
