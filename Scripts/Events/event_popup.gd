extends Control

# This is a script for a scene that will display event popups
# Create a new scene with this script attached to the root node

var popup
var title_label
var description_label
var effects_label
var ok_button
var animation_player

func _ready():
	# Create main popup panel
	popup = PopupPanel.new()
	popup.size = Vector2(400, 300)
	add_child(popup)
	
	# Create container for content
	var container = VBoxContainer.new()
	container.size_flags_horizontal = SIZE_EXPAND_FILL
	container.size_flags_vertical = SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(400, 300)
	popup.add_child(container)
	
	# Add some padding
	container.add_theme_constant_override("separation", 10)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.size_flags_vertical = SIZE_EXPAND_FILL
	container.add_child(margin)
	
	# Create content inside margin
	var content = VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_child(content)
	
	# Event Title
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("#FFDD00"))
	content.add_child(title_label)
	
	# Separator
	var separator = HSeparator.new()
	content.add_child(separator)
	
	# Event Description
	description_label = Label.new()
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 16)
	content.add_child(description_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	content.add_child(spacer)
	
	# Effects
	effects_label = Label.new()
	effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effects_label.add_theme_font_size_override("font_size", 14)
	effects_label.add_theme_color_override("font_color", Color("#88FF88"))
	content.add_child(effects_label)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(spacer2)
	
	# OK Button
	ok_button = Button.new()
	ok_button.text = "OK"
	ok_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok_button.custom_minimum_size = Vector2(120, 40)
	content.add_child(ok_button)
	
	# Connect button
	ok_button.pressed.connect(func(): popup.hide())
	
	# Create animation player for effects
	animation_player = AnimationPlayer.new()
	add_child(animation_player)
	
	# Create fade-in animation
	var animation = Animation.new()
	var track_idx = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_idx, ".:modulate")
	animation.track_insert_key(track_idx, 0.0, Color(1, 1, 1, 0))
	animation.track_insert_key(track_idx, 0.5, Color(1, 1, 1, 1))
	animation_player.add_animation("fade_in", animation)
	
	# Create shake animation for more dramatic events
	var shake_animation = Animation.new()
	shake_animation.length = 0.5
	var shake_track = shake_animation.add_track(Animation.TYPE_VALUE)
	shake_animation.track_set_path(shake_track, ".:position")
	shake_animation.track_insert_key(shake_track, 0.0, Vector2.ZERO)
	shake_animation.track_insert_key(shake_track, 0.1, Vector2(-5, 5))
	shake_animation.track_insert_key(shake_track, 0.2, Vector2(5, -5))
	shake_animation.track_insert_key(shake_track, 0.3, Vector2(-3, -3))
	shake_animation.track_insert_key(shake_track, 0.4, Vector2(3, 3))
	shake_animation.track_insert_key(shake_track, 0.5, Vector2.ZERO)
	animation_player.add_animation("shake", shake_animation)

# Show event popup with data
func show_event(event_data):
	title_label.text = event_data.title
	description_label.text = event_data.description
	
	# Format effects text
	var effects_text = "Effects:\n"
	
	for effect_type in event_data.effects:
		var effect_value = event_data.effects[effect_type]
		
		match effect_type:
			"cash":
				if effect_value > 0:
					effects_text += "Cash: +$" + str(abs(effect_value)) + "\n"
				else:
					effects_text += "Cash: -$" + str(abs(effect_value)) + "\n"
			"health":
				if effect_value > 0:
					effects_text += "Health: +" + str(abs(effect_value)) + "\n"
				else:
					effects_text += "Health: -" + str(abs(effect_value)) + "\n"
			"heat":
				if effect_value > 0:
					effects_text += "Police Attention: Increased\n"
				else:
					effects_text += "Police Attention: Decreased\n"
			"reputation":
				if effect_value > 0:
					effects_text += "Reputation: Improved\n"
				else:
					effects_text += "Reputation: Damaged\n"
			"inventory":
				if effect_value < 0:
					effects_text += "Inventory: Lost " + str(int(abs(effect_value) * 100)) + "%\n"
			"inventory_add":
				effects_text += "Inventory: Added drugs\n"
			"market_modifier":
				if typeof(effect_value) == TYPE_DICTIONARY:
					effects_text += effect_value.drug + " prices " + ("increased" if effect_value.value > 1 else "decreased") + "\n"
				else:
					effects_text += "Drug prices " + ("increased" if effect_value > 1 else "decreased") + "\n"
			"connection":
				if effect_value > 0:
					effects_text += "Connections: Improved\n"
				else:
					effects_text += "Connections: Lost\n"
			"time":
				effects_text += "Time passed: " + str(effect_value) + " hours\n"
	
	effects_label.text = effects_text
	
	# Reset position and modulate
	popup.modulate = Color(1, 1, 1, 0)
	popup.position = Vector2.ZERO
	
	# Show popup
	popup.popup_centered()
	
	# Play animation
	animation_player.play("fade_in")
	
	# For more dramatic events (like getting arrested or mugged),
	# play a shake animation as well
	if "health" in event_data.effects and event_data.effects.health < -10:
		# Wait for fade-in to complete
		await animation_player.animation_finished
		animation_player.play("shake")
