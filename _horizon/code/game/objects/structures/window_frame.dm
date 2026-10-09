/*
 * The CM13-style framed windows: glass that keeps its frame.
 *
 * Taking the glass out - clean or shattered - always leaves the frame in
 * the wall opening, junctions and all. Two fresh sheets build the window
 * back into the frame; a wrench takes the frame itself apart into metal.
 * The glass is bolted in for good: it cannot be unanchored and carried off.
 */

/obj/structure/window/framed
	name = "framed window"
	desc = "A glass window with a rod matrix inside a wall frame. It looks rather strong. Might take a few good hits to shatter it."
	icon = '_horizon/icons/obj/smooth_structures/reinforced_window.dmi'
	icon_state = "wall"
	plane = ABOVE_WALL_PLANE
	smoothing_flags = SMOOTH_CONNECTOR
	smoothing_groups = null
	canSmoothWith = null
	fulltile = TRUE
	flags_1 = PREVENT_CLICK_UNDER_1
	obj_flags = CAN_BE_HIT
	reinf = TRUE
	heat_resistance = 1600
	max_integrity = 150
	damage_deflection = 11
	explosion_block = 1
	state = RWINDOW_SECURE
	armor_type = /datum/armor/window_reinforced
	glass_type = /obj/item/stack/sheet/rglass
	glass_amount = 2
	custom_materials = list(/datum/material/glass = SHEET_MATERIAL_AMOUNT * 2, /datum/material/iron = SHEET_MATERIAL_AMOUNT)
	var/special_icon = TRUE
	var/list/wall_connections = list("0", "0", "0", "0")
	/// Objects the glass blends with cardinally - mirrors the wall's blend_objects.
	var/list/blend_objects = list(/obj/structure/window/reinforced/fulltile, /obj/structure/window/framed, /obj/structure/window_frame, /obj/machinery/door)
	var/list/noblend_objects = list(/obj/machinery/door/airlock/public/glass)
	/// The frame left in the opening whenever the glass goes.
	var/window_frame = /obj/structure/window_frame

/*
 * The glass twin of the wall's connector, the same one the reinforced
 * fulltile runs: one scan feeds the four corner frames.
 */
/obj/structure/window/framed/smooth_icon()
	if(!special_icon)
	        return ..()
	smoothing_flags &= ~SMOOTH_QUEUED
	update_connections()
	update_icon(~UPDATE_SMOOTHING)

/obj/structure/window/framed/proc/update_connections()
	var/list/wall_dirs = list()
	for(var/turf/T in orange(src, 1))
	        var/dir = get_dir(src, T)
	        if(istype(T, /turf/closed))
	                var/turf/closed/W = T
	                if((dir in GLOB.cardinals) && !is_type_in_list(src, W.noblend_objects) && is_type_in_list(src, W.blend_objects))
	                        wall_dirs += dir
	                continue
	        if(dir in GLOB.cardinals) // objects blend cardinally only
	                for(var/obj/O in T)
	                        if(is_type_in_list(O, noblend_objects))
	                                continue
	                        if(is_type_in_list(O, blend_objects))
	                                wall_dirs += dir
	                                break
	wall_connections = dirs_to_corner_states(wall_dirs)

/obj/structure/window/framed/update_icon()
	. = ..()
	if(!special_icon)
	        return

	overlays.Cut()
	icon_state = "blank"

	for(var/i in 1 to 4)
	        overlays += get_wall_object(icon, corner_icon_state(wall_connections[i]), 1<<(i-1), plane = WALL_PLANE, offset_spokesman = src)

/// The glass is bolted into the frame for good - it only ever comes out the hard way.
/obj/structure/window/framed/screwdriver_act(mob/living/user, obj/item/tool)
	to_chat(user, span_warning("[src] is bolted into its frame. It cannot be moved."))
	return ITEM_INTERACT_SUCCESS

/obj/structure/window/framed/wrench_act(mob/living/user, obj/item/tool)
	to_chat(user, span_warning("[src] is bolted into its frame. It cannot be moved."))
	return ITEM_INTERACT_SUCCESS

/obj/structure/window/framed/crowbar_act(mob/living/user, obj/item/tool)
	to_chat(user, span_warning("[src] is bolted into its frame. It cannot be moved."))
	return ITEM_INTERACT_SUCCESS

/// Any way the glass goes, the frame stays behind.
/obj/structure/window/framed/atom_deconstruct(disassembled = TRUE)
	if(window_frame)
	        new window_frame(loc)
	        window_frame = null
	return ..()

