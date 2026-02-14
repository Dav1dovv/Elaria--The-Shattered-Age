extends Resource
class_name Effect

enum EffectType {
	HEALTH_RESTORE = 0,
	SPEED_BOOST = 1,
	DAMAGE_BOOST = 2,
	REGENERATION = 3,
	DEFENSE_BOOST = 4,
	INVISIBILITY = 7,
	POISON = 8,
	SLOW = 9,
	BURN = 10,
	FREEZE = 11,
}

@export_category("Effect Properties")
@export var effect_icon : Texture
@export var effect_type: EffectType = EffectType.HEALTH_RESTORE
@export var value: float = 0.0  # Значение эффекта
@export var duration: float = 0.0  # Длительность в секундах (0 для мгновенного)
@export var tick_interval: float = 1.0  # Интервал для периодических эффектов
@export var max_stacks: int = 1  # Максимальное количество стаков

@export_category("Visual Effects")
@export var particle_color: Color = Color.WHITE
@export var particle: PackedScene
@export var icon: Texture2D
@export var sound_effect: AudioStream

@export_category("UI Display")
@export var display_name: String = "Effect"
@export_multiline var description: String = ""

# Методы применения эффектов
func apply_effect(target: Node) -> void:
	if target.has_method("apply_effect_instance"):
		target.apply_effect_instance(self)
	else:
		_apply_direct_effect(target)

func _apply_direct_effect(target: Node) -> void:
	match effect_type:
		EffectType.HEALTH_RESTORE:
			if target.has_method("heal"):
				target.heal(value)
		
		EffectType.SPEED_BOOST:
			if target.has_method("add_speed_modifier"):
				target.add_speed_modifier(value, duration)
		
		EffectType.DAMAGE_BOOST:
			if target.has_method("add_damage_modifier"):
				target.add_damage_modifier(value, duration)
		
		EffectType.REGENERATION:
			if target.has_method("start_regeneration"):
				target.start_regeneration(value, duration, tick_interval)
		
		EffectType.DEFENSE_BOOST:
			if target.has_method("add_defense_modifier"):
				target.add_defense_modifier(value, duration)
		
		EffectType.INVISIBILITY:
			if target.has_method("set_invisibility"):
				target.set_invisibility(true, duration)
		
		EffectType.POISON:
			if target.has_method("apply_poison"):
				target.apply_poison(value, duration, tick_interval)
		
		EffectType.SLOW:
			if target.has_method("add_speed_modifier"):
				target.add_speed_modifier(-value, duration)

func remove_effect(target: Node) -> void:
	if target.has_method("remove_effect_instance"):
		target.remove_effect_instance(self)
	else:
		_remove_direct_effect(target)

func _remove_direct_effect(target: Node) -> void:
	match effect_type:
		EffectType.SPEED_BOOST, EffectType.SLOW:
			if target.has_method("remove_speed_modifier"):
				target.remove_speed_modifier(value)
		
		EffectType.DAMAGE_BOOST:
			if target.has_method("remove_damage_modifier"):
				target.remove_damage_modifier(value)
		
		EffectType.DEFENSE_BOOST:
			if target.has_method("remove_defense_modifier"):
				target.remove_defense_modifier(value)
		
		EffectType.INVISIBILITY:
			if target.has_method("set_invisibility"):
				target.set_invisibility(false)

func get_tooltip_text() -> String:
	var text = display_name + "\n"
	text += description + "\n\n"
	
	var effect_text = ""
	match effect_type:
		EffectType.HEALTH_RESTORE:
			effect_text = "Restores " + str(value) + " health"
		EffectType.SPEED_BOOST:
			effect_text = "Increases speed by " + str(value * 100) + "%"
		EffectType.DAMAGE_BOOST:
			effect_text = "Increases damage by " + str(value * 100) + "%"
		EffectType.REGENERATION:
			effect_text = "Regenerates " + str(value) + " health every " + str(tick_interval) + "s"
		EffectType.DEFENSE_BOOST:
			effect_text = "Increases defense by " + str(value * 100) + "%"
		EffectType.INVISIBILITY:
			effect_text = "Makes you invisible"
		EffectType.POISON:
			effect_text = "Deals " + str(value) + " damage every " + str(tick_interval) + "s"
		EffectType.SLOW:
			effect_text = "Reduces speed by " + str(value * 100) + "%"
	
	text += effect_text
	
	if duration > 0:
		text += "\nDuration: " + str(duration) + "s"
	else:
		text += "\nInstant effect"
	
	if max_stacks > 1:
		text += "\nMax stacks: " + str(max_stacks)
	
	return text

# Создание предустановленных эффектов
static func create_health_potion() -> Effect:
	var effect = Effect.new()
	effect.effect_type = EffectType.HEALTH_RESTORE
	effect.value = 50.0
	effect.display_name = "Health Potion"
	effect.description = "Restores health instantly"
	effect.particle_color = Color.RED
	return effect

static func create_speed_boost() -> Effect:
	var effect = Effect.new()
	effect.effect_type = EffectType.SPEED_BOOST
	effect.value = 0.3  # 30% увеличение
	effect.duration = 30.0
	effect.display_name = "Speed Boost"
	effect.description = "Increases movement speed"
	effect.particle_color = Color.YELLOW
	return effect

static func create_regeneration() -> Effect:
	var effect = Effect.new()
	effect.effect_type = EffectType.REGENERATION
	effect.value = 5.0
	effect.duration = 20.0
	effect.tick_interval = 2.0
	effect.display_name = "Regeneration"
	effect.description = "Slowly regenerates health over time"
	effect.particle_color = Color.GREEN
	return effect
