extends Control

@onready var hud: Control = $HUD
@onready var on_screen_controls: Control = %OnScreenControls
@onready var screen_container: SGUIScreenContainer = %ScreenContainer
@onready var coin_label: Label = %CoinLabel
@onready var main_menu: Control = %MainMenu
@onready var credits: Control = %Credits
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

signal play_pressed()
signal quit_pressed()
signal pause_pressed()
signal resume_pressed()
signal return_to_menu_pressed()
signal retry_pressed()

signal xr_mode_changed(p_index: int)


func _ready() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		quit_button.hide()
	if not OS.has_feature("androidxr"):
		settings_button.hide()
	reset_ui()


func _input(p_event: InputEvent) -> void:
	if p_event.is_action_pressed("pause"):
		pause_pressed.emit()


func set_hud_visibility(p_visible: bool) -> void:
	hud.visible = p_visible


func set_on_screen_controls_visibility(p_visible: bool) -> void:
	on_screen_controls.visible = p_visible


func show_menu(p_menu_name: String) -> void:
	screen_container.visible = true
	screen_container.show_screen(p_menu_name)

	# Set focus to the first button in the menu.
	var screen: Control = screen_container.get_current_screen_control()
	if screen:
		var buttons = screen.find_children("*", "Button")
		if buttons.size() > 0:
			buttons[0].grab_focus()


func hide_menu() -> void:
	screen_container.visible = false


func set_coin_count(p_count: int) -> void:
	coin_label.text = "Coins: " + str(p_count)


func reset_ui() -> void:
	set_coin_count(0)
	set_hud_visibility(false)
	show_menu("MainMenu")


func _on_rich_text_label_meta_clicked(p_meta: Variant) -> void:
	OS.shell_open(p_meta)


func _on_play_button_pressed() -> void:
	play_pressed.emit()


func _on_settings_button_pressed() -> void:
	show_menu("SettingsMenu")


func _on_credits_button_pressed() -> void:
	show_menu("Credits")


func _on_quit_button_pressed() -> void:
	quit_pressed.emit()


func _on_back_from_settings_button_pressed() -> void:
	show_menu("MainMenu")


func _on_back_from_credits_button_pressed() -> void:
	show_menu("MainMenu")


func _on_pause_button_pressed() -> void:
	pause_pressed.emit()


func _on_resume_button_pressed() -> void:
	resume_pressed.emit()


func _on_return_to_menu_button_pressed() -> void:
	return_to_menu_pressed.emit()


func _on_retry_button_pressed() -> void:
	retry_pressed.emit()


func _on_xr_mode_field_item_selected(p_index: int) -> void:
	xr_mode_changed.emit(p_index)


func _send_action(p_action: StringName, p_pressed: bool) -> void:
	var action_event = InputEventAction.new()
	action_event.action = p_action
	action_event.pressed = p_pressed
	Input.parse_input_event(action_event)


func _on_left_button_button_down() -> void:
	_send_action("move_left", true)


func _on_left_button_button_up() -> void:
	_send_action("move_left", false)


func _on_right_button_button_down() -> void:
	_send_action("move_right", true)


func _on_right_button_button_up() -> void:
	_send_action("move_right", false)


func _on_jump_button_button_down() -> void:
	_send_action("jump", true)


func _on_jump_button_button_up() -> void:
	_send_action("jump", false)
