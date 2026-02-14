extends Harvestable
class_name Jar

const CARROT = preload("uid://cepvea5f7ye50")
const COAL = preload("uid://3t12hy0spmto")
const COOPER_IGNOT = preload("uid://c3o6pp1k5aepu")
const GOLDEN_PIECES = preload("uid://6hqyjr5dpe37")
const HEAL_DRINK = preload("uid://dhkudefnl5evg")
const PORTAL_ENERGY = preload("uid://depne451jnfse")

@warning_ignore("unused_parameter")
func Harvest(hit_strenght : float, tool_lvl:int,is_weapon:bool):
	if tool_lvl >= harvest_tool_lvl:
		$Sprite2D.visible = false
		
		# Рандомный дроп
		var roll = randf()
		if roll < 0.1:
			Dropper_component.drop_item[0] = PORTAL_ENERGY
			Dropper_component._drop_items()
		elif roll < 0.3:  # 0.1 + 0.2
			Dropper_component.drop_item[0] = COAL
			Dropper_component._drop_items()
		elif roll < 0.38: # 0.3 + 0.08
			Dropper_component.drop_item[0] = COOPER_IGNOT
			Dropper_component._drop_items()
		elif roll < 0.42: # 0.38 + 0.04
			Dropper_component.drop_item[0] = GOLDEN_PIECES
			Dropper_component._drop_items()
		elif roll < 0.48: # 0.42 + 0.06
			Dropper_component.drop_item[0] = HEAL_DRINK
			Dropper_component._drop_items()
		
		# Эффекты
		# Визуальные эффекты (в фоне)
		if VFX_component != null:
			VFX_component._hit_vfx($Sprite2D)
			VFX_component._play_particles()
		await VFX_component.paricles_finished
		
		queue_free()
