/obj/structure/titanium_structure
	name = "titanium framing"
	desc = "A large skeleton made of titanium steel that makes up the outer structure of most ships"
	icon = '_horizon/code/modules/shipbreaking/icons/smooth/girder_titan.dmi'
	icon_state = "wall"
	anchored = TRUE
	density = TRUE
	rad_insulation = RAD_VERY_LIGHT_INSULATION
	max_integrity = 300

	icon_state = "wall"
	var/list/wall_connections = list("0", "0", "0", "0")
	var/list/blend_turfs = list(/turf/closed)
	var/list/noblend_turfs = list(/turf/closed/mineral, /turf/closed/wall/mineral/titanium)
	var/list/blend_objects = list(/obj/structure/titanium_structure, /obj/machinery/door)
	var/list/noblend_objects = list()
	var/special_icon = TRUE
	smoothing_flags = SMOOTH_CONNECTOR
	smoothing_groups = null
	canSmoothWith = null

	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 7,
	)

/obj/structure/titanium_structure/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_RECYCLE_LIKE_ITEM, TRAIT_GENERIC)
	register_context()

/obj/structure/titanium_structure/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(isnull(held_item))
		return NONE
	if(held_item.tool_behaviour == TOOL_WELDER)
		context[SCREENTIP_CONTEXT_LMB] = anchored ? "Unsecure" : "Secure"
		return CONTEXTUAL_SCREENTIP_SET

/obj/structure/titanium_structure/examine(mob/user)
	. = ..()
	. += span_notice("Can be removed by cutting it off.")

/obj/structure/titanium_structure/welder_act(mob/living/user, obj/item/tool)
	if(!tool.get_temperature() >= FIRE_MINIMUM_TEMPERATURE_TO_EXIST)
		return ITEM_INTERACT_FAILURE
	balloon_alert(user, anchored ? "cutting..." : "securing...")
	if(!tool.use_tool(src, user, 2 SECONDS, amount = 1, volume=50))
		return ITEM_INTERACT_BLOCKING
	set_anchored(!anchored)
	return ITEM_INTERACT_SUCCESS

/obj/structure/titanium_structure/smooth_icon()
	if(!special_icon)
		return ..()
	smoothing_flags &= ~SMOOTH_QUEUED
	update_connections()
	update_icon(~UPDATE_SMOOTHING)

/obj/structure/titanium_structure/update_icon()
	if(!special_icon)
		return ..()
	render_corner_frames(src, wall_connections, WALL_PLANE)

/obj/structure/titanium_structure/proc/update_connections()
	wall_connections = dirs_to_corner_states(scan_blend_dirs(src, blend_turfs, noblend_turfs, blend_objects, noblend_objects))
