/// Manual colony doors: slowly actuated, non-powered airlocks made from a parts kit.
/// Ported from NovaSector (modular_nova/modules/colony_fabricator/code/construction/manual_door.dm) as a
/// dependency of the shipbreaking shuttle airlocks, which extend this type.
/// The flatpacked machine base from NovaSector's colony_fabricator (colony_fabricator.dm) is included here
/// so the door's parts kit can be deployed; it uses the local deployable component.
/obj/structure/mineral_door/manual_colony_door
	name = "manual airlock"
	icon = '_horizon/code/modules/shipbreaking/icons/airlock_manual.dmi'
	material_flags = NONE
	icon_state = "manual"
	openSound = '_horizon/code/modules/shipbreaking/sound/manual_door/manual_door_open.wav'
	closeSound = '_horizon/code/modules/shipbreaking/sound/manual_door/manual_door_close.wav'
	/// What we disassemble into
	var/disassembled_type = /obj/item/flatpacked_machine/airlock_kit_manual
	/// How long it takes to open/close the door
	var/manual_actuation_delay = 1 SECONDS

/obj/structure/mineral_door/manual_colony_door/atom_deconstruct(disassembled = TRUE)
	if(disassembled)
		new disassembled_type(get_turf(src))

// Pickaxes won't dig these apart
/obj/structure/mineral_door/manual_colony_door/pickaxe_door(mob/living/user, obj/item/item_in_question)
	return

// These doors have a short do_after to check if you can open or close them
/obj/structure/mineral_door/manual_colony_door/TryToSwitchState(atom/user)
	if(isSwitchingStates || !anchored)
		return
	if(!do_after(user, manual_actuation_delay, src))
		return
	return ..()

// We don't care about being bumped, these doors have to be actuated manually
/obj/structure/mineral_door/manual_colony_door/Bumped(atom/movable/bumped_atom)
	return

// Parts kit for putting the door together

/// Base type for "parts kit" items that deploy into a structure or machine after a delay.
/// Ported from NovaSector's colony_fabricator flatpack system; uses the deployable component.
/obj/item/flatpacked_machine
	name = "flat-packed rapid construction fabricator"
	desc = "A compactly packed kit of parts, panels and fasteners for building something much bigger than the box it comes in."
	icon = '_horizon/code/modules/shipbreaking/icons/packed_machines.dmi'
	icon_state = "colony_lathe_packed"
	w_class = WEIGHT_CLASS_BULKY
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 7.5,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2.5,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/silver = HALF_SHEET_MATERIAL_AMOUNT,
	)
	/// What structure is created by this item.
	var/obj/type_to_deploy
	/// How long it takes to create the structure in question.
	var/deploy_time = 4 SECONDS

/obj/item/flatpacked_machine/Initialize(mapload)
	. = ..()
	if(!type_to_deploy)
		return INITIALIZE_HINT_QDEL
	AddComponent(/datum/component/deployable, deploy_time, type_to_deploy)

/obj/item/flatpacked_machine/airlock_kit_manual
	name = "prefab manual airlock parts kit"
	desc = /obj/structure/mineral_door/manual_colony_door::desc
	icon = '_horizon/code/modules/shipbreaking/icons/doors_packed.dmi'
	icon_state = "airlock_parts_manual"
	type_to_deploy = /obj/structure/mineral_door/manual_colony_door
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 2,
	)
	w_class = WEIGHT_CLASS_NORMAL
