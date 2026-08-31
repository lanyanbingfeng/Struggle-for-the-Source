class_name CombatStatusController
extends Node

var _root: Node2D
var _health: HealthComponent
var _root_remaining: float = 0.0
var _stun_remaining: float = 0.0
var _control_immunity_remaining: float = 0.0
var _movement_slow_remaining: float = 0.0
var _movement_slow_ratio: float = 0.0
var _attack_slow_remaining: float = 0.0
var _attack_interval_increase_ratio: float = 0.0
var _damage_amp_remaining: float = 0.0
var _damage_taken_bonus_ratio: float = 0.0
var _next_hit_reduction_remaining: float = 0.0
var _next_hit_reduction_ratio: float = 0.0
var _control_resist_remaining: float = 0.0
var _control_duration_reduction_ratio: float = 0.0
var _dot_effects: Dictionary[StringName, Dictionary] = {}
var _revealed_to_peer: Dictionary[int, float] = {}

func _ready() -> void:
	set_process(false)

func configure(root: Node2D, health: HealthComponent) -> void:
	_root = root
	_health = health
	_root_remaining = 0.0
	_stun_remaining = 0.0
	_control_immunity_remaining = 0.0
	_movement_slow_remaining = 0.0
	_movement_slow_ratio = 0.0
	_attack_slow_remaining = 0.0
	_attack_interval_increase_ratio = 0.0
	_damage_amp_remaining = 0.0
	_damage_taken_bonus_ratio = 0.0
	_next_hit_reduction_remaining = 0.0
	_next_hit_reduction_ratio = 0.0
	_control_resist_remaining = 0.0
	_control_duration_reduction_ratio = 0.0
	_dot_effects.clear()
	_revealed_to_peer.clear()
	set_process(false)

func _process(delta: float) -> void:
	_root_remaining = maxf(0.0, _root_remaining - delta)
	_stun_remaining = maxf(0.0, _stun_remaining - delta)
	_control_immunity_remaining = maxf(0.0, _control_immunity_remaining - delta)
	_movement_slow_remaining = maxf(0.0, _movement_slow_remaining - delta)
	_attack_slow_remaining = maxf(0.0, _attack_slow_remaining - delta)
	_damage_amp_remaining = maxf(0.0, _damage_amp_remaining - delta)
	_next_hit_reduction_remaining = maxf(0.0, _next_hit_reduction_remaining - delta)
	_control_resist_remaining = maxf(0.0, _control_resist_remaining - delta)
	_process_dots(delta)
	for peer_id: int in _revealed_to_peer.keys():
		var remaining: float = maxf(0.0, _revealed_to_peer[peer_id] - delta)
		if remaining > 0.0:
			_revealed_to_peer[peer_id] = remaining
		else:
			_revealed_to_peer.erase(peer_id)
	if _movement_slow_remaining <= 0.0:
		_movement_slow_ratio = 0.0
	if _attack_slow_remaining <= 0.0:
		_attack_interval_increase_ratio = 0.0
	if _damage_amp_remaining <= 0.0:
		_damage_taken_bonus_ratio = 0.0
	if _next_hit_reduction_remaining <= 0.0:
		_next_hit_reduction_ratio = 0.0
	if _control_resist_remaining <= 0.0:
		_control_duration_reduction_ratio = 0.0
	if not has_any_status():
		set_process(false)

func apply_root(duration: float) -> void:
	if _control_immunity_remaining > 0.0:
		return
	_root_remaining = maxf(_root_remaining, _reduced_control_duration(duration))
	set_process(true)

func apply_stun(duration: float) -> void:
	if _control_immunity_remaining > 0.0:
		return
	_stun_remaining = maxf(_stun_remaining, _reduced_control_duration(duration))
	set_process(true)

func apply_movement_slow(ratio: float, duration: float) -> void:
	_movement_slow_ratio = maxf(_movement_slow_ratio, clampf(ratio, 0.0, 0.6))
	_movement_slow_remaining = maxf(_movement_slow_remaining, duration)
	set_process(true)

func apply_attack_slow(interval_increase_ratio: float, duration: float) -> void:
	_attack_interval_increase_ratio = maxf(_attack_interval_increase_ratio, clampf(interval_increase_ratio, 0.0, 0.5))
	_attack_slow_remaining = maxf(_attack_slow_remaining, duration)
	set_process(true)

func apply_damage_amp(ratio: float, duration: float) -> void:
	_damage_taken_bonus_ratio = maxf(_damage_taken_bonus_ratio, clampf(ratio, 0.0, 0.5))
	_damage_amp_remaining = maxf(_damage_amp_remaining, duration)
	set_process(true)

func apply_next_hit_reduction(ratio: float, duration: float) -> void:
	_next_hit_reduction_ratio = maxf(_next_hit_reduction_ratio, clampf(ratio, 0.0, 0.95))
	_next_hit_reduction_remaining = maxf(_next_hit_reduction_remaining, duration)
	set_process(true)

func apply_control_resistance(ratio: float, duration: float) -> void:
	_control_duration_reduction_ratio = maxf(_control_duration_reduction_ratio, clampf(ratio, 0.0, 0.8))
	_control_resist_remaining = maxf(_control_resist_remaining, duration)
	set_process(true)

func apply_control_immunity(duration: float) -> void:
	_control_immunity_remaining = maxf(_control_immunity_remaining, duration)
	set_process(true)

func apply_dot(source_id: StringName, raw_damage: float, duration: float, interval: float, owner_peer_id: int) -> void:
	if source_id.is_empty() or raw_damage <= 0.0 or duration <= 0.0:
		return
	_dot_effects[source_id] = {
		"damage": raw_damage,
		"remaining": duration,
		"interval": maxf(0.1, interval),
		"elapsed": 0.0,
		"owner_peer_id": owner_peer_id,
	}
	set_process(true)

