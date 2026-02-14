extends Node
class_name EffectManager

# Класс для хранения активного экземпляра эффекта
class ActiveEffect:
	var effect: Effect
	var time_remaining: float
	var tick_timer: float
	var stacks: int = 1
	
	func _init(eff: Effect):
		effect = eff
		time_remaining = eff.duration
		tick_timer = 0.0

# Словарь активных эффектов: {effect_type: ActiveEffect}
var active_effects: Dictionary = {}

# Ссылка на владельца (Entity)
var owner_entity: Entity

# Модификаторы
var speed_modifier: float = 0.0
var damage_modifier: float = 0.0
var defense_modifier: float = 0.0
var is_invisible: bool = false

# Таймеры для периодических эффектов
var regen_timer: float = 0.0
var poison_timer: float = 0.0

signal effect_added(effect: Effect)
signal effect_removed(effect: Effect)
signal effect_tick(effect: Effect)

func _init(entity: Entity):
	owner_entity = entity

func _ready():
	set_process(true)

func _process(delta: float):
	var effects_to_remove = []
	
	for effect_type in active_effects.keys():
		var active_effect: ActiveEffect = active_effects[effect_type]
		
		# Обновляем таймер эффекта
		if active_effect.effect.duration > 0:
			active_effect.time_remaining -= delta
			
			if active_effect.time_remaining <= 0:
				effects_to_remove.append(effect_type)
				continue
		
		# Обрабатываем периодические эффекты
		if active_effect.effect.tick_interval > 0:
			active_effect.tick_timer += delta
			
			if active_effect.tick_timer >= active_effect.effect.tick_interval:
				active_effect.tick_timer = 0.0
				_process_tick_effect(active_effect.effect)
	
	# Удаляем истекшие эффекты
	for effect_type in effects_to_remove:
		remove_effect_by_type(effect_type)

func apply_effect_instance(effect: Effect) -> void:
	if effect == null:
		return
	
	var effect_type = effect.effect_type
	
	# Проверяем стаки
	if active_effects.has(effect_type):
		var active_effect: ActiveEffect = active_effects[effect_type]
		
		if active_effect.stacks < effect.max_stacks:
			active_effect.stacks += 1
			active_effect.time_remaining = effect.duration  # Обновляем время
			_apply_effect_logic(effect, active_effect.stacks)
		else:
			# Просто обновляем время действия
			active_effect.time_remaining = effect.duration
		return
	
	# Создаем новый активный эффект
	var active_effect = ActiveEffect.new(effect)
	active_effects[effect_type] = active_effect
	
	# Применяем эффект
	_apply_effect_logic(effect, 1)
	
	# Визуальные эффекты
	_spawn_particles(effect)
	_play_sound(effect)
	
	emit_signal("effect_added", effect)

func _apply_effect_logic(effect: Effect, stack_count: int = 1) -> void:
	match effect.effect_type:
		Effect.EffectType.HEALTH_RESTORE:
			owner_entity.heal(effect.value * stack_count)
		
		Effect.EffectType.SPEED_BOOST:
			add_speed_modifier(effect.value * stack_count)
		
		Effect.EffectType.DAMAGE_BOOST:
			add_damage_modifier(effect.value * stack_count)
		
		Effect.EffectType.DEFENSE_BOOST:
			add_defense_modifier(effect.value * stack_count)
		
		Effect.EffectType.INVISIBILITY:
			set_invisibility(true)
		
		Effect.EffectType.SLOW:
			add_speed_modifier(-effect.value * stack_count)
		
		Effect.EffectType.REGENERATION, Effect.EffectType.POISON:
			pass  # Обрабатываются в _process_tick_effect

func _process_tick_effect(effect: Effect) -> void:
	match effect.effect_type:
		Effect.EffectType.REGENERATION:
			owner_entity.heal(effect.value)
		
		Effect.EffectType.POISON:
			owner_entity.take_damage(effect.value)
		
		Effect.EffectType.BURN:
			owner_entity.take_damage(effect.value)
	
	emit_signal("effect_tick", effect)

