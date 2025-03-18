# inventory_system.gd
extends Node

signal inventory_changed
signal capacity_changed
signal drug_purchased(drug_name, quantity, cost)
signal drug_sold(drug_name, quantity, revenue)

# References to main game and UI
var main_game
var inventory_list
var capacity_label
var quantity_dialog

# Inventory variables
var drugs = {}
var base_drug_prices = {}
var pocket_capacity = 100
var current_capacity = 0

# Dialog vars
var current_drug
var current_price
var is_buying = false
var quantity_slider
var confirm_button
var cancel_button

func _ready():
	# Get reference to main game
	main_game = get_node("/root/Control")
	
	# Get UI references
	inventory_list = main_game.get_node("MainContainer/BottomSection/InventoryContainer/InventoryList")
	capacity_label = main_game.get_node("MainContainer/BottomSection/InventoryContainer/PanelContainer/CapacityLabel")
	
	# Initialize drug prices
	initialize_drugs()
	
	# Setup quantity dialog
	setup_quantity_dialog()

func initialize_drugs():
	# Drug prices and quantities
	drugs = {
		"Cocaine": {"price": 16000, "qty": 0},
		"Hashish": {"price": 604, "qty": 0},
		"Heroin": {"price": 10016, "qty": 0},
		"Ecstasy": {"price": 28, "qty": 0},
		"Smack": {"price": 2929, "qty": 0},
		"Opium": {"price": 542, "qty": 0},
		"Crack": {"price": 1941, "qty": 0},
		"Peyote": {"price": 476, "qty": 0},
		"Shrooms": {"price": 824, "qty": 0},
		"Speed": {"price": 135, "qty": 0},
		"Weed": {"price": 657, "qty": 0}
	}

	# Base drug prices (for price fluctuation calculations)
	base_drug_prices = {
		"Cocaine": 16000,
		"Hashish": 600,
		"Heroin": 10000,
		"Ecstasy": 30,
		"Smack": 3000,
		"Opium": 550,
		"Crack": 2000,
		"Peyote": 480,
		"Shrooms": 800,
		"Speed": 140,
		"Weed": 650
	}
	
	calculate_current_capacity()

# Calculate current inventory capacity
func calculate_current_capacity():
	current_capacity = 0
	for drug_name in drugs:
		current_capacity += drugs[drug_name]["qty"]
	
	emit_signal("capacity_changed", current_capacity, pocket_capacity)
	return current_capacity

# Update inventory display
func update_inventory_display():
	if not is_instance_valid(inventory_list):
		return
		
	inventory_list.clear()
	inventory_list.set_columns(["Drug", "Qty"], [0.7, 0.3])
	
	for drug_name in drugs:
		if drugs[drug_name]["qty"] > 0:
			var qty_int = int(drugs[drug_name]["qty"])
			inventory_list.add_item([drug_name, str(qty_int)])
	
	capacity_label.text = "Pocket Space: " + str(int(current_capacity)) + "/" + str(int(pocket_capacity))
	
	emit_signal("inventory_changed")

# Setup the quantity dialog for buying/selling drugs
func setup_quantity_dialog():
	# Create dialog
	quantity_dialog = PopupPanel.new()
	quantity_dialog.title = "Select Quantity"
	main_game.call_deferred("add_child", quantity_dialog)
	
	# Create container
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 150)
	quantity_dialog.add_child(vbox)
	
	# Add label
	var label = Label.new()
	label.text = "Select Quantity:"
	vbox.add_child(label)
	
	# Add slider
	quantity_slider = HSlider.new()
	quantity_slider.min_value = 1
	quantity_slider.max_value = 10000
	quantity_slider.step = 1
	quantity_slider.value = 1
	vbox.add_child(quantity_slider)
	
	# Add quantity display
	var qty_display = Label.new()
	qty_display.text = "Quantity: 1"
	vbox.add_child(qty_display)
	
	# Add total display
	var total_display = Label.new()
	total_display.text = "Total: $0"
	vbox.add_child(total_display)
	
	# Update displays when slider changes
	quantity_slider.value_changed.connect(func(value): 
		qty_display.text = "Quantity: " + str(int(value))
		total_display.text = "Total: $" + str(int(value) * current_price)
	)
	
	# Add buttons
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	hbox.add_child(cancel_button)
	
	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	hbox.add_child(confirm_button)
	
	# Connect buttons
	cancel_button.pressed.connect(func(): quantity_dialog.hide())
	confirm_button.pressed.connect(func(): confirm_quantity())

# Shows dialog for buying drugs
func buy_drugs():
	# Get selected drug from market list
	var market_list = main_game.get_node("MainContainer/BottomSection/MarketContainer/MarketList")
	var selected_idx = market_list.selected_index
	if selected_idx == -1:
		main_game.show_message("No drug selected to buy")
		return
		
	# Extract drug name and price from the selected item
	var selected_item = market_list.rows[selected_idx]
	if not selected_item is Array or selected_item.size() < 2:
		main_game.show_message("Invalid selection format")
		return
		
	var drug_name = selected_item[0]
	var price_str = selected_item[1]
	var price = int(price_str.substr(1))  # Remove the $ character
	
	# Calculate maximum amount the player can buy
	var max_affordable = int(main_game.cash / price)
	var max_by_space = floor((pocket_capacity - current_capacity))
	var max_qty = min(max_affordable, max_by_space)
	
	if max_qty <= 0:
		# Can't afford any or no space
		if max_affordable <= 0:
			main_game.show_message("You can't afford any " + drug_name)
		else:
			main_game.show_message("You don't have enough space in your pockets.")
		return
	
	# Show quantity dialog
	show_quantity_dialog(drug_name, price, max_qty, true)

