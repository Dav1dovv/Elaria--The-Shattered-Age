# creature_spawner.gd
extends Node2D
class_name CreatureSpawner

# ─────────────────────────────────────────────
#  НАСТРОЙКИ СПАВНА
# ─────────────────────────────────────────────
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
@export var night_spawn_multiplier: float = 1.5

@export_group("Despawn Settings")
@export var despawn_enabled: bool = true
@export var despawn_check_interval: float = 2.0
@export var time_offscreen_to_despawn: float = 15.0
@export var offscreen_margin: float = 150.0

# ─────────────────────────────────────────────
#  ВНУТРЕННИЕ ПЕРЕМЕННЫЕ
# ─────────────────────────────────────────────
var current_pool: Array[CreatureConfig] = []
var can_spawn: bool = true

var _spawn_timer: Timer
var _despawn_timer: Timer

# Node → время последнего появления на экране
var _offscreen_tracker: Dictionary = {}

# Живые существа (очищается автоматически)
var _tracked_creatures: Array[Node] = []


# ─────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	add_to_group("Spawner")

	_spawn_timer = _create_timer(0.0, false, _on_spawn_timer_timeout)

	if despawn_enabled:
		_despawn_timer = _create_timer(despawn_check_interval, true, _check_despawn)

	_register_console_commands()

	if is_active:
		update_pool()
		_start_timer_if_possible()


func _create_timer(wait: float, autostart: bool, callback: Callable) -> Timer:
	var t := Timer.new()
	t.wait_time = max(wait, 0.001)
	t.one_shot = false
	t.autostart = autostart
	t.timeout.connect(callback)
	add_child(t)
	return t


# ─────────────────────────────────────────────
#  КОНСОЛЬНЫЕ КОМАНДЫ
# ─────────────────────────────────────────────
func _register_console_commands() -> void:
	var cmds := {
		"creature_count": [_cmd_count, "Count living creatures"],
		"creatures_list":  [_cmd_list,  "List all creatures"],
		"creature_clear":  [_cmd_clear, "Clear creatures: clear [count=0(all)]"],
		"spawn":           [_cmd_spawn, "Spawn specific creature: spawn [index] [count]"],
		"debug_spawn":     [_cmd_debug, "Debug spawn system"],
	}
	for cmd in cmds:
		Global.developer_console.register_command(cmd, cmds[cmd][0], cmds[cmd][1])


func _cmd_count(_args: Array) -> String:
	return "Living creatures: %d/%d" % [_get_alive_count(), max_creatures]


func _cmd_list(_args: Array) -> String:
	return _get_creature_list()


func _cmd_clear(args: Array) -> String:
	var group := get_tree().get_nodes_in_group("Creature")
	var total := group.size()

	if total == 0:
		return "No creatures to clear!"

	var count := total
	if not args.is_empty():
		if not args[0].is_valid_int():
			return "Error: Count must be a number."
		count = int(args[0])
		count = total if count <= 0 else mini(count, total)

	if count == total:
		for c in group:
			if is_instance_valid(c):
				c.queue_free()
		_tracked_creatures.clear()
		_offscreen_tracker.clear()
		return "Cleared ALL %d creatures!" % total

	# Удаляем N ближайших к игроку
	if not is_instance_valid(player):
		return "Player not found!"

	group.sort_custom(func(a, b):
		return player.global_position.distance_to(a.global_position) < \
			   player.global_position.distance_to(b.global_position))

	var cleared := 0
	for i in range(count):
		if is_instance_valid(group[i]):
			_despawn_creature(group[i])
			cleared += 1

	return "Cleared %d closest creatures (of %d total)" % [cleared, total]


func _cmd_spawn(args: Array) -> String:
	if args.is_empty():
		return "Usage: spawn [index] [count]\n" + _get_creature_list()

	if not args[0].is_valid_int():
		return "Error: Index must be a number!\n" + _get_creature_list()

	var index := int(args[0])
	if index < 0 or index >= creatures.size():
		return "Error: Index %d out of range (0-%d)!\n%s" % [index, creatures.size() - 1, _get_creature_list()]

	var cfg := creatures[index]
	if not cfg or not cfg.creature_scene:
		return "Error: Creature #%d has no scene!" % index

	var count := 1
	if args.size() > 1:
		if not args[1].is_valid_int():
			return "Error: Count must be a number!"
		count = int(args[1])
		if count <= 0:
			return "Error: Count must be > 0!"

	var alive := _get_alive_count()
	var available := max_creatures - alive
	if available <= 0:
		return "Cannot spawn — limit (%d) reached!" % max_creatures

	count = mini(count, available)
	for i in count:
		_spawn_single_creature(get_random_position(), cfg)

	return "✅ Spawned %d x %s (limit: %d/%d)" % [
		count,
		cfg.creature_scene.resource_path.get_file().get_basename(),
		alive + count, max_creatures
	]


func _cmd_debug(_args: Array) -> String:
	return "=== SPAWN DEBUG ===\nAlive: %d\nCan spawn: %s\nPhase: %s\nPool: %d" % [
		_get_alive_count(), can_spawn, _get_current_phase(), current_pool.size()
	]


func _get_creature_list() -> String:
	var lines := ["Creatures list:", "Alive: %d/%d\n" % [_get_alive_count(), max_creatures]]
	for i in creatures.size():
		var cfg := creatures[i]
		var nm := "EMPTY" if not cfg else cfg.creature_scene.resource_path.get_file().get_basename()
		lines.append("%d: %s (w=%.1f, phase=%s)" % [i, nm, cfg.spawn_weight if cfg else 0.0, cfg.spawn_phase if cfg else "—"])
	return "\n".join(lines)


