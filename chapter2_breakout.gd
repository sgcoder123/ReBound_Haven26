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
var assembling := true
var total_bricks := 0
var bricks_left := 0
var ended := false

func _ready() -> void:
	_gm().fx.play_music()
	ball.hit_paddle.connect(_paddle_audio)
	_gm().set_saturation(0.0)

	ball.bounce_bottom = false          # the bottom is a miss, not a bounce
	ball.enforce_side_bounds = true     # side walls still contain it

	bricks_root = get_node_or_null("Bricks") as Node2D
	if bricks_root == null:
		bricks_root = Node2D.new()
		bricks_root.name = "Bricks"
		add_child(bricks_root)

	_adopt_placed_bricks()
	if bricks_left == 0:
		_spawn_bricks()
	total_bricks = bricks_left

	_intro()

# ---------- Intro: the broken pieces fall and reconnect ----------

func _intro() -> void:
	paddle.visible = false
	paddle.set_physics_process(false)
	ball.visible = false
	ball.set_physics_process(false)

	await get_tree().create_timer(0.5).timeout
	await _assemble_paddle()

	paddle.visible = true
	paddle.set_physics_process(true)
	ball.visible = true
	ball.set_physics_process(true)
	assembling = false
	_reset_ball()

func _find_sprite(node: Node) -> Node2D:
	for c in node.get_children():
		if c is AnimatedSprite2D or c is Sprite2D:
			return c
	return null

func _assemble_paddle() -> void:
	var target := paddle.global_position
	var vis := _find_sprite(paddle)
	var tex: Texture2D = null
	var sc := Vector2.ONE
	if vis is AnimatedSprite2D:
		tex = vis.sprite_frames.get_frame_texture(vis.animation, 0)
		sc = vis.global_scale
	elif vis is Sprite2D:
		tex = vis.texture
		sc = vis.global_scale

	var w: float = float(paddle.get("half_width")) * 2.0   # fallback size
	var h := 20.0
	var halves: Array[Node2D] = []

	if tex:
		var sz := tex.get_size()
		w = sz.x * sc.x
		h = sz.y * sc.y
		var left_tex := AtlasTexture.new()
		left_tex.atlas = tex
		left_tex.region = Rect2(0, 0, sz.x / 2.0, sz.y)
		var right_tex := AtlasTexture.new()
		right_tex.atlas = tex
		right_tex.region = Rect2(sz.x / 2.0, 0, sz.x / 2.0, sz.y)
		for t in [left_tex, right_tex]:
			var s := Sprite2D.new()
			s.texture = t
			s.scale = sc
			halves.append(s)
	else:
		for i in 2:
			var p := Polygon2D.new()
			p.polygon = PackedVector2Array([
				Vector2(-w / 4.0, -h / 2.0), Vector2(w / 4.0, -h / 2.0),
				Vector2(w / 4.0, h / 2.0), Vector2(-w / 4.0, h / 2.0)])
			p.color = Color(0.9, 0.9, 0.9)
			halves.append(p)

	# Where each half ends up when the paddle is whole again
	var targets := [target + Vector2(-w / 4.0, 0), target + Vector2(w / 4.0, 0)]

	# Start above the screen, tilted, and fall to the floor
	for i in halves.size():
		var piece := halves[i]
		piece.z_index = 5
		piece.global_position = Vector2(randf_range(300.0, 850.0), -120.0)
		piece.rotation = randf_range(-1.5, 1.5)
		add_child(piece)
		var land := create_tween().set_parallel(true)
		land.tween_property(piece, "position:y", target.y + 30.0, 1.0) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		land.tween_property(piece, "rotation", randf_range(-0.4, 0.4), 1.0)

	await get_tree().create_timer(1.6).timeout   # they lie there for a moment

	# Reconnect
	var join: Tween
	for i in halves.size():
		join = create_tween().set_parallel(true)
		join.tween_property(halves[i], "global_position", targets[i], 1.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		join.tween_property(halves[i], "rotation", 0.0, 1.0)
	await join.finished
	await get_tree().create_timer(0.2).timeout

	_gm().fx.play_sfx("impact", -14.0, false)
	_gm().fx.shake(5.0, 0.18)
	for piece in halves:
		piece.queue_free()

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
	_add_brick(
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
	_gm().fx.play_sfx("brick", -16.0)
	_gm().fx.shake(2.0, 0.1)
	bricks_left -= 1
	var progress := 1.0 - float(bricks_left) / float(maxi(total_bricks, 1))
	_gm().fade_saturation(progress, 0.3)
	if bricks_left <= 0 and not ended:
		_on_all_bricks_broken()

func _on_all_bricks_broken() -> void:
	ended = true
	ball.set_physics_process(false)
	paddle.set_physics_process(false)
	_gm().fx.stop_shake()
	_gm().next_chapter()

# ---------- Ball ----------

func _reset_ball() -> void:
	launched = false
	ball.reset_to(paddle.global_position + Vector2(0, -40))
	await get_tree().create_timer(1.0).timeout
	if not ended:
		ball.launch_up()
		launched = true

func _physics_process(_delta: float) -> void:
	if ended or assembling:
		return
	if not launched:
		ball.global_position = paddle.global_position + Vector2(0, -40)
		return
	if ball.global_position.y - ball.radius > get_viewport_rect().size.y:
		_reset_ball()

func _paddle_audio(_paddle: Node) -> void:
	_gm().fx.play_sfx("hit", -15.0)

func _gm() -> Node:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null:
		manager = load("res://game_manager.gd").new()
		manager.name = "GameManager"
		get_tree().root.add_child(manager)
	return manager