# Shows dialog for selling drugs
func sell_drugs():
	# Get selected drug from inventory list
	var selected_idx = inventory_list.selected_index
	if selected_idx == -1:
		main_game.show_message("No drug selected to sell")
		return
		
	# Extract drug name and quantity from the selected item
	var selected_item = inventory_list.rows[selected_idx]
	if not selected_item is Array or selected_item.size() < 2:
		main_game.show_message("Invalid selection format")
		return
		
	var drug_name = selected_item[0]
	var quantity = int(selected_item[1])
	
	# Get the current market price from MarketSystem instead of inventory
	var price = main_game.get_node("Scripts/MarketSystem").get_drug_price(drug_name)
	
	if quantity <= 0:
		main_game.show_message("You don't have any " + drug_name + " to sell")
		return
	
	# Show quantity dialog for selling
	show_quantity_dialog(drug_name, price, quantity, false)

# Shows the quantity selection dialog
func show_quantity_dialog(drug_name, price, max_qty, buying=true):
	current_drug = drug_name
	current_price = price
	is_buying = buying
	
	# Set slider range
	quantity_slider.max_value = max_qty
	quantity_slider.value = 1
	
	# Update title
	if buying:
		quantity_dialog.title = "Buy " + drug_name
	else:
		quantity_dialog.title = "Sell " + drug_name
	
	# Show dialog
	quantity_dialog.popup_centered()

# Confirms the drug purchase or sale
func confirm_quantity():
	var quantity = int(quantity_slider.value)
	
	if is_buying:
		# Buy the drugs
		var total_cost = int(current_price * quantity)
		main_game.cash -= total_cost
		drugs[current_drug]["qty"] += quantity
		current_capacity += quantity
		main_game.show_message("Bought " + str(quantity) + " " + current_drug + " for $" + str(total_cost))
		emit_signal("drug_purchased", current_drug, quantity, total_cost)
		deselect_all()
	else:
		# Sell the drugs
		var total_revenue = int(current_price * quantity)
		main_game.cash += total_revenue
		drugs[current_drug]["qty"] -= quantity
		current_capacity -= quantity
		main_game.show_message("Sold " + str(quantity) + " " + current_drug + " for $" + str(total_revenue))
		emit_signal("drug_sold", current_drug, quantity, total_revenue)
		deselect_all()
		
		# Add heat when selling drugs - random between 1-5 points per transaction
		var heat_increase = randi_range(1, 5)
		main_game.add_heat(heat_increase)
		main_game.show_message("Heat increased by " + str(heat_increase) + " for selling drugs")
		
		# Check if heat reached threshold for possible police event
		if main_game.heat >= 50:
			# 20% chance of triggering police event when heat is 50+
			if randf() < 0.2:
				main_game.call_deferred("trigger_police_event")
	
	# Make sure all values are integers
	drugs[current_drug]["qty"] = int(drugs[current_drug]["qty"])
	current_capacity = int(current_capacity)
	main_game.cash = int(main_game.cash)
	
	# Mark that we have unsaved changes
	main_game.has_unsaved_changes = true
	
	# Update UI
	main_game.update_stats_display()
	update_inventory_display()
	
	# Hide dialog
	quantity_dialog.hide()

# Helper function to reduce inventory by percentage
func reduce_inventory(percentage):
	for drug_name in drugs:
		var current_qty = drugs[drug_name].qty
		if current_qty > 0:
			var lose_amount = int(current_qty * percentage)
			drugs[drug_name].qty -= lose_amount
			if drugs[drug_name].qty < 0:
				drugs[drug_name].qty = 0
	
	# Recalculate current capacity
	calculate_current_capacity()
	update_inventory_display()

# Helper function to add random drugs to inventory
func add_random_drugs(amount):
	# Get a list of all drugs
	var all_drugs = drugs.keys()
	
	# Choose a random drug
	var random_drug = all_drugs[randi() % all_drugs.size()]
	
	# Add the specified amount
	drugs[random_drug].qty += amount
	
	# Update capacity and display
	calculate_current_capacity()
	update_inventory_display()

# Clear selection in lists
func deselect_all():
	var market_list = main_game.get_node("MainContainer/BottomSection/MarketContainer/MarketList")
	if is_instance_valid(market_list):
		market_list.selected_index = -1

	if is_instance_valid(inventory_list):
		inventory_list.selected_index = -1

# Reset inventory (for new game)
func reset_inventory():
	# Reset quantities to zero
	for drug_name in drugs:
		drugs[drug_name]["qty"] = 0
	
	# Reset capacity
	current_capacity = 0
	
	# Update display
	update_inventory_display()

# Get drug data (for save/load)
func get_drug_data():
	return drugs

# Set drug data (for save/load)
func set_drug_data(new_data):
	for drug_name in new_data:
		if drugs.has(drug_name):
			drugs[drug_name]["price"] = int(new_data[drug_name]["price"])
			drugs[drug_name]["qty"] = int(new_data[drug_name]["qty"])
	
	calculate_current_capacity()
	update_inventory_display()


func update_drug_price(drug_name, new_price):
	if drugs.has(drug_name):
		drugs[drug_name]["price"] = new_price

# Remove a specific amount of a drug from inventory
func remove_drug(drug_name, amount):
	if drugs.has(drug_name):
		# Ensure we don't remove more than exists
		var actual_amount = min(amount, drugs[drug_name]["qty"])
		drugs[drug_name]["qty"] -= actual_amount
		
		# Make sure we don't go below zero
		if drugs[drug_name]["qty"] < 0:
			drugs[drug_name]["qty"] = 0
		
		# Recalculate capacity
		calculate_current_capacity()
		update_inventory_display()
		
		return actual_amount
	
	return 0
