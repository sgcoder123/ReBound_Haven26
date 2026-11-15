extends CharacterBody2D

@export var speed := 600.0
@export var left_bound := 40.0
@export var right_bound := 1112.0

var is_horizontal := true   # the ball reads this to bounce correctly
var half_width := 60.0

func _ready() -> void:
	var shape = $CollisionShape2D.shape
	if shape is RectangleShape2D:
		half_width = shape.size.x / 2.0

func _physics_process(_delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	velocity = Vector2(dir * speed, 0.0)
	move_and_slide()
	position.x = clampf(position.x, left_bound + half_width, right_bound - half_width)

func register_hit() -> void:
	pass   # add crack frames here later if you want
