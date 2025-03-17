extends Node

# Signal to notify main game of events
signal event_triggered(event_data)

# Probability of an event occurring when changing locations
var event_chance = 0.3  # 30% chance

# List of possible random events
var random_events = [
	{
		"title": "Unexpected Arrest",
		"description": "Police raid the area! You ditch your stuff and run.",
		"effects": {
			"cash": -200,
			"health": -10,
			"heat": 20,
			"inventory": -0.5  # Lose 50% of current inventory
		}
	},
	{
		"title": "Gang Confrontation",
		"description": "Local gang members demand protection money.",
		"effects": {
			"cash": -500,
			"health": -5
		}
	},
	{
		"title": "Street Mugging",
		"description": "You get mugged on your way through a dark alley.",
		"effects": {
			"cash": -350,
			"health": -15
		}
	},
	{
		"title": "Drug Bust",
		"description": "Police bust a major supplier, prices are going up!",
		"effects": {
			"market_modifier": 1.5,  # Increase prices by 50%
			"heat": 10
		}
	},
	{
		"title": "New Supplier",
		"description": "A new supplier has entered the market, prices are dropping!",
		"effects": {
			"market_modifier": 0.7  # Decrease prices by 30%
		}
	},
	{
		"title": "Informant Tip",
		"description": "An informant gives you valuable information about police patrols.",
		"effects": {
			"heat": -15,
		}
	},
	{
		"title": "Free Samples",
		"description": "A dealer gives you free samples to build connections.",
		"effects": {
			"inventory_add": {"random": true, "amount": 1},
		}
	},
	{
		"title": "Medical Emergency",
		"description": "You help someone having an overdose. It takes time but builds your rep.",
		"effects": {
			"time": 2,
		}
	},
	{
		"title": "Quick Sale",
		"description": "You make a quick sale to someone desperate.",
		"effects": {
			"cash": 800,
		}
	},
	{
		"title": "Police Chase",
		"description": "Police spot you and give chase! You manage to escape but not unscathed.",
		"effects": {
			"health": -20,
			"heat": 25,
			"time": 3
		}
	}
]

# Location-specific events that have higher chance in certain locations
var location_specific_events = {
	"Bronx": [
		{
			"title": "Bronx Street Fight",
			"description": "You get caught in the middle of a street fight.",
			"effects": {
				"health": -25,
			},
			"chance": 0.4  # 40% chance when in Bronx
		}
	],
	"Manhattan": [
		{
			"title": "Rich Client",
			"description": "A wealthy Manhattan resident offers premium price for your goods.",
			"effects": {
				"cash": 1500,
			},
			"chance": 0.3
		}
	],
	"Kensington": [
		{
			"title": "Drug Lab Raid",
			"description": "A nearby drug lab gets raided. Everyone's on high alert.",
			"effects": {
				"heat": 30,
				"market_modifier": 1.3
			},
			"chance": 0.4
		}
	],
	"Coney Island": [
		{
			"title": "Beach Party",
			"description": "There's a huge party at the beach. High demand for party drugs!",
			"effects": {
				"market_modifier": {"drug": "Ecstasy", "value": 1.8}
			},
			"chance": 0.5
		}
	],
	"Central Park": [
		{
			"title": "Park Dealer Turf War",
			"description": "Dealers in Central Park are fighting over territory.",
			"effects": {
				"reputation": -10,
				"heat": 15,
				"market_modifier": 0.8
			},
			"chance": 0.35
		}
	],
	"Brooklyn": [
		{
			"title": "Brooklyn Connection",
			"description": "You meet a well-connected dealer in Brooklyn who shares contacts.",
			"effects": {
				"reputation": 5
			},
			"chance": 0.3
		}
	]
}

# Function to check if an event should occur when player changes location
func check_for_event(location):
	# First check for location-specific events
	if location in location_specific_events:
		for event in location_specific_events[location]:
			if randf() < event.chance:
				# Trigger this location-specific event
				emit_signal("event_triggered", event)
				return true
	
	# If no location-specific event triggered, check for random events
	if randf() < event_chance:
		# Choose a random event
		var random_event = random_events[randi() % random_events.size()]
		emit_signal("event_triggered", random_event)
		return true
	
	return false

