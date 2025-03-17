extends Node
class_name CombatSystem

# Signals to notify other systems of combat events
signal combat_started(enemy_data)
signal combat_ended(victory)
signal player_damaged(amount)
signal enemy_damaged(amount)

# References to main game and UI
var main_game
var combat_dialog

# Combat variables
var in_combat = false
var enemy_health = 0
var enemy_name = ""
var enemy_damage = 0
var enemy_initial_health = 0

# Enemy configurations by location
var enemies = {
	"Erie": {"name": "Street Thug", "health": 30, "damage": 5},
	"York": {"name": "Gang Member", "health": 50, "damage": 10},
	"Kensington": {"name": "Drug Dealer", "health": 40, "damage": 8},
	"Pittsburgh": {"name": "Mobster", "health": 60, "damage": 15},
	"Love Park": {"name": "Corrupt Cop", "health": 70, "damage": 15},
	"Reading": {"name": "Junkie", "health": 20, "damage": 3}
}

func _ready():
	# Get reference to main game
	main_game = get_parent()
	
	# Setup combat dialog
	setup_combat_dialog()

# Function to setup combat dialog
func setup_combat_dialog():
	combat_dialog = PopupPanel.new()
	combat_dialog.title = "Combat"
	add_child(combat_dialog)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 300)
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
	run_button.pressed.connect(func(): attempt_escape())
	button_container.add_child(run_button)

# Start combat with an enemy based on current location
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
	var current_location = main_game.get_node("LocationSystem").current_location
	var location_enemies = enemies["Erie"]  # Default enemy
	
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
	
	# Emit signal that combat has started
	emit_signal("combat_started", {
		"name": enemy_name,
		"health": enemy_health,
		"damage": enemy_damage
	})
	
	# Log the combat event
	var events_container = main_game.get_node_or_null("EventsContainer")
	if events_container and events_container.has_method("add_custom_event"):
		events_container.add_custom_event("Combat Started", 
		"You were ambushed by a " + enemy_name + " in " + current_location + "!",
		{"health": 0})
	
	# Add a slight delay before the first enemy attack
	await get_tree().create_timer(0.5).timeout
	
	# Enemy gets the first attack in an ambush
	enemy_attack()

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
	
	if main_game.equipped_weapon != "":
		weapon_info = "\nEquipped: " + main_game.equipped_weapon
		if main_game.owned_weapons.has(main_game.equipped_weapon):
			weapon_info += " (" + str(int(main_game.owned_weapons[main_game.equipped_weapon].durability)) + "% durability)"
	
	player_info.text = "You\nHealth: " + str(main_game.health) + weapon_info

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
		combat_status.text = "You attack with your " + main_game.equipped_weapon + " for " + str(damage_dealt) + " damage!"
	else:
		combat_status.text = "You attack with your fists for " + str(damage_dealt) + " damage!"
	
	# Emit signal that enemy was damaged
	emit_signal("enemy_damaged", damage_dealt)
	
	# Check if enemy is defeated
	if enemy_health <= 0:
		end_combat(true)
		return
	
	# Enemy attacks back
	await get_tree().create_timer(1.0).timeout
	enemy_attack()

# Function for enemy attack
func enemy_attack():
	if not in_combat:
		return
	
	# Calculate damage with a slight variation
	var damage_taken = int(enemy_damage * randf_range(0.8, 1.2))
	
	# Apply damage to player
	main_game.health -= damage_taken
	
	# Update combat status
	var combat_status = combat_dialog.get_child(0).get_node("CombatStatus")
	combat_status.text = enemy_name + " attacks you for " + str(damage_taken) + " damage!"
	
	# Emit signal that player was damaged
	emit_signal("player_damaged", damage_taken)
	
	# Update main game UI
	main_game.update_stats_display()
	update_combat_dialog()
	
	# For testing purposes: make death happen faster when health is low
	if main_game.health < 30:
		damage_taken = int(enemy_damage * 2.5)  # Extra damage when low health
		main_game.health -= damage_taken
		combat_status.text += "\n" + enemy_name + " lands a critical hit for " + str(damage_taken) + " additional damage!"
		emit_signal("player_damaged", damage_taken)
	
	# Check if player is defeated - immediately end combat if so
	if main_game.health <= 0:
		# Add defeated message
		combat_status.text += "\nYou have been defeated!"
		
		# Give the player time to read the message before ending combat
		await get_tree().create_timer(1.5).timeout
		end_combat(false)

