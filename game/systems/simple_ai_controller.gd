class_name SimpleAIController
extends Node

signal think_requested

enum Difficulty { EASY, NORMAL, HARD, HELL }

const DIFFICULTY_NAMES: Array[String] = ["简单", "普通", "困难", "地狱"]
const THINK_DELAY_RANGES: Array[Vector2] = [
	Vector2(4.2, 5.4),
	Vector2(2.4, 3.2),
	Vector2(0.9, 1.4),
	Vector2.ZERO,
]

var paused: bool = false
var enabled: bool = false
var difficulty: int = Difficulty.NORMAL
var _remaining_think_time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	set_process(false)

func configure(should_enable: bool, selected_difficulty: int = Difficulty.NORMAL) -> void:
	enabled = should_enable
	paused = false
	difficulty = clampi(selected_difficulty, Difficulty.EASY, Difficulty.HELL)
	_rng.seed = Time.get_ticks_msec() ^ (difficulty * 7919)
	_remaining_think_time = _roll_think_delay()
	set_process(enabled)

func set_ai_paused(should_pause: bool) -> void:
	paused = should_pause

static func get_difficulty_name(selected_difficulty: int) -> String:
	var safe_difficulty: int = clampi(selected_difficulty, Difficulty.EASY, Difficulty.HELL)
	return DIFFICULTY_NAMES[safe_difficulty]

static func get_think_delay_range(selected_difficulty: int) -> Vector2:
	var safe_difficulty: int = clampi(selected_difficulty, Difficulty.EASY, Difficulty.HELL)
	return THINK_DELAY_RANGES[safe_difficulty]

func _process(delta: float) -> void:
	if not enabled or paused:
		return
	if difficulty == Difficulty.HELL:
		# Hell mode has no artificial thinking pause, but still yields between
		# control steps so a failed action cannot create a tight loop.
		think_requested.emit()
		return
	_remaining_think_time -= delta
	if _remaining_think_time > 0.0:
		return
	think_requested.emit()
	_remaining_think_time = _roll_think_delay()

func _roll_think_delay() -> float:
	var delay_range: Vector2 = get_think_delay_range(difficulty)
	if delay_range.y <= 0.0:
		return 0.0
	return _rng.randf_range(delay_range.x, delay_range.y)
