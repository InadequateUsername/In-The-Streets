extends Node

# Theme colors
const DARK_BG_COLOR = Color("#1E1E1E")
const DARKER_BG_COLOR = Color("#252526")
const DARKEST_BG_COLOR = Color("#0D0D0D")
const BUTTON_BG_COLOR = Color("#333333")
const BUTTON_ACTIVE_BG_COLOR = Color("#444444")
const BORDER_COLOR = Color("#555555")
const SELECTION_COLOR = Color("#01733a")
const TEXT_COLOR = Color("#CCCCCC")
const CASH_COLOR = Color("#4DF75B")  # Bright green
const DEBT_COLOR = Color("#FF5555")  # Bright red
const GUNS_COLOR = Color("#F7F34D")  # Bright yellow
const HEALTH_COLOR = Color("#0066CC")  # Medium blue

# Button colors
const BUY_BG_COLOR = Color("#2D882D")  # Darker green
const BUY_HOVER_COLOR = Color("#3AA83A")  # Medium green
const BUY_PRESSED_COLOR = Color("#4BC44B")  # Lighter green
const BUY_BORDER_COLOR = Color("#88FF88")  # Light green border

const SELL_BG_COLOR = Color("#AA2828")  # Darker red
const SELL_HOVER_COLOR = Color("#CC3232")  # Medium red
const SELL_PRESSED_COLOR = Color("#E03C3C")  # Lighter red
const SELL_BORDER_COLOR = Color("#FF8888")  # Light red border

const INACTIVE_BUTTON_COLOR = Color("#555555")  # Gray for inactive buttons
const INACTIVE_BORDER_COLOR = Color("#777777")  # Light gray border

# References to buttons
var buy_button: Button
var sell_button: Button
var market_list
var inventory_list

func _ready():
	# Wait one frame to ensure all nodes are properly initialized
	await get_tree().process_frame
	
	# Store references to important nodes
	buy_button = get_node_or_null("MainContainer/BottomSection/ActionButtons/BuyButton")
	sell_button = get_node_or_null("MainContainer/BottomSection/ActionButtons/SellButton")
	market_list = get_node_or_null("MainContainer/BottomSection/MarketContainer/MarketList")
	inventory_list = get_node_or_null("MainContainer/BottomSection/InventoryContainer/InventoryList")
	
	# Add all buttons to the "buttons" group
	var all_buttons = []
	find_all_buttons(get_tree().root, all_buttons)
	for button in all_buttons:
		button.add_to_group("buttons")
	
	# Apply dark theme to the entire UI
	apply_dark_theme()
	
	# Connect signals for list selections
	if market_list:
		if not market_list.is_connected("item_selected", Callable(self, "_on_market_item_selected")):
			market_list.item_selected.connect(_on_market_item_selected)
	
	if inventory_list:
		if not inventory_list.is_connected("item_selected", Callable(self, "_on_inventory_item_selected")):
			inventory_list.item_selected.connect(_on_inventory_item_selected)
	
	# Initially disable both buttons
	set_button_inactive(buy_button)
	set_button_inactive(sell_button)

# Signal handlers for list selections
func _on_market_item_selected(_index):
	# Enable buy button and disable sell button
	set_button_active(buy_button)
	set_button_inactive(sell_button)
	
	# If inventory also has a selection, clear it
	if inventory_list and inventory_list.is_anything_selected():
		inventory_list.deselect_all()

func _on_inventory_item_selected(_index):
	# Enable sell button and disable buy button
	set_button_active(sell_button)
	set_button_inactive(buy_button)
	
	# If market also has a selection, clear it
	if market_list and market_list.is_anything_selected():
		market_list.deselect_all()

# Set a button to active state with its default colors
func set_button_active(button):
	if not button:
		return
		
	var bg_color
	var hover_color
	var pressed_color
	var border_color
	
	if button.name == "Buy":
		bg_color = BUY_BG_COLOR
		hover_color = BUY_HOVER_COLOR
		pressed_color = BUY_PRESSED_COLOR
		border_color = BUY_BORDER_COLOR
	elif button.name == "Sell":
		bg_color = SELL_BG_COLOR
		hover_color = SELL_HOVER_COLOR
		pressed_color = SELL_PRESSED_COLOR
		border_color = SELL_BORDER_COLOR
	else:
		# Default colors for other buttons
		bg_color = BUTTON_BG_COLOR
		hover_color = Color(BUTTON_BG_COLOR.r + 0.1, BUTTON_BG_COLOR.g + 0.1, BUTTON_BG_COLOR.b + 0.1)
		pressed_color = BUTTON_ACTIVE_BG_COLOR
		border_color = BORDER_COLOR
	
	apply_button_style(button, bg_color, hover_color, pressed_color, border_color)
	button.disabled = false

