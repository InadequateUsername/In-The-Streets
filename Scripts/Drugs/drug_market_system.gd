extends Node

# Base prices for drugs
var base_drugs = {
	"Cocaine": {"base_price": 16388, "qty": 0},
	"Hashish": {"base_price": 604, "qty": 0},
	"Heroin": {"base_price": 10016, "qty": 0},
	"Ecstasy": {"base_price": 28, "qty": 0},
	"Smack": {"base_price": 2929, "qty": 0},
	"Opium": {"base_price": 542, "qty": 0},
	"Crack": {"base_price": 1941, "qty": 0},
	"Peyote": {"base_price": 476, "qty": 0},
	"Shrooms": {"base_price": 824, "qty": 0},
	"Speed": {"base_price": 135, "qty": 0},
	"Weed": {"base_price": 657, "qty": 0}
}

var market_table
var inventory_table

# Current market prices (fluctuate by location)
var current_market = {}

# Player's inventory
var player_inventory = {}

# Location price modifiers (multipliers)
var location_modifiers = {
	"Bronx": {
		"Cocaine": [0.8, 1.2],
		"Hashish": [0.9, 1.1],
		"Heroin": [0.7, 1.3],
		"Ecstasy": [0.8, 1.2],
		"Smack": [0.6, 1.4],
		"Opium": [0.9, 1.1],
		"Crack": [0.5, 1.5],
		"Peyote": [0.9, 1.1],
		"Shrooms": [0.8, 1.2],
		"Speed": [0.7, 1.3],
		"Weed": [0.8, 1.2]
	},
	"Manhattan": {
		"Cocaine": [0.9, 1.4],
		"Hashish": [0.8, 1.2],
		"Heroin": [0.9, 1.3],
		"Ecstasy": [0.7, 1.5],
		"Smack": [0.8, 1.2],
		"Opium": [0.9, 1.1],
		"Crack": [0.8, 1.2],
		"Peyote": [0.7, 1.3],
		"Shrooms": [0.6, 1.4],
		"Speed": [0.8, 1.2],
		"Weed": [0.9, 1.1]
	},
	"Kensington": {
		"Cocaine": [0.7, 1.1],
		"Hashish": [0.8, 1.2],
		"Heroin": [0.6, 1.4],
		"Ecstasy": [0.9, 1.1],
		"Smack": [0.5, 1.5],
		"Opium": [0.8, 1.2],
		"Crack": [0.6, 1.4],
		"Peyote": [0.9, 1.1],
		"Shrooms": [0.8, 1.2],
		"Speed": [0.7, 1.3],
		"Weed": [0.7, 1.3]
	},
	"Coney Island": {
		"Cocaine": [0.9, 1.1],
		"Hashish": [0.7, 1.3],
		"Heroin": [0.8, 1.2],
		"Ecstasy": [0.6, 1.4],
		"Smack": [0.9, 1.1],
		"Opium": [0.8, 1.2],
		"Crack": [0.9, 1.1],
		"Peyote": [0.8, 1.2],
		"Shrooms": [0.7, 1.3],
		"Speed": [0.6, 1.4],
		"Weed": [0.6, 1.4]
	},
	"Central Park": {
		"Cocaine": [1.0, 1.3],
		"Hashish": [0.9, 1.1],
		"Heroin": [1.0, 1.2],
		"Ecstasy": [0.8, 1.2],
		"Smack": [0.9, 1.1],
		"Opium": [0.8, 1.2],
		"Crack": [0.9, 1.1],
		"Peyote": [0.7, 1.3],
		"Shrooms": [0.6, 1.4],
		"Speed": [0.8, 1.2],
		"Weed": [0.7, 1.3]
	},
	"Brooklyn": {
		"Cocaine": [0.8, 1.2],
		"Hashish": [0.9, 1.1],
		"Heroin": [0.8, 1.2],
		"Ecstasy": [0.9, 1.1],
		"Smack": [0.8, 1.2],
		"Opium": [0.7, 1.3],
		"Crack": [0.8, 1.2],
		"Peyote": [0.9, 1.1],
		"Shrooms": [0.8, 1.2],
		"Speed": [0.9, 1.1],
		"Weed": [0.8, 1.2]
	}
}

# References to UI elements
var market_container
var inventory_container
var cash_label
var player_cash = 1000  # Starting cash

# Special events that can affect drug prices
var market_events = [
	{
		"drug": "Cocaine",
		"text": "Large shipment of cocaine seized at harbor",
		"effect": 1.5  # 50% price increase
	},
	{
		"drug": "Heroin",
		"text": "New heroin production method floods market",
		"effect": 0.6  # 40% price decrease
	},
	{
		"drug": "Weed",
		"text": "Legalization rumors cause weed prices to plummet",
		"effect": 0.5  # 50% price decrease
	},
	{
		"drug": "Ecstasy",
		"text": "Rave festival season increases demand for Ecstasy",
		"effect": 1.3  # 30% price increase
	},
	{
		"drug": "Crack",
		"text": "Police crackdown on crack dealers",
		"effect": 1.4  # 40% price increase
	}
]

# Chance for a market event (0-100)
var market_event_chance = 20

# Current active market events
var active_market_events = []

func _ready():
	# Initialize player inventory with 0 quantities
	for drug in base_drugs.keys():
		player_inventory[drug] = 0
	
	# Get references to UI containers (these should be set up in the scene)
	market_container = get_parent().get_node("/root/Control/MainContainer/BottomSection/MarketContainer")
	inventory_container = get_parent().get_node("/root/Control/MainContainer/BottomSection/InventoryContainer")
	cash_label = get_parent().get_node("/root/Control/MainContainer/TopSection/StatsContainer/CashRow/CashLabel")
	
	# Initial setup with starting location
	update_market("Bronx")  # Replace with actual starting location

