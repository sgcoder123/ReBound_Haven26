extends CharacterBody2D

signal shattered

@export var is_player := true
@export var speed := 450.0
@export var ai_speed := 500.0
@export var max_hits := 8
@export var top_bound := 60.0
@export var bottom_bound := 600.0

var ball: Node2D
var hits := 0
var half_height := 60.0

func _ready() -> void:
	var shape = $CollisionShape2D.shape
	if shape is RectangleShape2D:
		half_height = shape.size.y / 2.0

func _physics_process(_delta: float) -> void:
	var dir := 0.0
	if is_player:
		dir = Input.get_axis("ui_up", "ui_down")
	elif ball:
		var diff := ball.global_position.y - global_position.y
		if absf(diff) > 10.0:
			dir = signf(diff)
	velocity = Vector2(0.0, dir * (speed if is_player else ai_speed))
	move_and_slide()
	position.y = clampf(position.y, top_bound + half_height, bottom_bound - half_height)

func register_hit() -> void:
	hits += 1
	modulate = Color.WHITE.darkened(float(hits) / max_hits * 0.6)  # placeholder crack look
	if hits >= max_hits:
		shatter()

func shatter() -> void:
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	visible = false  # later: spawn ShatterEffect here
	shattered.emit()
