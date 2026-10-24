/obj/item/circuitboard/machine/recycler/refiner
	name = "Refiner"
	build_path = /obj/machinery/recycler/refiner
	req_components = list(
		/datum/stock_part/micro_laser = 3)

/datum/design/board/recycler/refiner
	name = "Refiner Board"
	desc = "Used to build a refiner."
	build_path = /obj/machinery/recycler/refiner

/obj/machinery/recycler/refiner
	name = "Refiner"
	obj_flags = EMAGGED
	circuit = /obj/item/circuitboard/machine/recycler/refiner
	icon = '_horizon/code/modules/shipbreaking/icons/refiner.dmi'
	icon_state = "refiner"
	base_icon_state = "refiner"
	amount_produced = 80
	crush_damage = 1000
	light_range = 2
	light_power = 4

/obj/machinery/recycler/refiner/RefreshParts()
	. = ..()
	var/amt_made = 0
	for(var/datum/stock_part/micro_laser/micro_laser in component_parts)
		amt_made = 10 * micro_laser.tier //% of materials salvaged
	amount_produced = min(50, amt_made) + 80

/obj/machinery/recycler/refiner/crush_living(mob/living/living_mob)
	if(issilicon(living_mob))
		playsound(src, 'sound/items/tools/welder.ogg', 50, TRUE)
	else
		playsound(src, 'sound/effects/splat.ogg', 50, TRUE)

	if(iscarbon(living_mob) && !IS_UNCONSCIOUS_OR_CRIT(living_mob))
		living_mob.say("RRRRGGGGGHHHHHHHHHHH!!!", forced= "recycler grinding")

	living_mob.Unconscious(100)
	living_mob.adjust_fire_loss(crush_damage)
	living_mob.adjust_fire_stacks(10)
	living_mob.ignite_mob()

/obj/machinery/recycler/refiner/mapper
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | FIRE_PROOF | ACID_PROOF | LAVA_PROOF

/obj/machinery/recycler/refiner/mapper/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/tool_blocker, TOOL_SCREWDRIVER, TOOL_ACT_PRIMARY)
	AddElement(/datum/element/tool_blocker, TOOL_CROWBAR, TOOL_ACT_PRIMARY)
	AddElement(/datum/element/tool_blocker, TOOL_WRENCH, TOOL_ACT_PRIMARY)

/obj/machinery/recycler/refiner/mapper/r
	icon_state = "refiner_r"
	base_icon_state = "refiner_r"

/obj/machinery/recycler/refiner/mapper/l
	icon_state = "refiner_l"
	base_icon_state = "refiner_l"

/obj/machinery/recycler/refiner/mapper/c
	icon_state = "refiner_c"
	base_icon_state = "refiner_c"
