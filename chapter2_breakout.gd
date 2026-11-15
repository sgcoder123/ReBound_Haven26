extends Node2D

const BRICK_SCENE := preload("res://tile.tscn")

const BRICK_SCALE := 1.5     # matches the Scale 1.5 on your Brick instances
const GAP := 4.0
const GRID_TOP := 140.0
const ROWS := 5
const ARENA_LEFT := 40.0
const ARENA_RIGHT := 1112.0

@onready var paddle: CharacterBody2D = $BreakoutPaddle
@onready var ball: CharacterBody2D = $Ball

var bricks_root: Node2D
var launched := false
var total_bricks := 0
var bricks_left := 0
var ended := false

func _ready() -> void:
	GameManager.set_saturation(0.0)

	bricks_root = get_node_or_null("Bricks") as Node2D
	if bricks_root == null:
		bricks_root = Node2D.new()
		bricks_root.name = "Bricks"
		add_child(bricks_root)

	_adopt_placed_bricks()
	if bricks_left == 0:
		_spawn_bricks()
	total_bricks = bricks_left

	_reset_ball()

# ---------- Bricks ----------

# Bricks you placed by hand in the editor
func _adopt_placed_bricks() -> void:
	var candidates: Array[Node] = []
	candidates.append_array(get_children())
	candidates.append_array(bricks_root.get_children())
	for node in candidates:
		if node.has_signal("broken") and not node.broken.is_connected(_on_brick_broken):
			node.broken.connect(_on_brick_broken)
			bricks_left += 1

func _measure_brick() -> Vector2:
	var size := Vector2(64, 28)
	var b := BRICK_SCENE.instantiate()
	var col := b.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		size = col.shape.size
	b.free()
	return size * BRICK_SCALE

func _spawn_bricks() -> void:
	var size := _measure_brick()
	var usable := ARENA_RIGHT - ARENA_LEFT
	var columns := maxi(1, int((usable + GAP) / (size.x + GAP)))
	var grid_width := columns * size.x + (columns - 1) * GAP
	var start_x := ARENA_LEFT + (usable - grid_width) / 2.0 + size.x / 2.0

	for row in ROWS:
		for col in columns:
			_add_brick(Vector2(
				start_x + col * (size.x + GAP),
				GRID_TOP + row * (size.y + GAP)))

	# Reinforced final brick, centered above the grid
	var final_brick := _add_brick(
		Vector2((ARENA_LEFT + ARENA_RIGHT) / 2.0, GRID_TOP - size.y - GAP - 20.0),
		3, Color(1.0, 0.8, 0.4))

func _add_brick(pos: Vector2, hits := 1, color := Color.WHITE) -> Node:
	var brick := BRICK_SCENE.instantiate()
	brick.max_hits = hits       # set before add_child so the brick's _ready sees it
	brick.tint = color
	brick.scale = Vector2.ONE * BRICK_SCALE
	brick.position = pos
	brick.broken.connect(_on_brick_broken)
	bricks_root.add_child(brick)
	bricks_left += 1
	return brick

func _on_brick_broken(_brick) -> void:
	bricks_left -= 1
	var progress := 1.0 - float(bricks_left) / float(maxi(total_bricks, 1))
	GameManager.fade_saturation(progress, 0.3)
	if bricks_left <= 0 and not ended:
		_on_all_bricks_broken()

func _on_all_bricks_broken() -> void:
	ended = true
	ball.set_physics_process(false)
	paddle.set_physics_process(false)
	await get_tree().create_timer(1.5).timeout
	GameManager.next_chapter()

# ---------- Ball ----------

func _reset_ball() -> void:
	launched = false
	ball.reset_to(paddle.global_position + Vector2(0, -40))
	await get_tree().create_timer(1.0).timeout
	if not ended:
		ball.launch_up()
		launched = true

func _physics_process(_delta: float) -> void:
	if ended:
		return
	if not launched:
		ball.global_position = paddle.global_position + Vector2(0, -40)
		return
	if ball.global_position.y > 700.0:
		_reset_ball()
