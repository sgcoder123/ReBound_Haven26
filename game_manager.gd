extends Node

# Turn the black-and-white / color-rising effect on or off
const SATURATION_EFFECT := false

var fx: Node
var transition_image: Texture2D

func _ready() -> void:
	fx = preload("res://rebound_fx.gd").new()
	fx.name = "ReboundFX"
	add_child(fx)

var main: Node = null
var chapter_index := 0
var final_pong := false

# The title screen is NOT in the chapters list
var title_scene := "res://title_screen.tscn"

var chapters := [
	"res://chapter1_pong.tscn",
	"res://chapter2_breakout.tscn",
	"res://chapter3_platformer.tscn",
	# add the others as you build them
]

# Caption shown on black when ENTERING each chapter (same order as chapters).
# Leave "" for no caption. Edit these to match your story.
var captions := [
	"",                                                # Chapter 1 (title -> game)
	"I thought that was the end.",                     # entering Chapter 2
	"Same problem. Different me.",                     # entering Chapter 3
	"",                                                # entering Chapter 4
	"",                                                # entering Chapter 5
	"After everything... I'm back where I started.",   # entering Chapter 6
	"",                                                # entering Chapter 7
]

var saturation := 1.0
var _sat_tween: Tween

func _caption_for(index: int) -> String:
	if index >= 0 and index < captions.size():
		return captions[index]
	return ""

# Title screen -> Chapter 1, with a slower fade than the in-game transitions
func start_game() -> void:
	print("start_game called, main = ", main)
	chapter_index = 0
	final_pong = false
	if main:
		main.change_chapter(chapters[0], _caption_for(0), 1.0)
	else:
		print("main is null (did you press F6?), using plain scene change")
		get_tree().change_scene_to_file(chapters[0])

func next_chapter() -> void:
	chapter_index += 1
	print("next_chapter called, index = ", chapter_index, " of ", chapters.size())
	if chapter_index >= chapters.size():
		print("No more chapters in the list")
		return
	if chapter_index == 1 and main:
		fx.stop_shake()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			transition_image = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
		await main.reveal_breakout(chapters[chapter_index])
		return
	if chapter_index == 2 and main:
		fx.stop_shake()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			transition_image = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
		await main.reveal_depth(chapters[chapter_index])
		return
	if main:
		main.change_chapter(chapters[chapter_index], _caption_for(chapter_index))
	else:
		print("main is null (did you press F6?), using plain scene change")
		get_tree().change_scene_to_file(chapters[chapter_index])

func go_to_chapter(index: int) -> void:
	chapter_index = index
	if main:
		main.change_chapter(chapters[index], _caption_for(index))
	else:
		get_tree().change_scene_to_file(chapters[index])

func set_saturation(value: float) -> void:
	saturation = clampf(value, 0.0, 1.0)
	if main == null:
		return
	var rect := main.get_node_or_null("Overlay/ColorFade") as ColorRect
	if rect == null:
		return
	if not SATURATION_EFFECT:
		rect.visible = false          # effect disabled: the game stays in full color
		return
	rect.visible = saturation < 0.999
	if rect.material:
		rect.material.set_shader_parameter("saturation", saturation)

func fade_saturation(target: float, duration := 1.0) -> void:
	if not SATURATION_EFFECT:
		saturation = target
		return
	if _sat_tween:
		_sat_tween.kill()
	_sat_tween = create_tween()
	_sat_tween.tween_method(set_saturation, saturation, target, duration)