# Function to attempt running from combat
func attempt_escape():
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
	
	var events_container = main_game.get_node_or_null("EventsContainer")
	
	if victory:
		# Player won the fight
		var cash_reward = int(enemy_initial_health * 10 * (1 + randf()))
		main_game.cash += cash_reward
		
		# Add reputation for winning combat
		main_game.add_reputation(5)
		
		if events_container and events_container.has_method("add_custom_event"):
			events_container.add_custom_event("Combat Victory", 
				"You defeated the " + enemy_name + " and found $" + str(cash_reward) + "!",
				{"cash": cash_reward})
				
		main_game.show_message("Victory! You found $" + str(cash_reward))
	else:
		if main_game.health <= 0:
			# Player died
			if events_container and events_container.has_method("add_custom_event"):
				events_container.add_custom_event("Combat Defeat", 
					"You were defeated by the " + enemy_name + ".",
					{"health": -main_game.health})  # Negative of current health to show how much was lost
					
			main_game.show_message("You were defeated!")
			
			# If game over function exists in main game
			if main_game.has_method("trigger_game_over"):
				main_game.call_deferred("trigger_game_over", enemy_name)
		else:
			# Player escaped
			var cash_lost = int(main_game.cash * 0.3)
			main_game.cash -= cash_lost
			
			# Lose some drugs
			var drugs_data = main_game.get_drugs()
			var drugs_to_remove = []
			for drug_name in drugs_data:
				if drugs_data[drug_name]["qty"] > 0:
					drugs_to_remove.append(drug_name)

			if drugs_to_remove.size() > 0:
				var random_drug = drugs_to_remove[randi() % drugs_to_remove.size()]
				var lost_amount = int(drugs_data[random_drug]["qty"] * 0.5)
				main_game.get_node("InventorySystem").remove_drug(random_drug, lost_amount)
				
				if events_container and events_container.has_method("add_custom_event"):
					events_container.add_custom_event("Escaped Combat", 
						"You managed to escape from the " + enemy_name + " but lost $" + str(cash_lost) + " and " + str(lost_amount) + " " + random_drug + ".",
						{"cash": -cash_lost})
						
				main_game.show_message("You lost $" + str(cash_lost) + " and " + str(lost_amount) + " " + random_drug)
			else:
				if events_container and events_container.has_method("add_custom_event"):
					events_container.add_custom_event("Escaped Combat", 
						"You managed to escape from the " + enemy_name + " but lost $" + str(cash_lost) + ".",
						{"cash": -cash_lost})
						
				main_game.show_message("You lost $" + str(cash_lost))
			
			# Reset health to minimum if it's low
			if main_game.health < 10:
				main_game.health = 10

	# Emit signal that combat has ended
	emit_signal("combat_ended", victory)
	
	# Update main game UI
	main_game.update_stats_display()
	main_game.get_node("InventorySystem").update_inventory_display()

# Uses a weapon during combat
func use_weapon():
	if main_game.equipped_weapon != "" and main_game.owned_weapons.has(main_game.equipped_weapon):
		# Reduce durability with each use
		main_game.owned_weapons[main_game.equipped_weapon].durability -= randf_range(1, 5)
		
		# Ensure durability doesn't go below 0
		if main_game.owned_weapons[main_game.equipped_weapon].durability < 0:
			main_game.owned_weapons[main_game.equipped_weapon].durability = 0
		
		# Check if weapon is broken
		if main_game.owned_weapons[main_game.equipped_weapon].durability <= 0:
			main_game.show_message("Your " + main_game.equipped_weapon + " is broken and needs repair!")
			return 0
		
		# Return damage based on weapon and current durability
		var base_damage = main_game.owned_weapons[main_game.equipped_weapon].damage
		var durability_factor = main_game.owned_weapons[main_game.equipped_weapon].durability / 100.0
		
		# Weapon is less effective when durability is low
		return int(base_damage * durability_factor)
	
	# No weapon equipped or doesn't exist
	return 0

# Method to get combat chance based on location
func get_combat_chance(location):
	var combat_chance = 0.1  # Base 10% chance

	if location in ["York", "Pittsburgh"]:
		combat_chance = 0.25  # 25% chance
	elif location in ["Kensington"]:
		combat_chance = 0.2  # 20% chance
		
	return combat_chance
