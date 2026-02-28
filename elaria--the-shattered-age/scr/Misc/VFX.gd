extends Node
class_name VFX

signal vfx_finished
signal paricles_finished

@export var audio_player : AudioStreamPlayer2D
@export var particles : GPUParticles2D

func _hit_vfx(target: Node) -> void:
	if audio_player:
		audio_player.play()
	_play_particles()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(target, "rotation", randf_range(-0.2, 0.2), 0.1)
	tween.tween_property(target, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(target, "rotation", 0.0, 0.1).set_delay(0.1)
	tween.tween_property(target, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.1)
	tween.tween_callback(vfx_finished.emit)


func _damage_vfx(target: Node):
	if audio_player: 
		audio_player.play()
	_play_particles()
	var tween = create_tween()
	tween.tween_property(target, "rotation", randf_range(-0.2, 0.2), 0.1)
	await tween.tween_property(target, 'modulate', Color(1.219, 0.0, 0.0, 1.0), 0.1)
	tween.tween_property(target, 'modulate', Color.WHITE, 0.3)
	tween.tween_property(target, "rotation", 0.0, 0.1).set_delay(0.1)


func _play_particles():
	if particles == null:
		paricles_finished.emit()
		return
	
	particles.restart()
	particles.emitting = true
	
	# ЖДЁМ, пока частицы закончатся
	while particles.emitting:
		await get_tree().process_frame  # Ждём кадр
	
	# Дополнительно: ждём, пока все частицы исчезнут
	await get_tree().create_timer(particles.lifetime).timeout
	
	paricles_finished.emit()  # Только теперь!
