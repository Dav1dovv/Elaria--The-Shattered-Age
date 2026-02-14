# creature_spawner.gd
extends Node2D
class_name CreatureSpawner

@export_category("Spawner Settings")
@export var is_active: bool = true
@export var player: Node2D
@export_range(50, 1000) var spawn_distance_min: float = 100.0
@export_range(50, 1000) var spawn_distance_max: float = 300.0
@export var max_creatures: int = 50

@export_group("Creature Pools")
@export var creatures: Array[CreatureConfig] = []

@export_group("Spawn Timing")
@export var base_spawn_interval: float = 10.0
@export var spawn_interval_variation: float = 3.0
@export_range(1, 5) var spawn_count_min: int = 1
@export_range(1, 5) var spawn_count_max: int = 3
@export var night_spawn_multiplier: float = 1.5  # Ускоряет спавн ночью

@export_group("Despawn Settings")
@export var despawn_enabled: bool = true                     # Вкл/выкл вообще
@export var despawn_check_interval: float = 2.0               # Как часто проверяем (сек)
@export var time_offscreen_to_despawn: float = 15.0

# Внутреннее
var current_pool: Array[CreatureConfig] = []
var spawn_timer: Timer
var can_spawn: bool = true
var _despawn_timer: Timer
var _offscreen_tracker: Dictionary = {}   # Node → время последнего появления на экране
@export var offscreen_margin: float = 150.0
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	add_to_group("Spawner")
	
	spawn_timer = Timer.new()
	spawn_timer.name = "SpawnerTimer"
	spawn_timer.one_shot = false
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	if despawn_enabled:
		_despawn_timer = Timer.new()
		_despawn_timer.wait_time = despawn_check_interval
		_despawn_timer.autostart = true
		_despawn_timer.one_shot = false
		_despawn_timer.timeout.connect(_check_despawn)
		add_child(_despawn_timer)
	
	Global.developer_console.register_command("creature_count", _cmd_count, "Count living creatures")
	Global.developer_console.register_command("creatures_list", _cmd_list, "List all creatures")
	Global.developer_console.register_command("creature_clear", _cmd_clear, "Clear creatures: clear [count=0(all)]")
	Global.developer_console.register_command("spawn", _cmd_spawn, "Spawn specific creature: spawn [index] [count]")
	Global.developer_console.register_command("debug_spawn", _cmd_debug, "Debug spawn system")
	if is_active:
		update_pool()
		_start_timer_if_possible()


func _cmd_count(_args: Array) -> String:
	var count = get_tree().get_nodes_in_group("Creature").size()
	return "Living creatures: %d/%d (max)" % [count, max_creatures]

func _cmd_list(_args: Array) -> String:
	return _get_creature_list()

func _cmd_clear(args: Array) -> String:
	var creatures_group = get_tree().get_nodes_in_group("Creature")
	var total = creatures_group.size()
	
	if total == 0:
		return "No creatures to clear!"
	
	var count_to_clear = total  # По умолчанию все
	
	if not args.is_empty():
		if not args[0].is_valid_int():
			return "Error: Count must be a number. Usage: clear [count]"
		count_to_clear = int(args[0])
		if count_to_clear <= 0:
			count_to_clear = total
		count_to_clear = min(count_to_clear, total)
	
	if count_to_clear == total:
		# Быстрое удаление всех
		for creature in creatures_group:
			if is_instance_valid(creature):
				creature.queue_free()
		return "Cleared ALL %d creatures!" % total
	
	# Удаляем N ближайших к игроку
	if not is_instance_valid(player):
		return "Player not found!"
	
	creatures_group.sort_custom(func(a, b):
		var dist_a = player.global_position.distance_to(a.global_position)
		var dist_b = player.global_position.distance_to(b.global_position)
		return dist_a < dist_b
	)
	
	var cleared = 0
	for i in range(count_to_clear):
		var creature = creatures_group[i]
		if is_instance_valid(creature):
			creature.queue_free()
			cleared += 1
	
	for creature in creatures_group:
		if is_instance_valid(creature):
			creature.queue_free()
			# Удаляем из трекинга
			var idx = tracked_creatures.find(creature)
			if idx != -1:
				tracked_creatures.remove_at(idx)
	
	return "Cleared %d closest creatures (of %d total)" % [cleared, total]

