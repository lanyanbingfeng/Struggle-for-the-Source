class_name HealthComponent
extends Node

signal state_changed(current_health: float, max_health: float, current_mana: float, max_mana: float)
signal died(component: HealthComponent)

var target_root: Node2D
var owner_peer_id: int = 0
var max_health: float = 1.0
var current_health: float = 1.0
var base_defense: float = 0.0
var defense: float = 0.0
var evasion_chance: float = 0.0
var max_mana: float = 0.0
var current_mana: float = 0.0
var mana_regen_per_second: float = 0.0
var combat_radius: float = 0.0
var last_damage_owner_peer_id: int = 0
var _alive: bool = true
var _temporary_defense_bonuses: Dictionary[StringName, float] = {}
var _temporary_defense_durations: Dictionary[StringName, float] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	var changed: bool = false
	for source_id_value: Variant in _temporary_defense_durations.keys():
		var source_id: StringName = StringName(str(source_id_value))
		var remaining: float = maxf(0.0, float(_temporary_defense_durations[source_id]) - delta)
		if remaining > 0.0:
			_temporary_defense_durations[source_id] = remaining
			continue
		_temporary_defense_durations.erase(source_id)
		_temporary_defense_bonuses.erase(source_id)
		changed = true
	if changed:
		_recalculate_defense()
	if _temporary_defense_durations.is_empty():
		set_process(false)

func configure_from_unit(root: Node2D, peer_id: int, definition: UnitDefinition) -> void:
	configure(
		root,
		peer_id,
		float(definition.max_health),
		float(definition.defense),
		definition.evasion_chance,
		float(definition.max_mana),
		definition.mana_regen_per_second
	)

func configure(
	root: Node2D,
	peer_id: int,
	new_max_health: float,
	new_defense: float,
	new_evasion_chance: float = 0.0,
	new_max_mana: float = 0.0,
	new_mana_regen: float = 0.0
) -> void:
	target_root = root
	owner_peer_id = peer_id
	max_health = maxf(1.0, new_max_health)
	current_health = max_health
	base_defense = maxf(0.0, new_defense)
	_temporary_defense_bonuses.clear()
	_temporary_defense_durations.clear()
	_recalculate_defense()
	set_process(false)
	evasion_chance = clampf(new_evasion_chance, 0.0, 0.95)
	max_mana = maxf(0.0, new_max_mana)
	current_mana = max_mana
	mana_regen_per_second = maxf(0.0, new_mana_regen)
	_alive = true
	last_damage_owner_peer_id = 0
	_rng.seed = peer_id * 1000003 + int(root.get_instance_id())
	_emit_state()

func apply_attack(raw_attack: float, source_owner_peer_id: int = 0) -> float:
	if not _alive:
		return 0.0
	if evasion_chance > 0.0 and _rng.randf() < evasion_chance:
		return 0.0
	var damage := maxf(1.0, raw_attack - defense)
	if source_owner_peer_id > 0:
		last_damage_owner_peer_id = source_owner_peer_id
	current_health = maxf(0.0, current_health - damage)
	_emit_state()
	if current_health <= 0.0:
		_alive = false
		died.emit(self)
	return damage

func execute_if_below(health_ratio: float, source_owner_peer_id: int = 0) -> bool:
	if not _alive or health_ratio <= 0.0 or get_health_ratio() >= health_ratio:
		return false
	current_health = 0.0
	if source_owner_peer_id > 0:
		last_damage_owner_peer_id = source_owner_peer_id
	_alive = false
	_emit_state()
	died.emit(self)
	return true

func heal(amount: float) -> float:
	if not _alive or amount <= 0.0:
		return 0.0
	var previous := current_health
	current_health = minf(max_health, current_health + amount)
	if not is_equal_approx(previous, current_health):
		_emit_state()
	return current_health - previous

func regenerate_mana(delta: float) -> void:
	if not _alive or max_mana <= 0.0 or current_mana >= max_mana:
		return
	current_mana = minf(max_mana, current_mana + mana_regen_per_second * delta)
	_emit_state()

func spend_mana(amount: float) -> bool:
	if amount < 0.0 or current_mana + 0.001 < amount:
		return false
	current_mana = maxf(0.0, current_mana - amount)
	_emit_state()
	return true

func apply_network_state(health_value: float, mana_value: float) -> void:
	current_health = clampf(health_value, 0.0, max_health)
	current_mana = clampf(mana_value, 0.0, max_mana)
	_alive = current_health > 0.0
	_emit_state()

func set_max_health(new_max_health: float, preserve_ratio: bool = true) -> void:
	var previous_ratio: float = get_health_ratio() if max_health > 0.0 else 1.0
	max_health = maxf(1.0, new_max_health)
	current_health = max_health * previous_ratio if preserve_ratio else minf(current_health, max_health)
	_emit_state()

func apply_temporary_defense_bonus(source_id: StringName, amount: float, duration: float) -> void:
	if source_id.is_empty() or amount <= 0.0 or duration <= 0.0:
		return
	_temporary_defense_bonuses[source_id] = amount
	_temporary_defense_durations[source_id] = maxf(duration, float(_temporary_defense_durations.get(source_id, 0.0)))
	_recalculate_defense()
	set_process(true)

func get_temporary_defense_bonus(source_id: StringName) -> float:
	return float(_temporary_defense_bonuses.get(source_id, 0.0))

func is_alive() -> bool:
	return _alive and is_instance_valid(target_root)

func get_health_ratio() -> float:
	return current_health / max_health

func get_target_position() -> Vector2:
	return target_root.global_position if is_instance_valid(target_root) else Vector2.INF

func _recalculate_defense() -> void:
	var bonus: float = 0.0
	for amount_value: Variant in _temporary_defense_bonuses.values():
		bonus += float(amount_value)
	defense = maxf(0.0, base_defense + bonus)

func _emit_state() -> void:
	state_changed.emit(current_health, max_health, current_mana, max_mana)
