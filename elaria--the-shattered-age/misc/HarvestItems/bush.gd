extends Harvestable
class_name bush

const BERRY = preload("uid://chdqxydwrh23b")
const BLUE_BERRY = preload("uid://dy2f7lngs5n8o")
const PORTAL_ENERGY = preload("uid://depne451jnfse")

@warning_ignore("unused_parameter")
func Harvest(hit_strenght : float, tool_lvl:int,is_weapon:bool):
	if tool_lvl >= harvest_tool_lvl:
		$Sprite2D.visible = false
		
		# Дроп PORTAL_ENERGY с задержкой
		if randf() < 0.05:
			Dropper_component.drop_item[0] = PORTAL_ENERGY
			Dropper_component._drop_items()
			await get_tree().create_timer(0.5)
		
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
