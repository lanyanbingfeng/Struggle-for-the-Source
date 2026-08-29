class_name HeroDefinition
extends UnitDefinition

@export var passive_skill: Resource
@export var active_skills: Array[Resource] = []

func get_hero_skill(requested_skill_id: StringName) -> Resource:
	if passive_skill != null and StringName(str(passive_skill.get("skill_id"))) == requested_skill_id:
		return passive_skill
	for skill: Resource in active_skills:
		if skill != null and StringName(str(skill.get("skill_id"))) == requested_skill_id:
			return skill
	return null
