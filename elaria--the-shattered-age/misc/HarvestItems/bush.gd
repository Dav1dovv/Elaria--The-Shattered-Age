extends Harvestable
class_name bush

const BERRY = preload("uid://dt3jv77sc1amr")
const BLUE_BERRY = preload("uid://cek8v8e4qeq28")
@warning_ignore("unused_parameter")
func Harvest(hit_strenght : float, tool_lvl:int,is_weapon:bool):
	if tool_lvl >= harvest_tool_lvl:
		$Sprite2D.visible = false
		
		# Обычные ягоды
		if $Sprite2D.frame == 1:
			Dropper_component.drop_item[0] = BERRY
			Dropper_component._drop_items()
		elif $Sprite2D.frame == 2:
			Dropper_component.drop_item[0] = BLUE_BERRY
			Dropper_component._drop_items()
		
		# Визуальные эффекты (в фоне)
		if VFX_component != null:
			VFX_component._hit_vfx($Sprite2D)
			VFX_component._play_particles()
		await VFX_component.paricles_finished
		queue_free()