func reveal_to_peer(peer_id: int, duration: float) -> void:
	if peer_id <= 0 or duration <= 0.0:
		return
	_revealed_to_peer[peer_id] = maxf(duration, _revealed_to_peer.get(peer_id, 0.0))
	set_process(true)

func is_revealed_to_peer(peer_id: int) -> bool:
	return _revealed_to_peer.get(peer_id, 0.0) > 0.0

func cleanse(damage_over_time: bool, movement_slow: bool, attack_slow: bool, defense_reduction: bool, control: bool) -> void:
	if damage_over_time:
		_dot_effects.clear()
	if movement_slow:
		_movement_slow_remaining = 0.0
		_movement_slow_ratio = 0.0
	if attack_slow:
		_attack_slow_remaining = 0.0
		_attack_interval_increase_ratio = 0.0
	if defense_reduction and is_instance_valid(_health):
		_health.clear_negative_defense_modifiers()
	if control:
		_root_remaining = 0.0
		_stun_remaining = 0.0
		if is_instance_valid(_root) and _root.has_method(&"clear_control_state"):
			_root.call(&"clear_control_state")
		if is_instance_valid(_root) and _root.has_method(&"clear_forced_taunt"):
			_root.call(&"clear_forced_taunt")

func modify_final_damage(damage: float) -> float:
	var result: float = damage * (1.0 + _damage_taken_bonus_ratio)
	if _next_hit_reduction_remaining > 0.0 and result > 0.0:
		result *= 1.0 - _next_hit_reduction_ratio
		_next_hit_reduction_remaining = 0.0
		_next_hit_reduction_ratio = 0.0
	return maxf(0.0, result)

func is_rooted() -> bool:
	return _root_remaining > 0.0

func is_stunned() -> bool:
	return _stun_remaining > 0.0

func get_stun_remaining() -> float:
	return _stun_remaining

func is_control_immune() -> bool:
	return _control_immunity_remaining > 0.0

func has_cleanseable_debuff() -> bool:
	return is_rooted() or is_stunned() or _movement_slow_remaining > 0.0 or _attack_slow_remaining > 0.0 or not _dot_effects.is_empty()

func get_movement_multiplier() -> float:
	return 1.0 - _movement_slow_ratio

func get_attack_interval_multiplier() -> float:
	return 1.0 + _attack_interval_increase_ratio

func has_any_status() -> bool:
	return _root_remaining > 0.0 or _stun_remaining > 0.0 or _control_immunity_remaining > 0.0 or _movement_slow_remaining > 0.0 or _attack_slow_remaining > 0.0 or _damage_amp_remaining > 0.0 or _next_hit_reduction_remaining > 0.0 or _control_resist_remaining > 0.0 or not _dot_effects.is_empty() or not _revealed_to_peer.is_empty()

func get_network_state() -> Dictionary:
	return {
		"root": _root_remaining,
		"stun": _stun_remaining,
		"immunity": _control_immunity_remaining,
		"move_slow_remaining": _movement_slow_remaining,
		"move_slow_ratio": _movement_slow_ratio,
		"attack_slow_remaining": _attack_slow_remaining,
		"attack_slow_ratio": _attack_interval_increase_ratio,
		"damage_amp_remaining": _damage_amp_remaining,
		"damage_amp_ratio": _damage_taken_bonus_ratio,
		"revealed": _revealed_to_peer.duplicate(),
	}

func apply_network_state(state: Dictionary) -> void:
	_root_remaining = maxf(0.0, float(state.get("root", 0.0)))
	_stun_remaining = maxf(0.0, float(state.get("stun", 0.0)))
	_control_immunity_remaining = maxf(0.0, float(state.get("immunity", 0.0)))
	_movement_slow_remaining = maxf(0.0, float(state.get("move_slow_remaining", 0.0)))
	_movement_slow_ratio = clampf(float(state.get("move_slow_ratio", 0.0)), 0.0, 0.6)
	_attack_slow_remaining = maxf(0.0, float(state.get("attack_slow_remaining", 0.0)))
	_attack_interval_increase_ratio = clampf(float(state.get("attack_slow_ratio", 0.0)), 0.0, 0.5)
	_damage_amp_remaining = maxf(0.0, float(state.get("damage_amp_remaining", 0.0)))
	_damage_taken_bonus_ratio = clampf(float(state.get("damage_amp_ratio", 0.0)), 0.0, 0.5)
	_revealed_to_peer.clear()
	var revealed_state: Dictionary = state.get("revealed", {}) as Dictionary
	for peer_id_value: Variant in revealed_state.keys():
		_revealed_to_peer[int(peer_id_value)] = maxf(0.0, float(revealed_state[peer_id_value]))
	set_process(has_any_status())

func _reduced_control_duration(duration: float) -> float:
	return duration * (1.0 - _control_duration_reduction_ratio)

func _process_dots(delta: float) -> void:
	if not is_instance_valid(_health) or not _health.is_alive():
		_dot_effects.clear()
		return
	for source_id: StringName in _dot_effects.keys():
		var effect: Dictionary = _dot_effects[source_id]
		var remaining: float = maxf(0.0, float(effect.get("remaining", 0.0)) - delta)
		var elapsed: float = float(effect.get("elapsed", 0.0)) + delta
		var interval: float = float(effect.get("interval", 1.0))
		while elapsed >= interval and remaining > 0.0:
			elapsed -= interval
			_health.apply_attack(float(effect.get("damage", 0.0)), int(effect.get("owner_peer_id", 0)))
		effect["remaining"] = remaining
		effect["elapsed"] = elapsed
		if remaining > 0.0:
			_dot_effects[source_id] = effect
		else:
			_dot_effects.erase(source_id)