func _get_configuration_warnings() -> PackedStringArray:
	var w: PackedStringArray = []
	if not player:
		w.append("Player node is not assigned.")
	if creatures.is_empty():
		w.append("No creature configurations assigned.")
	if spawn_distance_min > spawn_distance_max:
		w.append("spawn_distance_min cannot be greater than spawn_distance_max.")
	for cfg in creatures:
		if not cfg or not cfg.creature_scene:
			w.append("Invalid CreatureConfig: missing scene.")
	return w


# ─────────────────────────────────────────────
#  ПУЛ
# ─────────────────────────────────────────────
func update_pool() -> void:
	var phase := _get_current_phase()
	current_pool = creatures.filter(func(c):
		if not c or not c.creature_scene:
			return false
		match c.spawn_phase:
			"Day":   return phase == "Day"
			"Night": return phase == "Night"
			"Both":  return true
		return false
	)
	if current_pool.is_empty() and not creatures.is_empty():
		push_warning("CreatureSpawner: No creatures match phase '%s'" % phase)


func _get_current_phase() -> String:
	if not is_instance_valid(DayNightCycle):
		return "Day"
	match DayNightCycle.Phase:
		DayNightCycle.Phase.DAY, DayNightCycle.Phase.MIDDAY:
			return "Day"
		DayNightCycle.Phase.NIGHT:
			return "Night"
	return "Day"


# ─────────────────────────────────────────────
#  СПАВН
# ─────────────────────────────────────────────
func _on_spawn_timer_timeout() -> void:
	if not is_active or not is_instance_valid(player) or not can_spawn:
		return

	update_pool()
	if current_pool.is_empty():
		_start_timer_if_possible()
		return

	var count := randi_range(spawn_count_min, spawn_count_max)
	for i in count:
		if not can_spawn:
			break
		var cfg := _select_creature_from_pool(current_pool)
		if cfg:
			_spawn_single_creature(get_random_position(), cfg)

	_start_timer_if_possible()


func _spawn_single_creature(pos: Vector2, cfg: CreatureConfig) -> void:
	var scene := cfg.get_random_scene()
	if not scene:
		return

	var instance := scene.instantiate()
	instance.global_position = pos
	instance.add_to_group("Creature")
	_tracked_creatures.append(instance)
	get_tree().current_scene.add_child(instance)


func _select_creature_from_pool(pool: Array[CreatureConfig]) -> CreatureConfig:
	if pool.is_empty():
		return null
	var total: float = 0.0
	for c in pool:
		total += c.spawn_weight
	if total <= 0.0:
		return pool[0]
	var roll: float = randf() * total
	var sum: float = 0.0
	for c in pool:
		sum += c.spawn_weight
		if roll <= sum:
			return c
	return pool[0]


func get_random_position() -> Vector2:
	if not is_instance_valid(player):
		return global_position
	var angle := randf() * TAU
	var dist  := randf_range(spawn_distance_min, spawn_distance_max)
	return player.global_position + Vector2(cos(angle), sin(angle)) * dist


func _start_timer_if_possible() -> void:
	if not is_active or current_pool.is_empty():
		_spawn_timer.stop()
		return
	_spawn_timer.start(_get_next_spawn_interval())


func _get_next_spawn_interval() -> float:
	var base := randf_range(
		base_spawn_interval - spawn_interval_variation,
		base_spawn_interval + spawn_interval_variation)
	return base / night_spawn_multiplier if _get_current_phase() == "Night" else base


# ─────────────────────────────────────────────
#  ДЕСПАВН
# ─────────────────────────────────────────────
func _physics_process(_delta: float) -> void:
	_track_creatures_visibility()
	_cleanup_tracked()
	can_spawn = _tracked_creatures.size() < max_creatures


func _cleanup_tracked() -> void:
	for i in range(_tracked_creatures.size() - 1, -1, -1):
		if not is_instance_valid(_tracked_creatures[i]):
			_tracked_creatures.remove_at(i)


func _track_creatures_visibility() -> void:
	if not despawn_enabled:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for creature in get_tree().get_nodes_in_group("Creature"):
		if is_instance_valid(creature) and _is_on_screen(creature):
			_offscreen_tracker[creature] = now


func _check_despawn() -> void:
	if not despawn_enabled:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var to_remove: Array[Node] = []

	for creature in _offscreen_tracker.keys():
		if not is_instance_valid(creature):
			to_remove.append(creature)
			continue
		if now - _offscreen_tracker[creature] > time_offscreen_to_despawn:
			to_remove.append(creature)

	for c in to_remove:
		_despawn_creature(c)


func _despawn_creature(creature: Node) -> void:
	_offscreen_tracker.erase(creature)
	if is_instance_valid(creature):
		creature.queue_free()


func _is_on_screen(creature: Node2D) -> bool:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return true

	var screen_pos := camera.get_screen_center_position() + \
		(creature.global_position - camera.global_position) * camera.zoom
	return get_viewport().get_visible_rect().grow(offscreen_margin).has_point(screen_pos)


# ─────────────────────────────────────────────
#  УТИЛИТЫ
# ─────────────────────────────────────────────
func _get_alive_count() -> int:
	var count := 0
	for c in get_tree().get_nodes_in_group("Creature"):
		if is_instance_valid(c):
			count += 1
	return count