# Set a button to inactive (gray) state
func set_button_inactive(button):
	if not button:
		return
		
	apply_button_style(button, INACTIVE_BUTTON_COLOR, INACTIVE_BUTTON_COLOR, 
		INACTIVE_BUTTON_COLOR, INACTIVE_BORDER_COLOR)
	button.disabled = true

# Apply specific style to a button
func apply_button_style(button, bg_color, hover_color, pressed_color, border_color):
	# Normal state
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = bg_color
	normal_style.set_border_width_all(1)
	normal_style.border_color = border_color
	normal_style.set_corner_radius_all(3)
	
	# Hover state
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = hover_color
	hover_style.set_border_width_all(1)
	hover_style.border_color = border_color
	hover_style.set_corner_radius_all(3)
	
	# Pressed state
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = pressed_color
	pressed_style.set_border_width_all(1)
	pressed_style.border_color = border_color
	pressed_style.set_corner_radius_all(3)
	
	# Focus state
	var focus_style = StyleBoxFlat.new()
	focus_style.bg_color = bg_color
	focus_style.set_border_width_all(2)
	focus_style.border_color = SELECTION_COLOR
	focus_style.set_corner_radius_all(3)
	
	# Apply styles
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", focus_style)
	button.add_theme_stylebox_override("disabled", normal_style.duplicate())
	
	# Text color
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(TEXT_COLOR, 0.5))  # Semi-transparent

# Recursively find all buttons in the scene
func find_all_buttons(node, button_list):
	if node is Button:
		button_list.append(node)
	
	for child in node.get_children():
		find_all_buttons(child, button_list)

func apply_dark_theme():
	# Create the base theme
	var darktheme = Theme.new()
	
	# Set up default font
	var default_font = ThemeDB.fallback_font
	darktheme.set_default_font(default_font)
	darktheme.set_default_font_size(14)
	
	# Apply theme to the root control
	var root_control = get_parent()
	if root_control:
		root_control.theme = darktheme
	
	# Style each component
	style_panels()
	style_stats_panels()
	style_buttons()
	style_tables()
	style_progress_bars()
	style_event_container()


# Add this function to style the event container
func style_event_container():
	var events_container = get_node_or_null("/root/Control/EventsContainer")
	if not events_container:
		return
		
	# Container style
	var container_style = StyleBoxFlat.new()
	container_style.bg_color = DARKER_BG_COLOR
	container_style.set_border_width_all(1)
	container_style.border_color = BORDER_COLOR
	container_style.set_corner_radius_all(5)  # Rounded corners
	events_container.add_theme_stylebox_override("panel", container_style)
	
	# Find the title label
	for child in events_container.get_children():
		if child is VBoxContainer:
			for grandchild in child.get_children():
				if grandchild is Label:
					grandchild.add_theme_color_override("font_color", Color("#0077FF"))  # Blue title
					grandchild.add_theme_font_size_override("font_size", 16)

func style_panels():
	# Main background panel
	var main_panel = get_node_or_null("MainContainer")
	if not main_panel:
		push_warning("Could not find MainContainer")
		return
		
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = DARK_BG_COLOR
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color.BLACK
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Top section panel
	var top_section = get_node_or_null("MainContainer/TopSection")
	if top_section:
		var top_style = StyleBoxFlat.new()
		top_style.bg_color = DARK_BG_COLOR
		top_section.add_theme_stylebox_override("panel", top_style)
	
	# Bottom section panel
	var bottom_section = get_node_or_null("MainContainer/BottomSection")
	if bottom_section:
		var bottom_style = StyleBoxFlat.new()
		bottom_style.bg_color = DARK_BG_COLOR
		bottom_section.add_theme_stylebox_override("panel", bottom_style)
	
	# Location container
	var location_container = get_node_or_null("MainContainer/TopSection/LocationContainer")
	if location_container:
		var location_style = StyleBoxFlat.new()
		location_style.bg_color = DARKER_BG_COLOR
		location_style.set_border_width_all(1)
		location_style.border_color = BORDER_COLOR
		location_container.add_theme_stylebox_override("panel", location_style)
	
	# Apply text color to all labels
	var all_labels = []
	find_all_labels(get_tree().root, all_labels)
	for label in all_labels:
		label.add_theme_color_override("font_color", TEXT_COLOR)

# Recursively find all labels in the scene
func find_all_labels(node, label_list):
	if node is Label:
		label_list.append(node)
	
	for child in node.get_children():
		find_all_labels(child, label_list)

func style_stats_panels():
	# Apply styling to stats panels (Cash, Bank, Debt, Guns)
	style_stat_panel("MainContainer/TopSection/StatsContainer/CashRow", CASH_COLOR)
	style_stat_panel("MainContainer/TopSection/StatsContainer/DebtRow", DEBT_COLOR)
	style_stat_panel("MainContainer/TopSection/StatsContainer/GunsRow", GUNS_COLOR)

