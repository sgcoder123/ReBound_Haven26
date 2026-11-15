extends CharacterBody2D

signal hit_paddle(paddle)

@export var start_speed := 600.0
@export var speed_gain := 25.0
@export var max_speed := 900.0
@export var top_bound := 60.0      
@export var bottom_bound := 600.0 

var speed := 0.0
var radius := 8.0

func _ready() -> void:
	var shape = $CollisionShape2D.shape
	if shape is CircleShape2D:
		radius = shape.radius

func launch(dir_x := 1.0) -> void:
	speed = start_speed
	var angle := randf_range(-0.5, 0.5)
	velocity = Vector2(signf(dir_x), angle).normalized() * speed

func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var c := move_and_collide(velocity * delta)
	if c:
		var other := c.get_collider()
		if other.is_in_group("paddle"):
			speed = minf(speed + speed_gain, max_speed)
			var offset := clampf((global_position.y - other.global_position.y) / other.half_height, -1.0, 1.0)
			var dir_x := -signf(velocity.x)
			velocity = Vector2(dir_x, offset * 0.8).normalized() * speed
			hit_paddle.emit(other)
		else:
			velocity = velocity.bounce(c.get_normal())

	# Bounce off the top and bottom of the arena
	if global_position.y - radius < top_bound and velocity.y < 0.0:
		velocity.y = -velocity.y
		global_position.y = top_bound + radius
	elif global_position.y + radius > bottom_bound and velocity.y > 0.0:
		velocity.y = -velocity.y
		global_position.y = bottom_bound - radius
