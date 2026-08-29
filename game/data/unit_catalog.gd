class_name UnitCatalog
extends Resource

@export var definitions: Array[UnitDefinition] = []
@export var recruitment_pool: Array[UnitDefinition] = []
@export var summon_pool: Array[UnitDefinition] = []
@export var hero_pool: Array[UnitDefinition] = []

func get_definition(unit_id: StringName) -> UnitDefinition:
	for definition: UnitDefinition in definitions:
		if definition != null and definition.unit_id == unit_id:
			return definition
	return null

func build_recruitment_cards() -> Array[UnitDefinition]:
	return recruitment_pool.duplicate()

func build_summon_cards(base_level: int, card_count: int, rng: RandomNumberGenerator) -> Array[UnitDefinition]:
	var cards: Array[UnitDefinition] = []
	if summon_pool.is_empty() or rng == null:
		return cards
	for _index: int in card_count:
		var rarity: UnitDefinition.Rarity = BaseProgression.roll_rarity(base_level, rng)
		var candidates: Array[UnitDefinition] = _definitions_for_rarity(rarity)
		if not candidates.is_empty():
			cards.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	return cards

func build_hero_choices() -> Array[UnitDefinition]:
	var choices: Array[UnitDefinition] = []
	for definition: UnitDefinition in hero_pool:
		if definition != null and definition.category == UnitDefinition.Category.HERO:
			choices.append(definition)
	return choices

func definitions_from_ids(unit_ids: Array) -> Array[UnitDefinition]:
	var cards: Array[UnitDefinition] = []
	for unit_id_value: Variant in unit_ids:
		var definition: UnitDefinition = get_definition(StringName(str(unit_id_value)))
		if definition != null:
			cards.append(definition)
	return cards

func _definitions_for_rarity(requested_rarity: UnitDefinition.Rarity) -> Array[UnitDefinition]:
	for rarity_index: int in range(int(requested_rarity), -1, -1):
		var candidates: Array[UnitDefinition] = []
		for definition: UnitDefinition in summon_pool:
			if definition != null and definition.category == UnitDefinition.Category.COMBAT and int(definition.rarity) == rarity_index:
				candidates.append(definition)
		if not candidates.is_empty():
			return candidates
	for rarity_index: int in range(int(requested_rarity) + 1, UnitDefinition.Rarity.size()):
		var candidates: Array[UnitDefinition] = []
		for definition: UnitDefinition in summon_pool:
			if definition != null and definition.category == UnitDefinition.Category.COMBAT and int(definition.rarity) == rarity_index:
				candidates.append(definition)
		if not candidates.is_empty():
			return candidates
	return []
