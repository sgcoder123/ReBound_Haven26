extends Node2D

const MAX_SATURATION := 0.35
const PER_HIT := 0.02

@onready var player: CharacterBody2D = $PlayerPaddle
@onready var opponent: CharacterBody2D = $OpponentPaddle
@onready var ball: CharacterBody2D = $Ball
@onready var player_label: Label = $PlayerScore
@onready var opponent_label: Label = $OpponentScore
@onready var wall_left: Area2D = $WallLeft
@onready var wall_right: Area2D = $WallRight

var center := Vector2.ZERO
var player_score := 0
var opponent_score := 0
var ended := false
var serving := false

func _ready() -> void:
	center = get_viewport_rect().size / 2.0
	GameManager.set_saturation(0.0)
	opponent.ball = ball
	ball.hit_paddle.connect(_on_ball_hit_paddle)
	player.shattered.connect(on_paddle_shatter)
	wall_left.body_entered.connect(_on_wall_left_entered)
	wall_right.body_entered.connect(_on_wall_right_entered)
	_update_score()
	_serve(1.0)

# Ball touched the left wall: the opponent scores
func _on_wall_left_entered(body: Node) -> void:
	if body != ball or ended or serving:
		return
	opponent_score += 1
	_serve(-1.0)   # serve toward the player

# Ball touched the right wall: the player scores
func _on_wall_right_entered(body: Node) -> void:
	if body != ball or ended or serving:
		return
	player_score += 1
	_serve(1.0)    # serve toward the opponent

func _serve(dir_x: float) -> void:
	serving = true
	_update_score()
	ball.reset_to(center)   # respawn in the center, stopped
	await get_tree().create_timer(1.0).timeout
	if not ended:
		ball.launch(dir_x)
	serving = false

func _on_ball_hit_paddle(paddle: Node) -> void:
	if ended:
		return
	if paddle == player:
		player.register_hit()
	GameManager.fade_saturation(
		minf(GameManager.saturation + PER_HIT, MAX_SATURATION), 0.3)

func _update_score() -> void:
	player_label.text = str(player_score)
	opponent_label.text = str(opponent_score)

func on_paddle_shatter() -> void:
	ended = true
	ball.set_physics_process(false)
	opponent.set_physics_process(false)
	GameManager.fade_saturation(0.0, 0.1)
	await get_tree().create_timer(1.5).timeout
	GameManager.next_chapter()
