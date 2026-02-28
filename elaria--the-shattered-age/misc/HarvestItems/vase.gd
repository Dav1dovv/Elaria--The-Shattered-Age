extends Harvestable
class_name Jar


@warning_ignore("unused_parameter")
func Harvest(hit_strenght : float, tool_lvl:int,is_weapon:bool):
	if tool_lvl >= harvest_tool_lvl:
		$Sprite2D.visible = false
		
		Dropper_component._drop_items()
		
		# Эффекты
		# Визуальные эффекты (в фоне)
		if VFX_component != null:
			VFX_component._hit_vfx($Sprite2D)
			VFX_component._play_particles()
		await VFX_component.paricles_finished
		
		queue_free()
