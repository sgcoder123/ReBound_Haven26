extends CharacterBody2D

signal shattered

@export var is_player := true
@export var speed := 450.0
@export var ai_speed := 650.0
@export var max_hits := 5
@export var top_bound := 60.0
@export var bottom_bound := 600.0

var ball: Node2D
var hits := 0
var ai_target_y := 0.0
var ai_reaction_timer := 0.0
var half_height := 60.0
var base_scale := Vector2.ONE
var base_size := Vector2.ONE

func _ready() -> void:
	var shape = $CollisionShape2D.shape
	if shape is RectangleShape2D:
		half_height = shape.size.y / 2.0
	$Visual.stop()
	$Visual.frame = 0
	base_scale = $Visual.scale
	base_size = $Visual.sprite_frames.get_frame_texture("default", 0).get_size()
	$Visual.stop()
	_show_stage(0)

func _physics_process(delta: float) -> void:
	var dir := 0.0
	if is_player:
		dir = Input.get_axis("ui_up", "ui_down")
	elif ball:
		ai_reaction_timer -= delta
		if ai_reaction_timer <= 0.0:
			ai_target_y = ball.global_position.y
			ai_reaction_timer = 0.20
		var diff := ai_target_y - global_position.y
		if absf(diff) > 22.0:
			dir = signf(diff)
	velocity = Vector2(0.0, dir * (speed if is_player else ai_speed))
	move_and_slide()
	position.y = clampf(position.y, top_bound + half_height, bottom_bound - half_height)

func register_hit() -> void:
	hits += 1
	print("hit ", hits)
	if hits >= max_hits:
		shatter()
		return
	if hits % 1 == 0:
		var count: int = $Visual.sprite_frames.get_frame_count("default")
		var stage := mini(floori(hits / 1.0), count - 1)
		_show_stage(stage)
		print("stage ", stage, " of ", count, " frames")

func shatter() -> void:
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	visible = false
	shattered.emit()

func _show_stage(stage: int) -> void:
	var tex: Texture2D = $Visual.sprite_frames.get_frame_texture("default", stage)
	$Visual.frame = stage
	$Visual.scale = base_scale * (base_size / tex.get_size())
