extends Node

# Turn the black-and-white / color-rising effect on or off
const SATURATION_EFFECT := false

var fx: Node = null
var transition_image: Texture2D = null

var main: Node = null
var chapter_index: int = 0
var final_pong: bool = false

# The title screen is NOT in the chapters list
var title_scene := "res://title_screen.tscn"

var chapters: Array[String] = [
	"res://chapter1_pong.tscn",
	"res://chapter2_breakout.tscn",
	"res://chapter3_platformer.tscn",
]

# Captions shown when entering each chapter
var captions: Array[String] = [
	"",                          # Chapter 1
	"I thought that was the end.", # Chapter 2
	"Same problem. Different me.", # Chapter 3
]

var saturation: float = 1.0
var _sat_tween: Tween = null


func _ready() -> void:
	var fx_script = load("res://rebound_fx.gd")

	if fx_script:
		fx = fx_script.new()
		fx.name = "ReboundFX"
		add_child(fx)
	else:
		push_error("Could not load rebound_fx.gd")


func _caption_for(index: int) -> String:
	if index >= 0 and index < captions.size():
		return captions[index]

	return ""


# Title screen -> Chapter 1
func start_game() -> void:
	print("start_game called, main = ", main)

	chapter_index = 0
	final_pong = false

	if chapters.is_empty():
		push_error("No chapters have been added to the chapters array.")
		return

	if main != null and main.has_method("change_chapter"):
		main.change_chapter(
			chapters[0],
			_caption_for(0),
			1.0
		)
	else:
		print("main is null or missing change_chapter(). Using plain scene change.")
		get_tree().change_scene_to_file(chapters[0])


func next_chapter() -> void:
	chapter_index += 1

	print(
		"next_chapter called, index = ",
		chapter_index,
		" of ",
		chapters.size()
	)

	if chapter_index >= chapters.size():
		print("No more chapters in the list.")
		return

	# Special transition into Chapter 2
	if chapter_index == 1 and main != null:
		if fx != null and fx.has_method("stop_shake"):
			fx.stop_shake()

		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw

			var viewport_image = get_viewport().get_texture().get_image()
			transition_image = ImageTexture.create_from_image(viewport_image)

		if main.has_method("reveal_breakout"):
			await main.reveal_breakout(chapters[chapter_index])
			return

	# Special transition into Chapter 3
	if chapter_index == 2 and main != null:
		if fx != null and fx.has_method("stop_shake"):
			fx.stop_shake()

		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw

			var viewport_image = get_viewport().get_texture().get_image()
			transition_image = ImageTexture.create_from_image(viewport_image)

		if main.has_method("reveal_depth"):
			await main.reveal_depth(chapters[chapter_index])
			return

	# Normal chapter transition
	if main != null and main.has_method("change_chapter"):
		main.change_chapter(
			chapters[chapter_index],
			_caption_for(chapter_index)
		)
	else:
		print("main is null. Using plain scene change.")
		get_tree().change_scene_to_file(chapters[chapter_index])


func go_to_chapter(index: int) -> void:
	if index < 0 or index >= chapters.size():
		push_error("Invalid chapter index: " + str(index))
		return

	chapter_index = index

	if main != null and main.has_method("change_chapter"):
		main.change_chapter(
			chapters[index],
			_caption_for(index)
		)
	else:
		get_tree().change_scene_to_file(chapters[index])


func set_saturation(value: float) -> void:
	saturation = clampf(value, 0.0, 1.0)

	# Don't try to access main until it exists
	if main == null:
		return

	var rect := main.get_node_or_null(
		"Overlay/ColorFade"
	) as ColorRect

	if rect == null:
		return

	# Effect disabled — keep everything in full color
	if not SATURATION_EFFECT:
		rect.visible = false
		return

	rect.visible = saturation < 0.999

	if rect.material != null:
		rect.material.set_shader_parameter(
			"saturation",
			saturation
		)


func fade_saturation(target: float, duration: float = 1.0) -> void:
	target = clampf(target, 0.0, 1.0)

	if not SATURATION_EFFECT:
		saturation = target
		return

	if _sat_tween != null:
		_sat_tween.kill()

	_sat_tween = create_tween()
	_sat_tween.tween_method(
		set_saturation,
		saturation,
		target,
		duration
	)