func remove_effect_instance(effect: Effect) -> void:
	remove_effect_by_type(effect.effect_type)

func remove_effect_by_type(effect_type: Effect.EffectType) -> void:
	if not active_effects.has(effect_type):
		return
	
	var active_effect: ActiveEffect = active_effects[effect_type]
	var effect = active_effect.effect
	
	# Убираем модификаторы
	_remove_effect_logic(effect, active_effect.stacks)
	
	active_effects.erase(effect_type)
	emit_signal("effect_removed", effect)

func _remove_effect_logic(effect: Effect, stack_count: int = 1) -> void:
	match effect.effect_type:
		Effect.EffectType.SPEED_BOOST:
			remove_speed_modifier(effect.value * stack_count)
		
		Effect.EffectType.DAMAGE_BOOST:
			remove_damage_modifier(effect.value * stack_count)
		
		Effect.EffectType.DEFENSE_BOOST:
			remove_defense_modifier(effect.value * stack_count)
		
		Effect.EffectType.INVISIBILITY:
			set_invisibility(false)
		
		Effect.EffectType.SLOW:
			remove_speed_modifier(-effect.value * stack_count)

# Методы модификаторов
func add_speed_modifier(value: float) -> void:
	speed_modifier += value
	_update_entity_speed()

func remove_speed_modifier(value: float) -> void:
	speed_modifier -= value
	_update_entity_speed()

func add_damage_modifier(value: float) -> void:
	damage_modifier += value
	if owner_entity.Entity_stats:
		owner_entity.Entity_stats.damage_modifier = owner_entity.Entity_stats.base_damage_modifier + damage_modifier

func remove_damage_modifier(value: float) -> void:
	damage_modifier -= value
	if owner_entity.Entity_stats:
		owner_entity.Entity_stats.damage_modifier = owner_entity.Entity_stats.base_damage_modifier + damage_modifier

func add_defense_modifier(value: float) -> void:
	defense_modifier += value
	if owner_entity.Entity_stats:
		owner_entity.Entity_stats.defense_modifier = owner_entity.Entity_stats.base_defense_modifier + defense_modifier

func remove_defense_modifier(value: float) -> void:
	defense_modifier -= value
	if owner_entity.Entity_stats:
		owner_entity.Entity_stats.defense_modifier = owner_entity.Entity_stats.base_defense_modifier + defense_modifier

func set_invisibility(value: bool) -> void:
	is_invisible = value
	if owner_entity.has_node("Sprite2D"):
		var sprite = owner_entity.get_node("Sprite2D")
		sprite.modulate.a = 0.3 if value else 1.0

func _update_entity_speed() -> void:
	if owner_entity.Entity_stats:
		var base_speed = owner_entity.Entity_stats.base_move_speed
		owner_entity.Entity_stats.move_speed = base_speed * (1.0 + speed_modifier)

# Визуальные эффекты
func _spawn_particles(effect: Effect) -> void:
	if effect.particle == null:
		return
	
	var particles_instance = effect.particle.instantiate()
	owner_entity.add_child(particles_instance)
	
	if particles_instance is GPUParticles2D:
		particles_instance.emitting = true

func _play_sound(effect: Effect) -> void:
	if effect.sound_effect == null:
		return
	
	var audio_player = AudioStreamPlayer.new()
	owner_entity.add_child(audio_player)
	audio_player.stream = effect.sound_effect
	audio_player.play()
	audio_player.finished.connect(func(): audio_player.queue_free())

# Вспомогательные методы
func get_active_effects() -> Array:
	return active_effects.values()

func has_effect(effect_type: Effect.EffectType) -> bool:
	return active_effects.has(effect_type)

func get_effect_time_remaining(effect_type: Effect.EffectType) -> float:
	if not active_effects.has(effect_type):
		return 0.0
	return active_effects[effect_type].time_remaining

func clear_all_effects() -> void:
	var effect_types = active_effects.keys()
	for effect_type in effect_types:
		remove_effect_by_type(effect_type)
