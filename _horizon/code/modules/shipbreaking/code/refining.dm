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
	amount_produced = 100
	crush_damage = 10000
	light_range = 2
	light_power = 4

/obj/machinery/recycler/RefreshParts()
	. = ..()
	amount_produced = 100

/obj/machinery/recycler/crush_living(mob/living/living_mob)
	if(issilicon(living_mob))
		playsound(src, 'sound/items/tools/welder.ogg', 50, TRUE)
	else
		playsound(src, 'sound/effects/splat.ogg', 50, TRUE)

	if(iscarbon(living_mob) && !IS_UNCONSCIOUS_OR_CRIT(living_mob))
		living_mob.say("RRRRGGGGGHHHHHHHHHHH!!!", forced= "recycler grinding")

	living_mob.Unconscious(100)
	living_mob.adjust_fire_loss(crush_damage)

/obj/machinery/recycler/refiner/mapper
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE

/obj/machinery/recycler/refiner/mapper/r
	icon_state = "refiner_r"
	base_icon_state = "refiner_r"

/obj/machinery/recycler/refiner/mapper/l
	icon_state = "refiner_l"
	base_icon_state = "refiner_l"

/obj/machinery/recycler/refiner/mapper/c
	icon_state = "refiner_c"
	base_icon_state = "refiner_c"
