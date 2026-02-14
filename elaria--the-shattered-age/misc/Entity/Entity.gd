extends CharacterBody2D
class_name Entity

@export var Entity_stats: stats
@export var Vfx_node : VFX
@export var knockback_strength: float = 300.0
@export var knockback_duration: float = 0.1

# Сигналы
signal health_changed(new_health: float)
signal died

# Переменные состояния
var is_alive: bool = true
var is_knocked_back: bool = false

# Менеджер эффектов
var effect_manager: EffectManager

func _ready():
	Entity_stats.move_speed = Entity_stats.base_move_speed
	# Инициализируем менеджер эффектов
	effect_manager = EffectManager.new(self)
	add_child(effect_manager)
	
	# Подключаем сигналы эффектов
	effect_manager.effect_added.connect(_on_effect_added)
	effect_manager.effect_removed.connect(_on_effect_removed)

# УЛУЧШЕННАЯ СИСТЕМА ПОЛУЧЕНИЯ УРОНА
func take_damage(damage: float, damage_source: Node2D = null) -> void:
	if not is_alive or is_knocked_back:
		return
	
	# Получаем итоговое снижение урона
	var total_reduction = Entity_stats.get_total_damage_reduction()
	
	# Добавляем снижение от эффектов
	if effect_manager:
		total_reduction += effect_manager.defense_modifier
		total_reduction = clamp(total_reduction, 0.0, 0.9)
	
	# Рассчитываем фактический урон
	var actual_damage = damage * (1.0 - total_reduction)
	
	# Визуальные эффекты
	if Vfx_node != null: 
		Vfx_node._damage_vfx(self)
	
	# Применяем урон
	Entity_stats.current_health -= actual_damage
	emit_signal("health_changed", Entity_stats.current_health)
	
	# Информация в консоль
	print("====================================")
	print("Получен урон:")
	print("  Базовый урон: %.1f" % damage)
	print("  Броня: %.1f (%.1f%% снижения)" % [Entity_stats.armor, Entity_stats.get_armor_reduction() * 100])
	print("  Доп. защита: %.1f%%" % (Entity_stats.defense_modifier * 100))
	if effect_manager and effect_manager.defense_modifier > 0:
		print("  Защита от эффектов: %.1f%%" % (effect_manager.defense_modifier * 100))
	print("  Итоговое снижение: %.1f%%" % (total_reduction * 100))
	print("  Фактический урон: %.1f" % actual_damage)
	print("  Осталось HP: %.1f / %.1f" % [Entity_stats.current_health, Entity_stats.max_health])
	print("====================================")
	
	# Отбрасывание
	if damage_source != null:
		apply_knockback(damage_source, knockback_strength)
	
	# Проверка на смерть
	if Entity_stats.current_health <= 0:
		die()

func apply_knockback(damage_source: Node2D, knockback_multipiler: float) -> void:
	if is_knocked_back:
		return
	is_knocked_back = true
	
	var knockback_direction = (global_position - damage_source.global_position).normalized()
	var knockback_distance = knockback_direction * knockback_multipiler / 3.5
	
	var tween = create_tween()
	tween.tween_property(self, "position", position + knockback_distance, knockback_duration)
	tween.tween_callback(func(): is_knocked_back = false)
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	tween.tween_callback(func():
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
	)

func die() -> void:
	if not is_alive:
		return
	is_alive = false
	emit_signal("died")
	
	# Очищаем все эффекты
	if effect_manager:
		effect_manager.clear_all_effects()
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	if $Drop: 
		$Drop._drop_items()
	
	if is_in_group("Creature"):
		remove_from_group("Creature")

####### Entity effects - через EffectManager
func heal(amount: float) -> void:
	if !is_alive:
		return
	Entity_stats.current_health = min(Entity_stats.current_health + amount, Entity_stats.max_health)
	emit_signal("health_changed", Entity_stats.current_health)

func apply_effect_instance(effect: Effect) -> void:
	if effect_manager:
		effect_manager.apply_effect_instance(effect)

func remove_effect_instance(effect: Effect) -> void:
	if effect_manager:
		effect_manager.remove_effect_instance(effect)

func add_speed_modifier(value: float, duration: float = -1.0) -> void:
	if effect_manager:
		effect_manager.add_speed_modifier(value)

func remove_speed_modifier(value: float) -> void:
	if effect_manager:
		effect_manager.remove_speed_modifier(value)

func add_damage_modifier(value: float, duration: float = -1.0) -> void:
	if effect_manager:
		effect_manager.add_damage_modifier(value)

func remove_damage_modifier(value: float) -> void:
	if effect_manager:
		effect_manager.remove_damage_modifier(value)

func add_defense_modifier(value: float, duration: float = -1.0) -> void:
	if effect_manager:
		effect_manager.add_defense_modifier(value)

func remove_defense_modifier(value: float) -> void:
	if effect_manager:
		effect_manager.remove_defense_modifier(value)

func set_invisibility(value: bool, duration: float = 0.0) -> void:
	if effect_manager:
		effect_manager.set_invisibility(value)

func start_regeneration(value: float, duration: float, tick_interval: float) -> void:
	var regen_effect = Effect.new()
	regen_effect.effect_type = Effect.EffectType.REGENERATION
	regen_effect.value = value
	regen_effect.duration = duration
	regen_effect.tick_interval = tick_interval
	apply_effect_instance(regen_effect)

func apply_poison(value: float, duration: float, tick_interval: float) -> void:
	var poison_effect = Effect.new()
	poison_effect.effect_type = Effect.EffectType.POISON
	poison_effect.value = value
	poison_effect.duration = duration
	poison_effect.tick_interval = tick_interval
	apply_effect_instance(poison_effect)

func _on_effect_added(effect: Effect) -> void:
	print("Effect added: " + effect.display_name)

func _on_effect_removed(effect: Effect) -> void:
	print("Effect removed: " + effect.display_name)