# Update market when player changes location
func update_market(location):
	# Clear any previous market items
	if market_table:
		market_table.clear()
	else:
		print("Warning: MarketTable not found!")
		return
	
	# Reset current market
	current_market.clear()
	
	# Check for market events
	check_market_events()
	
	# Generate new prices based on location
	for drug_name in base_drugs.keys():
		var base_price = base_drugs[drug_name].base_price
		var modifier_range = location_modifiers[location][drug_name]
		
		# Random modifier within the location's range for this drug
		var modifier = randf_range(modifier_range[0], modifier_range[1])
		
		# Apply any active market events
		for event in active_market_events:
			if event.drug == drug_name:
				modifier *= event.effect
		
		# Calculate the new price
		var new_price = int(base_price * modifier)
		
		# Add to current market
		current_market[drug_name] = {
			"price": new_price,
			"available": true
		}
		
		# Add to market table using the table's add_item method
		market_table.add_item([drug_name, "$" + str(new_price), "0", "Buy"])
	
	# Update inventory display
	update_inventory_display()

# Check if any market events should occur
func check_market_events():
	# Clear previous events
	active_market_events.clear()
	
	# Random chance for each possible event
	for event in market_events:
		if randf() * 100 < market_event_chance:
			active_market_events.append(event)
			get_parent().show_notification(event.text)

# Create a market item in the UI
func create_market_item(drug_name, price):
	var item = HBoxContainer.new()
	
	# Drug name label
	var name_label = Label.new()
	name_label.text = drug_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(name_label)
	
	# Price label
	var price_label = Label.new()
	price_label.text = "$" + str(price)
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(price_label)
	
	# Quantity spinbox
	var quantity = SpinBox.new()
	quantity.min_value = 0
	quantity.max_value = 100
	quantity.value = 0
	quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(quantity)
	
	# Buy button
	var buy_button = Button.new()
	buy_button.text = "Buy"
	buy_button.pressed.connect(_on_buy_pressed.bind(drug_name, price, quantity))
	item.add_child(buy_button)
	
	# Add to market container
	market_container.add_child(item)

# Update the inventory display
func update_inventory_display():
	# Clear previous inventory items
	for child in inventory_container.get_children():
		child.queue_free()
	
	# Create inventory items for each drug in player's inventory
	for drug_name in player_inventory.keys():
		var quantity = player_inventory[drug_name]
		
		# Only show drugs that player has in inventory
		if quantity > 0:
			var item = HBoxContainer.new()
			
			# Drug name label
			var name_label = Label.new()
			name_label.text = drug_name
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item.add_child(name_label)
			
			# Quantity label
			var qty_label = Label.new()
			qty_label.text = "x" + str(quantity)
			qty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item.add_child(qty_label)
			
			# Current market price (if available in this location)
			var price_label = Label.new()
			if drug_name in current_market and current_market[drug_name].available:
				price_label.text = "$" + str(current_market[drug_name].price)
			else:
				price_label.text = "N/A"
			price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item.add_child(price_label)
			
			# Quantity spinbox for selling
			var sell_quantity = SpinBox.new()
			sell_quantity.min_value = 0
			sell_quantity.max_value = quantity
			sell_quantity.value = 0
			sell_quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item.add_child(sell_quantity)
			
			# Sell button
			var sell_button = Button.new()
			sell_button.text = "Sell"
			# Only enable sell button if drug is available in current market
			sell_button.disabled = not (drug_name in current_market and current_market[drug_name].available)
			sell_button.pressed.connect(_on_sell_pressed.bind(drug_name, current_market[drug_name].price if drug_name in current_market else 0, sell_quantity))
			item.add_child(sell_button)
			
			# Add to inventory container
			inventory_container.add_child(item)
	
	# Update cash display
	update_cash_display()

# Handle buy button pressed
func _on_buy_pressed(drug_name, price, quantity_spinbox):
	var quantity = int(quantity_spinbox.value)
	if quantity <= 0:
		return
	
	var total_cost = price * quantity
	
	# Check if player has enough cash
	if player_cash >= total_cost:
		# Purchase the drugs
		player_cash -= total_cost
		player_inventory[drug_name] += quantity
		
		# Reset spinbox
		quantity_spinbox.value = 0
		
		# Update displays
		update_inventory_display()
		get_parent().show_notification("Bought " + str(quantity) + " " + drug_name + " for $" + str(total_cost))
	else:
		get_parent().show_notification("Not enough cash!")

# Handle sell button pressed
func _on_sell_pressed(drug_name, price, quantity_spinbox):
	var quantity = int(quantity_spinbox.value)
	if quantity <= 0:
		return
	
	var total_earnings = price * quantity
	
	# Sell the drugs
	player_cash += total_earnings
	player_inventory[drug_name] -= quantity
	
	# Update displays
	update_inventory_display()
	get_parent().show_notification("Sold " + str(quantity) + " " + drug_name + " for $" + str(total_earnings))

# Update the cash display
func update_cash_display():
	cash_label.text = "Cash: $" + str(player_cash)

# Public method to set cash (for use from main game)
func set_cash(amount):
	player_cash = amount
	update_cash_display()

# Public method to add cash (for use from main game)
func add_cash(amount):
	player_cash += amount
	update_cash_display()

# Public method to get current cash amount
func get_cash():
	return player_cash

# Public method to handle location change
func change_location(new_location):
	update_market(new_location)
