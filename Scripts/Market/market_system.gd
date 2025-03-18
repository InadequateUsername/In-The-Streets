extends Node
class_name MarketSystem

# Signal to notify other systems of market updates
signal market_updated(drug_prices)
signal market_event_triggered(event_data)

# Base drug prices (reference values)
var base_drug_prices = {
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

# Current drug prices
var current_prices = {}

# Location price modifiers (percentage adjustment)
var location_modifiers = {
	"Erie": {"Crack": 80, "Weed": 110, "Speed": 90},
	"York": {"Cocaine": 120, "Heroin": 110, "Ecstasy": 130},
	"Kensington": {"Hashish": 90, "Smack": 80, "Shrooms": 70},
	"Pittsburgh": {"Weed": 120, "Ecstasy": 80, "Peyote": 110},
	"Love Park": {"Shrooms": 120, "Peyote": 130, "Weed": 90},
	"Reading": {"Crack": 70, "Smack": 85, "Speed": 120}
}

# Market events (rare price spikes or crashes)
var market_events = [
	{"name": "Police Bust", "drug": "", "message": "Police busted a major supplier! DRUG_NAME prices are soaring!", "effect": 250},
	{"name": "New Shipment", "drug": "", "message": "A new shipment of DRUG_NAME has flooded the market. Prices are crashing!", "effect": 40},
	{"name": "Gang War", "drug": "", "message": "A gang war has disrupted the DRUG_NAME trade. Prices are up!", "effect": 180},
	{"name": "Lab Raid", "drug": "", "message": "DEA raided several DRUG_NAME labs. Prices are up!", "effect": 200},
	{"name": "Addicts Dying", "drug": "", "message": "Too many DRUG_NAME users are dying. Demand is down!", "effect": 60},
	{"name": "Celebrity Overdose", "drug": "", "message": "A celebrity OD'd on DRUG_NAME. The drug is trending!", "effect": 150}
]

# Reference to the main game
var main_game

# Initialize with base values
func _ready():
	# Get reference to main game
	main_game = get_node("/root/Control")
	
	# Initialize current prices with base values
	for drug_name in base_drug_prices:
		current_prices[drug_name] = base_drug_prices[drug_name]

# Update market prices based on location
func update_market_prices(location):
	# 10% chance of a market event
	var event_chance = randf()
	var event_triggered = false
	
	if event_chance < 0.1:
		# Trigger a random market event
		event_triggered = trigger_market_event()
	
	# Normal price fluctuations for all drugs
	for drug_name in base_drug_prices:
		# Skip drug if it was affected by an event
		if event_triggered and drug_name == current_prices["event_drug"]:
			continue
			
		# Start with the base price
		var base_price = base_drug_prices[drug_name]
		
		# Apply location modifiers if any exist for this drug in this location
		var location_modifier = 100
		if location_modifiers.has(location) and location_modifiers[location].has(drug_name):
			location_modifier = location_modifiers[location][drug_name]
		
		# Calculate adjusted base price
		var adjusted_base = int(base_price * (location_modifier / 100.0))
		
		# Apply random fluctuation (80% to 120% of the adjusted base price)
		var fluctuation = randf_range(0.8, 1.2)
		var new_price = int(adjusted_base * fluctuation)
		
		# Set the new price
		current_prices[drug_name] = new_price
	
	# Emit signal that market has been updated
	emit_signal("market_updated", current_prices)
	
	return current_prices

# Trigger a random market event
func trigger_market_event():
	# Choose a random event
	var event = market_events[randi() % market_events.size()]
	
	# Select a random drug for this event
	var all_drugs = base_drug_prices.keys()
	var random_drug = all_drugs[randi() % all_drugs.size()]
	
	# Apply the effect
	var base_price = base_drug_prices[random_drug]
	var new_price = int(base_price * (event["effect"] / 100.0))
	current_prices[random_drug] = new_price
	
	# Store which drug was affected by the event
	current_prices["event_drug"] = random_drug
	
	# Create event data
	var event_data = {
		"name": event["name"],
		"drug": random_drug,
		"message": event["message"].replace("DRUG_NAME", random_drug),
		"price": new_price,
		"effect": event["effect"]
	}
	
	# Emit signal that an event occurred
	emit_signal("market_event_triggered", event_data)
	
	return true

# Get current drug prices
func get_current_prices():
	return current_prices

# Get price for a specific drug
func get_drug_price(drug_name):
	if current_prices.has(drug_name):
		return current_prices[drug_name]
	return 0

# Set price for a specific drug
func set_drug_price(drug_name, price):
	if base_drug_prices.has(drug_name):
		current_prices[drug_name] = price
		emit_signal("market_updated", current_prices)

# Apply a market modifier to all drugs
func apply_market_modifier(modifier):
	for drug_name in base_drug_prices:
		var base_price = base_drug_prices[drug_name]
		current_prices[drug_name] = int(base_price * modifier)
	
	emit_signal("market_updated", current_prices)

# Apply a modifier to a specific drug
func apply_drug_modifier(drug_name, modifier):
	if base_drug_prices.has(drug_name):
		var base_price = base_drug_prices[drug_name]
		current_prices[drug_name] = int(base_price * modifier)
		emit_signal("market_updated", current_prices)

# Reset prices to base values
func reset_prices():
	for drug_name in base_drug_prices:
		current_prices[drug_name] = base_drug_prices[drug_name]
	
	emit_signal("market_updated", current_prices)

# Get current location
func get_current_location():
	if main_game and is_instance_valid(main_game) and main_game.has_node("LocationSystem"):
		return main_game.get_node("Scripts/LocationSystem").current_location
	return ""