# Function to apply event effects to the game state
func apply_event_effects(event_data, game_controller):
	var effects = event_data.effects
	
	# Apply each effect to the game
	for effect_type in effects:
		var effect_value = effects[effect_type]
		
		match effect_type:
			"cash":
				game_controller.add_cash(effect_value)
			"health":
				game_controller.add_health(effect_value)
			"heat":
				game_controller.add_heat(effect_value)
			"reputation":
				game_controller.add_reputation(effect_value)
			"time":
				game_controller.add_time(effect_value)
			"inventory":
				if effect_value < 0:
					# Lose inventory
					reduce_inventory(game_controller, abs(effect_value))
			"inventory_add":
				if effect_value.has("random") and effect_value.random:
					add_random_drugs(game_controller, effect_value.amount)
			"market_modifier":
				if typeof(effect_value) == TYPE_DICTIONARY:
					# Apply modifier to specific drug
					modify_specific_drug_price(game_controller, effect_value.drug, effect_value.value)
				else:
					# Apply general market modifier
					modify_market_prices(game_controller, effect_value)

# Helper function to reduce inventory by percentage
func reduce_inventory(game_controller, percentage):
	# Let the inventory system handle this
	if game_controller.has_node("InventorySystem"):
		game_controller.get_node("InventorySystem").reduce_inventory(percentage)
	else:
		print("ERROR: InventorySystem node not found")
	
	# The inventory system will handle capacity calculation and display updates

# Helper function to add random drugs to inventory
func add_random_drugs(game_controller, amount):
	# Let the inventory system handle this
	if game_controller.has_node("InventorySystem"):
		game_controller.get_node("InventorySystem").add_random_drugs(amount)
	else:
		print("ERROR: InventorySystem node not found")

# Helper function to modify specific drug price
func modify_specific_drug_price(game_controller, drug_name, price_modifier):
	game_controller.get_node("MarketSystem").apply_drug_modifier(drug_name, price_modifier)
	game_controller.update_market_display()

# Helper function to modify all market prices
func modify_market_prices(game_controller, modifier):
	var drugs_data = game_controller.get_drugs()  # Use the getter function
	for drug_name in drugs_data:
		var base_price = game_controller.get_base_drug_prices()[drug_name]
		game_controller.set_drug_price(drug_name, int(base_price * modifier))
	
	game_controller.get_node("MarketSystem").apply_market_modifier(modifier)
	game_controller.update_market_display()

# Display event in UI and apply effects
func process_event(event_data, game_controller):
	# Show event notification
	game_controller.show_message(event_data.title + ": " + event_data.description, 5.0)
	
	# Apply event effects
	apply_event_effects(event_data, game_controller)

func add_cash(amount, game_controller):
	# Add the amount to player's cash via the game controller
	# Show a message based on whether gaining or losing money
	if amount > 0:
		game_controller.show_message("You gained $" + str(amount))
	else:
		game_controller.show_message("You lost $" + str(abs(amount)))

	# Update the UI via game controller
	game_controller.cash += amount
	game_controller.update_stats_display()

func check_for_travel_event(location):
	# First check for location-specific events
	if location in location_specific_events:
		for event in location_specific_events[location]:
			# Only consider events that don't reduce health
			if not event.effects.has("health") or event.effects["health"] >= 0:
				if randf() < event.chance:
					# Trigger this location-specific event
					emit_signal("event_triggered", event)
					return true
	
	# If no location-specific event triggered, check for random events
	if randf() < event_chance:
		# Filter out harmful events
		var safe_events = []
		for event in random_events:
			if not event.effects.has("health") or event.effects["health"] >= 0:
				safe_events.append(event)
		
		# Choose a random safe event if any exist
		if safe_events.size() > 0:
			var random_event = safe_events[randi() % safe_events.size()]
			emit_signal("event_triggered", random_event)
			return true
	
	return false
