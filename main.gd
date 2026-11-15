extends Node

# Turn the fade-to-black between chapters on or off
const FADE_TRANSITIONS := true

const COLOR_FADE_SHADER := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(gray), c.rgb, saturation), 1.0);
}
"""

@onready var chapter_container: Node = $ChapterContainer
@onready var fade_rect: ColorRect = get_node_or_null("Overlay/FadeRect")
@onready var caption_label: Label = get_node_or_null("Overlay/CaptionLabel")
@onready var color_fade: ColorRect = get_node_or_null("Overlay/ColorFade")
@onready var crt_filter: ColorRect = get_node_or_null("Overlay/CRTFilter")

var current_chapter: Node = null
var transitioning := false

func _ready() -> void:
	print("MAIN RUNNING, title = ", _gm().title_scene)
	_gm().main = self
	_setup_overlays()
	if fade_rect and FADE_TRANSITIONS:
		fade_rect.modulate.a = 1.0           # start black, then fade into the title
	var ok: bool = await load_chapter(_gm().title_scene)
	print("Title loaded: ", ok)
	await _fade_to(0.0, 0.8)                 # always fade back in

# Stops the overlay rectangles from covering the game as solid boxes
func _setup_overlays() -> void:
	if color_fade:
		color_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _gm().SATURATION_EFFECT:
			if color_fade.material == null:
				var shader := Shader.new()
				shader.code = COLOR_FADE_SHADER
				var mat := ShaderMaterial.new()
				mat.shader = shader
				color_fade.material = mat
			color_fade.material.set_shader_parameter("saturation", 1.0)
		else:
			color_fade.visible = false       # effect off: remove the overlay entirely
	if crt_filter:
		crt_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if crt_filter.material == null:
			crt_filter.visible = false       # no shader yet, so keep it hidden
	if fade_rect:
		fade_rect.color = Color.BLACK
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not FADE_TRANSITIONS:
			fade_rect.modulate.a = 0.0
	if caption_label:
		caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption_label.modulate.a = 0.0

func load_chapter(path: String) -> bool:
	if current_chapter:
		current_chapter.queue_free()
		await current_chapter.tree_exited
		current_chapter = null
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Chapter not found: " + path)
		return false
	current_chapter = scene.instantiate()
	chapter_container.add_child(current_chapter)
	print("Loaded chapter: ", path)
	return true

# Fades the black overlay to the given alpha (skipped when fades are off)
func _fade_to(alpha: float, time: float) -> void:
	if fade_rect == null or not FADE_TRANSITIONS:
		return
	var t := create_tween()
	t.tween_property(fade_rect, "modulate:a", alpha, time)
	await t.finished

# Fades to black, optionally shows a caption, swaps the chapter, fades back in
func change_chapter(path: String, caption := "", fade_time := 0.6) -> void:
	if transitioning:
		print("change_chapter ignored: already transitioning")
		return
	transitioning = true
	print("Changing to: ", path)
	await _fade_to(1.0, fade_time)
	if caption != "" and FADE_TRANSITIONS:
		await _show_caption(caption)
	var ok: bool = await load_chapter(path)
	if not ok:
		push_error("Transition failed, could not load: " + path)
	await _fade_to(0.0, fade_time)
	transitioning = false

# Types the caption out, holds, then fades it away
func _show_caption(text: String) -> void:
	if caption_label == null:
		return
	caption_label.text = text
	caption_label.visible_ratio = 0.0
	caption_label.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(caption_label, "visible_ratio", 1.0, text.length() * 0.05)
	t.tween_interval(1.2)
	t.tween_property(caption_label, "modulate:a", 0.0, 0.4)
	await t.finished

# Chapter 2 -> 3 bypasses the black fade and caption. The 3D scene owns the reveal.
func reveal_depth(path: String) -> void:
	if transitioning:
		return
	transitioning = true
	_gm().fx.stop_shake()
	if fade_rect:
		fade_rect.modulate.a = 0.0
	if caption_label:
		caption_label.modulate.a = 0.0
	await load_chapter(path)
	transitioning = false

func reveal_breakout(path: String) -> void:
	if transitioning:
		return
	transitioning = true
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var picture := TextureRect.new()
	picture.texture = _gm().transition_image
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(picture)
	picture.size = get_viewport().get_visible_rect().size
	_gm().transition_image = null
	if fade_rect:
		fade_rect.modulate.a = 0.0
	_gm().fx.buildup(1.4)
	await load_chapter(path)
	var sweep := create_tween().set_parallel(true)
	sweep.tween_property(picture, "position:y", -picture.size.y, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	sweep.tween_property(picture, "modulate:a", 0.0, 1.4)
	await sweep.finished
	layer.queue_free()
	_gm().fx.reveal()
	transitioning = false

func _gm() -> Node:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null:
		manager = load("res://game_manager.gd").new()
		manager.name = "GameManager"
		get_tree().root.add_child(manager)
	return manager
