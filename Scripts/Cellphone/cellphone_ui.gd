# Fixed cellphone_ui.gd - ensures buttons on phone work while preventing outside clicks from closing it
extends Control

signal contact_selected(contact_name)

var is_phone_active = false
var click_blocker = null

func _ready():
	# Start with phone hidden
	hide()
	if has_node("Popup"):
		$Popup.hide()
	
	# CRITICAL CHANGE: Don't make popup exclusive - this blocks our own buttons
	if has_node("Popup"):
		$Popup.exclusive = false
		
		# Connect the close button
		if has_node("Popup/TextureRect/Control/Button"):
			$Popup/TextureRect/Control/Button.pressed.connect(func(): _on_close_button_pressed())
		
		# Connect all the contact buttons
		var vbox = $Popup/TextureRect/Control/VBoxContainer
		if vbox:
			if vbox.has_node("LoanSharkButton"):
				vbox.get_node("LoanSharkButton").pressed.connect(
					func(): emit_signal("contact_selected", "Loan Shark"))
			
			if vbox.has_node("GunDealerButton"):
				vbox.get_node("GunDealerButton").pressed.connect(
					func(): emit_signal("contact_selected", "Gun Dealer"))
			
			if vbox.has_node("MarketButton"):
				vbox.get_node("MarketButton").pressed.connect(
					func(): emit_signal("contact_selected", "Market"))
				
			if vbox.has_node("BankButton"):
				vbox.get_node("BankButton").pressed.connect(
					func(): emit_signal("contact_selected", "Soulioli Banking"))
			
			# NEW: Add game management buttons
			if vbox.has_node("SaveGameButton"):
				vbox.get_node("SaveGameButton").pressed.connect(
					func(): emit_signal("contact_selected", "Save Game"))
					
			if vbox.has_node("LoadGameButton"):
				vbox.get_node("LoadGameButton").pressed.connect(
					func(): emit_signal("contact_selected", "Load Game"))
					
			if vbox.has_node("NewGameButton"):
				vbox.get_node("NewGameButton").pressed.connect(
					func(): emit_signal("contact_selected", "New Game"))
	
	# Create a click blocker for our custom modal behavior
	create_click_blocker()

# Create a panel that will block clicks outside the phone
func create_click_blocker():
	# Remove any existing click blocker first
	if has_node("ClickBlocker"):
		get_node("ClickBlocker").queue_free()
		await get_tree().process_frame
	
	# Create a new click blocker
	click_blocker = Panel.new()
	click_blocker.name = "ClickBlocker"
	
	# Make sure the panel covers the entire screen and catches all input
	click_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_blocker.mouse_filter = Control.MOUSE_FILTER_STOP # This ensures it catches all mouse events
	
	# Style it as semi-transparent
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)  # Semi-transparent black
	click_blocker.add_theme_stylebox_override("panel", style)
	
	# Hide it by default
	click_blocker.visible = false
	
	# Add it to the scene before the popup
	add_child(click_blocker)
	move_child(click_blocker, 0)  # Make sure it's behind the popup
	
	# Connect to input events from the click blocker
	click_blocker.gui_input.connect(_on_click_blocker_input)

# Handle clicks on the blocker with visual feedback
func _on_click_blocker_input(event):
	if event is InputEventMouseButton and event.pressed:
		# Visual feedback to indicate they need to use the close button
		if has_node("Popup/TextureRect/Control/Button"):
			var close_button = $Popup/TextureRect/Control/Button
			var tween = create_tween()
			tween.tween_property(close_button, "modulate", Color(1, 0.5, 0.5), 0.2)
			tween.tween_property(close_button, "modulate", Color(1, 1, 1), 0.2)
		
		# Phone shake animation
		if has_node("Popup/TextureRect"):
			var phone_rect = $Popup/TextureRect
			var orig_pos = phone_rect.position
			var shake_tween = create_tween()
			shake_tween.tween_property(phone_rect, "position", orig_pos + Vector2(5, 0), 0.05)
			shake_tween.tween_property(phone_rect, "position", orig_pos, 0.05)

# Close button handler - the ONLY way to close the phone
func _on_close_button_pressed():
	print("Close button pressed")
	
	# First, mark the phone as inactive
	is_phone_active = false
	
	# Then hide everything
	if has_node("Popup"):
		$Popup.hide()
	if has_node("ClickBlocker"):
		$ClickBlocker.visible = false
	
	# Finally hide the entire control
	hide()

# Show the phone with all necessary setup
func show_phone():
	# First, show the main control (this node)
	show()
	
	# Activate the click blocker
	if has_node("ClickBlocker"):
		$ClickBlocker.visible = true
	
	# Mark as active
	is_phone_active = true
	
	# Ensure all UI elements are visible
	if has_node("Popup/TextureRect"):
		$Popup/TextureRect.visible = true
		$Popup/TextureRect.modulate = Color(1, 1, 1, 1)
	
	if has_node("Popup/TextureRect/Control/VBoxContainer"):
		var vbox = $Popup/TextureRect/Control/VBoxContainer
		for child in vbox.get_children():
			child.visible = true
	
	# Show the popup (NOT exclusive)
	if has_node("Popup"):
		$Popup.exclusive = false  # Ensure it's not exclusive
		$Popup.popup_centered()

# Update message in the phone
func update_message(text):
	# Get the message label
	var message_label = null
	if has_node("Popup/TextureRect/Control/VBoxContainer"):
		var vbox = $Popup/TextureRect/Control/VBoxContainer
		message_label = vbox.get_node_or_null("MessageLabel")
	
	# If message label doesn't exist, create it
	if not message_label:
		message_label = Label.new()
		message_label.name = "MessageLabel"
		message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message_label.size_flags_horizontal = SIZE_EXPAND_FILL
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		if has_node("Popup/TextureRect/Control/VBoxContainer"):
			var vbox = $Popup/TextureRect/Control/VBoxContainer
			vbox.add_child(message_label)
			vbox.move_child(message_label, 1)  # Move to just after the title
	
	# Set message text
	if message_label:
		message_label.text = text