/*
 * The frame: a hole in the wall that used to sport a large window.
 */

/obj/structure/window_frame
	name = "window frame"
	desc = "A big hole in the wall that used to sport a large window. Can be vaulted through."
	icon = '_horizon/icons/obj/smooth_structures/window_frame.dmi'
	icon_state = "wall"
	plane = ABOVE_WALL_PLANE
	layer = ABOVE_OBJ_LAYER
	density = TRUE
	anchored = TRUE
	pass_flags_self = LETPASSTHROW
	can_atmos_pass = ATMOS_PASS_YES
	max_integrity = 600
	armor_type = /datum/armor/structure_window
	smoothing_flags = SMOOTH_CONNECTOR
	smoothing_groups = null
	canSmoothWith = null
	var/special_icon = TRUE
	var/list/wall_connections = list("0", "0", "0", "0")
	/// Objects the frame blends with cardinally - mirrors the wall's blend_objects.
	var/list/blend_objects = list(/obj/structure/window/reinforced/fulltile, /obj/structure/window/framed, /obj/structure/window_frame, /obj/machinery/door)
	var/list/noblend_objects = list(/obj/machinery/door/airlock/public/glass)
	/// The window built back into the frame once it is fed glass.
	var/window_type = /obj/structure/window/framed
	/// The sheets the window is rebuilt from, and how many it takes.
	var/glass_type = /obj/item/stack/sheet/rglass
	var/glass_amount = 2

/obj/structure/window_frame/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/climbable)

/obj/structure/window_frame/Destroy()
	set_density(FALSE)
	air_update_turf(TRUE, FALSE)
	return ..()

/*
 * The frame runs the same connector twin: one scan feeds the four corner
 * frames, the empty hole edition.
 */
/obj/structure/window_frame/smooth_icon()
	if(!special_icon)
	        return ..()
	smoothing_flags &= ~SMOOTH_QUEUED
	update_connections()
	update_icon(~UPDATE_SMOOTHING)

/obj/structure/window_frame/proc/update_connections()
	var/list/wall_dirs = list()
	for(var/turf/T in orange(src, 1))
	        var/dir = get_dir(src, T)
	        if(istype(T, /turf/closed))
	                var/turf/closed/W = T
	                if((dir in GLOB.cardinals) && !is_type_in_list(src, W.noblend_objects) && is_type_in_list(src, W.blend_objects))
	                        wall_dirs += dir
	                continue
	        if(dir in GLOB.cardinals) // objects blend cardinally only
	                for(var/obj/O in T)
	                        if(is_type_in_list(O, noblend_objects))
	                                continue
	                        if(is_type_in_list(O, blend_objects))
	                                wall_dirs += dir
	                                break
	wall_connections = dirs_to_corner_states(wall_dirs)

/obj/structure/window_frame/update_icon()
	. = ..()
	if(!special_icon)
	        return

	overlays.Cut()
	icon_state = "blank"

	for(var/i in 1 to 4)
	        overlays += get_wall_object(icon, corner_icon_state(wall_connections[i]), 1<<(i-1), plane = WALL_PLANE, offset_spokesman = src)

/// Two fresh sheets build the window back in; the frame hands its tile over.
/obj/structure/window_frame/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, glass_type))
	        return NONE
	var/obj/item/stack/sheets = tool
	if(sheets.get_amount() < glass_amount)
	        balloon_alert(user, "need [glass_amount] sheets!")
	        return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "installing window...")
	add_fingerprint(user)
	if(!tool.use_tool(src, user, 2 SECONDS, glass_amount))
	        return ITEM_INTERACT_BLOCKING
	playsound(src, 'sound/items/deconstruct.ogg', 50, TRUE)
	balloon_alert(user, "window installed")
	new window_type(loc)
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/// The frame itself comes apart into metal.
/obj/structure/window_frame/wrench_act(mob/living/user, obj/item/tool)
	balloon_alert(user, "deconstructing frame...")
	if(!tool.use_tool(src, user, 3 SECONDS, volume = 75))
	        return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "frame deconstructed")
	deconstruct()
	return ITEM_INTERACT_SUCCESS

/obj/structure/window_frame/atom_deconstruct(disassembled = TRUE)
	if(disassembled)
	        new /obj/item/stack/sheet/iron(drop_location(), 2)
	else
	        var/remains = pick(/obj/item/stack/rods, /obj/item/stack/sheet/iron)
	        new remains(drop_location())