func _cmd_spawn(args: Array) -> String:
	if args.is_empty():
		return "Usage: spawn [index] [count]\n" + _get_creature_list()
	
	var index_str = args[0]
	if not index_str.is_valid_int():
		return "Error: Index must be number!\n" + _get_creature_list()
	
	var index = int(index_str)
	if index < 0 or index >= creatures.size():
		return "Error: Index %d out of range (0-%d)!\n" + _get_creature_list() % [index, creatures.size()-1]
	
	var config = creatures[index]
	if not config or not config.creature_scene:
		return "Error: Creature #%d invalid (no scene)!\n" + _get_creature_list()
	
	var count = 1
	if args.size() > 1:
		if not args[1].is_valid_int():
			return "Error: Count must be number!"
		count = int(args[1])
		if count <= 0:
			return "Error: Count > 0!"
	
	# 🔥 КЛЮЧЕВАЯ ПРОВЕРКА ЛИМИТА
	var current_alive = 0
	for c in get_tree().get_nodes_in_group("Creature"):
		if is_instance_valid(c):
			current_alive += 1
	
	var can_spawn_count = max_creatures - current_alive
	if can_spawn_count <= 0:
		return "Cannot spawn! Max creatures (%d) reached!" % max_creatures
	
	if count > can_spawn_count:
		count = can_spawn_count
		print("Warning: Reduced to %d (limit reached)" % count)
	
	var spawned = 0
	for i in range(count):
		var pos = get_random_position()
		_spawn_single_creature(pos, config)
		spawned += 1
	
	return "✅ Spawned %d x %s #%d (limit: %d/%d)" % [
		spawned, 
		config.creature_scene.resource_path.get_file().get_basename(), 
		index,
		current_alive + spawned,
		max_creatures
	]

func _cmd_debug(_args: Array) -> String:
	var alive = 0
	var total_in_group = get_tree().get_nodes_in_group("Creature").size()
	for c in get_tree().get_nodes_in_group("Creature"):
		if is_instance_valid(c): alive += 1
	
	var phase = _get_current_phase()
	return "=== SPAWN DEBUG ===\n" + \
		   "Alive: %d\nIn group: %d\nCan spawn: %s\nPhase: %s\nPool size: %d" % \
		   [alive, total_in_group, can_spawn, phase, current_pool.size()]


func _get_creature_list() -> String:
	var list = "Creatures list:\n"
	var current_alive = 0
	for c in get_tree().get_nodes_in_group("Creature"):
		if is_instance_valid(c): current_alive += 1
	
	list += "Alive: %d/%d\n\n" % [current_alive, max_creatures]
	
	for i in range(creatures.size()):
		var config = creatures[i]
		var name = "EMPTY" if not config else config.creature_scene.resource_path.get_file().get_basename()
		var phase = "—" if not config else config.spawn_phase
		list += "%d: %s (%.1f, %s)\n" % [i, name, config.spawn_weight if config else 0.0, phase]
	
	return list

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not player:
		warnings.append("Player node is not assigned.")
	if creatures.is_empty():
		warnings.append("No creature configurations assigned.")
	if spawn_distance_min > spawn_distance_max:
		warnings.append("spawn_distance_min cannot be greater than spawn_distance_max.")
	for config in creatures:
		if not config or not config.creature_scene:
			warnings.append("Invalid CreatureConfig: missing scene.")
	return warnings


func update_pool() -> void:
	var phase = _get_current_phase()
	current_pool = creatures.filter(func(c):
		if not c or not c.creature_scene:
			return false
		match c.spawn_phase:
			"Day": return phase == "Day"
			"Night": return phase == "Night"
			"Both": return true
		return false
	)
	
	if current_pool.is_empty() and not creatures.is_empty():
		push_warning("No creatures match current phase: %s" % phase)


func _filter_pool_by_phase(forced: String) -> Array[CreatureConfig]:
	if forced == "":
		return current_pool
	
	var phase = forced
	if phase == "both":
		return creatures.filter(func(c): return c and c.creature_scene)
	
	return creatures.filter(func(c):
		if not c or not c.creature_scene: return false
		match phase:
			"day": return c.spawn_phase in ["Day", "Both"]
			"night": return c.spawn_phase in ["Night", "Both"]
		return false
	)


func _get_current_phase() -> String:
	if not is_instance_valid(DayNightCycle):
		return "Day"
	
	match DayNightCycle.Phase:
		DayNightCycle.Phase.DAY, DayNightCycle.Phase.MIDDAY:
			return "Day"
		DayNightCycle.Phase.NIGHT:
			return "Night"
	
	return "Day"


