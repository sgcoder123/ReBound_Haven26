extends Node

const TITLE_IMAGE := "res://title.png"   # your title art; skipped if the file isn't found
const TITLE_TEXT := "RE:BOUND"

var start_button: Button
var starting := false

func _ready() -> void:
	GameManager.set_saturation(1.0)   # full color on the title; use 0.0 for black-and-white

	start_button = find_child("StartButton", true, false) as Button
	var quit_button := find_child("QuitButton", true, false) as Button
	if start_button == null:
		start_button = _build_ui()
	else:
		print("Using the existing StartButton")

	start_button.pressed.connect(_on_start_pressed)
	if quit_button:
		quit_button.pressed.connect(func(): get_tree().quit())
	start_button.grab_focus()         # so Enter / Space works

# Builds a simple title screen when the scene has no buttons of its own
func _build_ui() -> Button:
	print("No StartButton found, building the title screen in code")
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.04, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	if ResourceLoader.exists(TITLE_IMAGE):
		var pic := TextureRect.new()
		pic.texture = load(TITLE_IMAGE)
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(pic)
	else:
		var title := Label.new()
		title.text = TITLE_TEXT
		title.set_anchors_preset(Control.PRESET_FULL_RECT)
		title.offset_top = -120
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 96)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(title)

	var button := Button.new()
	button.name = "StartButton"
	button.text = "Start"
	button.custom_minimum_size = Vector2(240, 60)
	button.add_theme_font_size_override("font_size", 32)
	button.set_anchors_preset(Control.PRESET_CENTER)
	button.position = Vector2(576 - 120, 440)
	layer.add_child(button)
	return button

func _on_start_pressed() -> void:
	if starting:
		return                        # ignore double clicks
	starting = true
	start_button.disabled = true
	var music := get_node_or_null("Music") as AudioStreamPlayer
	if music:
		create_tween().tween_property(music, "volume_db", -40.0, 0.8)
	GameManager.start_game()
