extends Node

var main: Node = null
var chapter_index := 0

var chapters := [
	"res://scenes/chapters/chapter1_pong.tscn",
	"res://scenes/chapters/chapter2_breakout.tscn",
	"res://scenes/chapters/chapter3_transformation.tscn",
	"res://scenes/chapters/chapter4_platformer.tscn",
	"res://scenes/chapters/chapter5_trophy.tscn",
	"res://scenes/chapters/chapter6_fall.tscn",
	"res://scenes/chapters/chapter7_pong.tscn",
]

func next_chapter() -> void:
	chapter_index += 1
	if chapter_index < chapters.size():
		main.load_chapter(chapters[chapter_index])

func go_to_chapter(index: int) -> void:
	chapter_index = index
	main.load_chapter(chapters[index])

var saturation := 0.0
var _sat_tween: Tween

func _color_fade() -> ColorRect:
	return main.get_node("Overlay/ColorFade")

func set_saturation(value: float) -> void:
	saturation = clampf(value, 0.0, 1.0)
	_color_fade().material.set_shader_parameter("saturation", saturation)

func fade_saturation(target: float, duration := 1.0) -> void:
	if _sat_tween:
		_sat_tween.kill()
	_sat_tween = create_tween()
	_sat_tween.tween_method(set_saturation, saturation, target, duration)