var tracked_creatures: Array[Node] = []

func _is_creature_on_screen(creature: Node2D) -> bool:
	if not is_instance_valid(creature):
		return false
	
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return true  # если камеры нет — считаем видимым (на всякий случай)
	
	# Правильный способ в Godot 4:
	var screen_pos := camera.get_screen_center_position() + \
		(creature.global_position - camera.global_position) * camera.zoom
	
	var viewport_rect := get_viewport().get_visible_rect()
	var expanded_rect := viewport_rect.grow(offscreen_margin)
	
	return expanded_rect.has_point(screen_pos)

# Обновление трекера видимости (вызывай каждый кадр)
func _track_creatures_visibility() -> void:
	if not despawn_enabled:
		return
	
	var current_time := Time.get_ticks_msec() / 1000.0  # секунды с плавной точкой
	
	for creature in get_tree().get_nodes_in_group("Creature"):
		if not is_instance_valid(creature):
			continue
			
		if _is_creature_on_screen(creature):
			_offscreen_tracker[creature] = current_time
		# если не видно — время не обновляется

# Проверка на удаление
func _check_despawn() -> void:
	if not despawn_enabled:
		return
		
	var current_time := Time.get_ticks_msec() / 1000.0
	var to_despawn: Array[Node] = []
	
	for creature in _offscreen_tracker.keys():
		if not is_instance_valid(creature):
			to_despawn.append(creature)
			continue
			
		var last_seen_time: float = _offscreen_tracker[creature]
		if current_time - last_seen_time > time_offscreen_to_despawn:
			to_despawn.append(creature)
	
	for creature in to_despawn:
		_despawn_creature(creature)

func _despawn_creature(creature: Node) -> void:
	_offscreen_tracker.erase(creature)
	if creature.is_in_group("Creature"):
		creature.remove_from_group("Creature")
	
	creature.queue_free()

func _physics_process(_delta: float) -> void:
	_track_creatures_visibility()
	# Очистка мёртвых (раз в кадр)
	for i in range(tracked_creatures.size() - 1, -1, -1):
		var creature = tracked_creatures[i]
		if not is_instance_valid(creature):
			tracked_creatures.remove_at(i)
	
	can_spawn = tracked_creatures.size() < max_creatures

func _spawn_single_creature(pos: Vector2, config: CreatureConfig) -> void:
	var scene = config.get_random_scene()
	if not scene: return
	var instance = scene.instantiate()
	instance.global_position = pos
	instance.add_to_group("Creature")
	tracked_creatures.append(instance)  # 🔥 ТРЕКИНГ
	get_tree().current_scene.add_child(instance)


func _select_creature_from_pool(pool: Array[CreatureConfig]) -> CreatureConfig:
	if pool.is_empty(): return null
	var total = pool.reduce(func(a, c): return a + c.spawn_weight, 0.0)
	if total <= 0.0: return null
	var roll = randf() * total
	var sum = 0.0
	for c in pool:
		sum += c.spawn_weight
		if roll <= sum:
			return c
	return pool[0]


func get_random_position() -> Vector2:
	if not is_instance_valid(player):
		return global_position
	var dist = randf_range(spawn_distance_min, spawn_distance_max)
	var angle = randf() * TAU
	return player.global_position + Vector2(cos(angle), sin(angle)) * dist


func _on_spawn_timer_timeout() -> void:
	if not is_active or not is_instance_valid(player) or not can_spawn:
		return
	
	update_pool()
	if current_pool.is_empty():
		_start_timer_if_possible()
		return
	
	var count = randi_range(spawn_count_min, spawn_count_max)
	for i in count:
		if not can_spawn: break
		var pos = get_random_position()
		var config = _select_creature_from_pool(current_pool)
		if config:
			_spawn_single_creature(pos, config)
	
	_start_timer_if_possible()


func _start_timer_if_possible() -> void:
	if not is_active or current_pool.is_empty():
		if spawn_timer.is_stopped() == false:
			spawn_timer.stop()
		return
	
	var interval = _get_next_spawn_interval()
	spawn_timer.start(interval)


func _get_next_spawn_interval() -> float:
	var base = randf_range(
		base_spawn_interval - spawn_interval_variation,
		base_spawn_interval + spawn_interval_variation
	)
	if _get_current_phase() == "Night":
		return base / night_spawn_multiplier  # Чаще ночью
	return base
