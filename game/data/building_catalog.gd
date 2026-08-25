class_name BuildingCatalog
extends Resource

@export var definitions: Array[BuildingDefinition] = []

func get_definition(building_id: StringName) -> BuildingDefinition:
	for definition: BuildingDefinition in definitions:
		if definition != null and definition.building_id == building_id:
			return definition
	return null
