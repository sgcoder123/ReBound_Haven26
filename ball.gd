extends CharacterBody2D

signal hit_paddle(paddle)

@export var start_speed := 500.0
@export var speed_gain := 25.0
@export var max_speed := 900.0
@export var top_bound := 60.0
@export var bottom_bound := 600.0
@export var bounce_bottom := true     # Pong: true. Breakout: false.
@export var left_bound := 40.0        # safety edges (match your walls' inner faces)
@export var right_bound := 1112.0
@export var enforce_side_bounds := true   # Breakout: true. Pong: false (ball exits to score).

var speed := 0.0
var radius := 8.0
var hit_cooldown := 0.0

func _ready() -> void:
	# The ball lives on layer 2 and collides with layer 1 (paddles, walls, bricks)
	collision_layer = 2
	collision_mask = 1
	var col := find_child("CollisionShape2D", true, false) as CollisionShape2D
	if col and col.shape is CircleShape2D:
		radius = col.shape.radius

func launch(dir_x := 1.0) -> void:
	speed = start_speed
	var angle := randf_range(-0.5, 0.5)
	velocity = Vector2(signf(dir_x), angle).normalized() * speed

func launch_up() -> void:
	speed = start_speed
	var angle := randf_range(-0.4, 0.4)
	velocity = Vector2(angle, -1.0).normalized() * speed

func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	hit_cooldown = maxf(hit_cooldown - delta, 0.0)

	# Up to 3 collisions per frame, using the leftover motion after each bounce
	var motion := velocity * delta
	for i in 3:
		var c := move_and_collide(motion)
		if c == null:
			break
		var other := c.get_collider()
		if other.is_in_group("paddle"):
			_bounce_off_paddle(other)
			break
		velocity = velocity.bounce(c.get_normal())
		if other.has_method("hit"):
			other.hit()
		motion = c.get_remainder().bounce(c.get_normal())

	_enforce_bounds()

func _bounce_off_paddle(other: Node) -> void:
	if hit_cooldown > 0.0:
		return
	hit_cooldown = 0.15
	speed = minf(speed + speed_gain, max_speed)
	if other.get("is_horizontal"):
		var offset := clampf((global_position.x - other.global_position.x) / other.half_width, -1.0, 1.0)
		velocity = Vector2(offset * 0.8, -absf(velocity.y)).normalized() * speed
	else:
		var offset := clampf((global_position.y - other.global_position.y) / other.half_height, -1.0, 1.0)
		velocity = Vector2(-signf(velocity.x), offset * 0.8).normalized() * speed
	hit_paddle.emit(other)

func _enforce_bounds() -> void:
	# Top / bottom
	if global_position.y - radius < top_bound and velocity.y < 0.0:
		velocity.y = -velocity.y
		global_position.y = top_bound + radius
	elif bounce_bottom and global_position.y + radius > bottom_bound and velocity.y > 0.0:
		velocity.y = -velocity.y
		global_position.y = bottom_bound - radius
	# Left / right
	if enforce_side_bounds:
		if global_position.x - radius < left_bound and velocity.x < 0.0:
			velocity.x = -velocity.x
			global_position.x = left_bound + radius
		elif global_position.x + radius > right_bound and velocity.x > 0.0:
			velocity.x = -velocity.x
			global_position.x = right_bound - radius
