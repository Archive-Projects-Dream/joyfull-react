// MARK: Окна

/obj/structure/window/reinforced/shuttle
	icon = '_horizon/icons/obj/smooth_structures/shuttle_window.dmi'
	plane = ABOVE_WALL_PLANE
	smoothing_flags = SMOOTH_BITMASK | SMOOTH_DIAGONAL_CORNERS
	smoothing_groups = SMOOTH_GROUP_TITANIUM_WALLS + SMOOTH_GROUP_WALLS + SMOOTH_GROUP_CLOSED_TURFS
	canSmoothWith = SMOOTH_GROUP_SHUTTLE_PARTS + SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_TITANIUM_WALLS

/obj/structure/window/reinforced/plasma/plastitanium
	icon = '_horizon/icons/obj/smooth_structures/plastitanium_window.dmi'
	plane = ABOVE_WALL_PLANE

/obj/structure/window/reinforced/fulltile
	icon = '_horizon/icons/obj/smooth_structures/reinforced_window.dmi'
	icon_state = "wall"
	plane = ABOVE_WALL_PLANE
	smoothing_flags = SMOOTH_CONNECTOR
	smoothing_groups = null
	canSmoothWith = null
	var/special_icon = TRUE
	var/list/wall_connections = list("0", "0", "0", "0")
	/// Objects the glass blends with cardinally - mirrors the wall's blend_objects.
	var/list/blend_objects = list(/obj/structure/window/reinforced/fulltile, /obj/structure/window/framed, /obj/structure/window_frame, /obj/machinery/door)
	var/list/noblend_objects = list()

/*
	 * The glass twin of the wall's connector: one scan feeds the four
	 * corner frames. A turf is accepted by the wall's own blend list -
	 * whatever merges with the glass, the glass merges with back, so a
	 * junction one side draws, the other draws too. Objects blend
	 * cardinally only: the family and the doors.
	 */
/obj/structure/window/reinforced/fulltile/smooth_icon()
	if(!special_icon)
		return ..()
	smoothing_flags &= ~SMOOTH_QUEUED
	update_connections()
	update_icon(~UPDATE_SMOOTHING)

/obj/structure/window/reinforced/fulltile/proc/update_connections()
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

/obj/structure/window/reinforced/fulltile/update_icon()
	. = ..()
	if(!special_icon)
		return

	overlays.Cut()
	icon_state = "blank"

	for(var/i in 1 to 4)
		overlays += get_wall_object(icon, corner_icon_state(wall_connections[i]), 1<<(i-1), plane = WALL_PLANE, offset_spokesman = src)

// the vanilla rice sheet has no wall states
/obj/structure/window/reinforced/fulltile/ice
	special_icon = FALSE
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_WALLS
	canSmoothWith = SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_WALLS

/obj/structure/window/fulltile
	icon = '_horizon/icons/obj/smooth_structures/window.dmi'
	plane = ABOVE_WALL_PLANE

/obj/structure/window/plasma/fulltile
	icon = '_horizon/icons/obj/smooth_structures/plasma_window.dmi'
	plane = ABOVE_WALL_PLANE

/obj/structure/window/reinforced/plasma/fulltile
	icon = '_horizon/icons/obj/smooth_structures/rplasma_window.dmi'
	plane = ABOVE_WALL_PLANE

/turf/closed/indestructible/fakeglass
	icon = MAP_SWITCH('_horizon/icons/obj/smooth_structures/reinforced_window.dmi', 'icons/obj/smooth_structures/structure_variations.dmi')
	plane = ABOVE_WALL_PLANE
	smoothing_groups = SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_WALLS
	canSmoothWith = SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_WALLS
