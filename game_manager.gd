extends Node

var main: Node = null
var chapter_index := 0

var chapters := [
	"res://chapter1_pong.tscn",
	# add the others as you build them:
	# "res://chapter2_breakout.tscn",
]

var saturation := 0.0
var _sat_tween: Tween

func _color_fade() -> ColorRect:
	return main.get_node("Overlay/ColorFade")

func set_saturation(value: float) -> void:
	saturation = clampf(value, 0.0, 1.0)
	if main == null:
		return
	_color_fade().material.set_shader_parameter("saturation", saturation)

func fade_saturation(target: float, duration := 1.0) -> void:
	if _sat_tween:
		_sat_tween.kill()
	_sat_tween = create_tween()
	_sat_tween.tween_method(set_saturation, saturation, target, duration)

func next_chapter() -> void:
	chapter_index += 1
	if main and chapter_index < chapters.size():
		main.load_chapter(chapters[chapter_index])

func go_to_chapter(index: int) -> void:
	chapter_index = index
	if main:
		main.load_chapter(chapters[index])