func style_stat_panel(node_path, text_color):
	var panel = get_node_or_null(node_path)
	if not panel:
		push_warning("Could not find node: " + node_path)
		return
	
	# Panel background
	var style = StyleBoxFlat.new()
	style.bg_color = DARKEST_BG_COLOR
	style.set_border_width_all(1)
	style.border_color = BORDER_COLOR
	panel.add_theme_stylebox_override("panel", style)
	
	# Find label and value children
	var label_node = null
	var value_node = null
	
	for child in panel.get_children():
		if "Label" in child.name:
			label_node = child
		elif "Value" in child.name:
			value_node = child
	
	# Apply styling to children
	if label_node:
		label_node.add_theme_color_override("font_color", text_color)
	
	if value_node:
		value_node.add_theme_color_override("font_color", text_color)

func style_buttons():
	# Get all buttons
	var buttons = get_tree().get_nodes_in_group("buttons")
	
	for button in buttons:
		# Skip Buy and Sell buttons as they will be handled separately
		if button.name == "Buy" or button.name == "Sell":
			continue
			
		var bg_color = BUTTON_BG_COLOR
		var hover_color = Color(BUTTON_BG_COLOR.r + 0.1, BUTTON_BG_COLOR.g + 0.1, BUTTON_BG_COLOR.b + 0.1)
		var pressed_color = BUTTON_ACTIVE_BG_COLOR
		var border_color = BORDER_COLOR
		var text_color = TEXT_COLOR
		
		# Default styling for action buttons
		if button.get_parent() and button.get_parent().name == "ActionButtons":
			bg_color = Color("#4D8A4D")  # Green for other action buttons
			hover_color = Color("#5AAD5A")
			pressed_color = Color("#75C675")
			border_color = Color("#88FF88")
			text_color = Color.WHITE
		
		# Normal state
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = bg_color
		normal_style.set_border_width_all(1)
		normal_style.border_color = border_color
		normal_style.set_corner_radius_all(3)  # Rounded corners for better appearance
		
		# Hover state
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = hover_color
		hover_style.set_border_width_all(1)
		hover_style.border_color = border_color
		hover_style.set_corner_radius_all(3)
		
		# Pressed state
		var pressed_style = StyleBoxFlat.new()
		pressed_style.bg_color = pressed_color
		pressed_style.set_border_width_all(1)
		pressed_style.border_color = border_color
		pressed_style.set_corner_radius_all(3)
		
		# Focus state
		var focus_style = StyleBoxFlat.new()
		focus_style.bg_color = bg_color
		focus_style.set_border_width_all(2)
		focus_style.border_color = SELECTION_COLOR
		focus_style.set_corner_radius_all(3)
		
		# Apply styles
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", pressed_style)
		button.add_theme_stylebox_override("focus", focus_style)
		
		# Text color
		button.add_theme_color_override("font_color", text_color)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		
		# Change cursor to pointing hand for all buttons
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func style_tables():
	# Style the market and inventory lists
	style_list("MainContainer/BottomSection/MarketContainer/MarketList")
	style_list("MainContainer/BottomSection/InventoryContainer/InventoryList")

func style_list(node_path):
	var list = get_node_or_null(node_path)
	
	# Check if the node exists before styling it
	if not list:
		push_warning("Could not find node: " + node_path)
		return
	
	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = DARKER_BG_COLOR
	bg_style.set_border_width_all(1)
	bg_style.border_color = BORDER_COLOR
	
	# Selected item style
	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = SELECTION_COLOR
	selected_style.set_border_width_all(1)
	selected_style.border_color = BORDER_COLOR
	
	# Apply styles
	list.add_theme_stylebox_override("panel", bg_style)
	list.add_theme_stylebox_override("selected", selected_style)
	list.add_theme_color_override("font_color", TEXT_COLOR)
	list.add_theme_color_override("font_selected_color", Color.WHITE)
	
func style_progress_bars():
	# Style health bar
	var health_bar = get_node_or_null("MainContainer/TopSection/StatsContainer/HealthContainer/HealthRow/HealthBar")
	if not health_bar:
		push_warning("Could not find HealthBar")
		return
		
	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = DARKER_BG_COLOR
	bg_style.set_border_width_all(1)
	bg_style.border_color = BORDER_COLOR
	
	# Fill style
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = HEALTH_COLOR
	fill_style.set_border_width_all(0)
	
	# Apply styles
	health_bar.add_theme_stylebox_override("background", bg_style)
	health_bar.add_theme_stylebox_override("fill", fill_style)
