/mutable_appearance/frill
	appearance_flags = TILE_BOUND | RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM

/proc/get_wall_object(icon, icon_state, dir = 2, pixel_x = 0, pixel_y = 0, plane = GAME_PLANE, layer = ABOVE_MOB_LAYER, atom/offset_spokesman)
	var/mutable_appearance/frill/vis = new()
	vis.icon = icon
	vis.icon_state = icon_state
	vis.pixel_x = pixel_x
	vis.pixel_y = pixel_y
	vis.layer = layer
	if(isatom(offset_spokesman))
		SET_PLANE_EXPLICIT(vis, plane, offset_spokesman)
	else
		vis.plane = plane
	return make_mutable_appearance_directional(vis, dir)

/*
 * Connector walls ride the SSicon_smooth queue: /turf/Initialize queues every
 * USES_SMOOTHING turf, and these overrides do the connection rebuild once
 * the whole map exists (at mapload) or under the tick budget (at runtime).
 * SMOOTH_BITMASK_CARDINALS on the special_icon types is just the queue ticket.
 */
/turf/closed/wall/smooth_icon()
	if(!special_icon)
		return ..() //standard bitmask walls keep their normal smoothing
	smoothing_flags &= ~SMOOTH_QUEUED
	update_connections(FALSE)
	update_icon()

/turf/closed/mineral/smooth_icon()
	smoothing_flags &= ~SMOOTH_QUEUED
	update_connections(FALSE)
	update_icon()

/turf/closed/wall/update_icon()
	. = ..()
	if(!special_icon)
		return

	overlays.Cut()
	icon_state = "blank"

	for(var/i in 1 to 4)
		overlays += get_wall_object(icon, corner_icon_state(wall_connections[i]), 1<<(i-1), plane = WALL_PLANE, offset_spokesman = src)

GLOBAL_LIST_EMPTY(closed_blend_caches)

/turf/closed/proc/blend_caches()
	var/list/caches = GLOB.closed_blend_caches[type]
	if(!caches)
		caches = list(
			"blend_turfs" = typecacheof(blend_turfs),
			"noblend_turfs" = typecacheof(noblend_turfs),
			"blend_objects" = typecacheof(blend_objects),
			"noblend_objects" = typecacheof(noblend_objects),
		)
		GLOB.closed_blend_caches[type] = caches
	return caches

/*
 * One pass over the 3x3 neighbourhood instead of the old two orange() scans:
 * closed neighbours join through can_join_with() (inlined below, same
 * semantics), objects only matter on the cardinal sides. Blend matching is
 * a typecache lookup per atom rather than an istype() per blend path.
 */
/turf/closed/proc/update_connections(propagate = 0)
	var/list/wall_dirs = list()
	var/list/caches = blend_caches()
	var/list/blend_turfs = caches["blend_turfs"]
	var/list/noblend_turfs = caches["noblend_turfs"]
	var/list/blend_objects = caches["blend_objects"]
	var/list/noblend_objects = caches["noblend_objects"]
	var/cardinal_only

	for(var/turf/T in orange(src, 1))
		cardinal_only = get_dir(src, T) in GLOB.cardinals
		if(istype(T, /turf/closed))
			var/turf/closed/W = T
			if(W.type == type || !(noblend_turfs[W.type]) && blend_turfs[W.type])
				wall_dirs += get_dir(src, W)
			if(propagate)
				W.update_connections()
				W.update_icon()
			continue
		if(!cardinal_only)
			continue
		for(var/obj/O in T)
			if(noblend_objects[O.type])
				continue
			if(blend_objects[O.type])
				wall_dirs += get_dir(src, T)
				break

	wall_connections = dirs_to_corner_states(wall_dirs)

#define CORNER_NONE 0
#define CORNER_COUNTERCLOCKWISE 1
#define CORNER_DIAGONAL 2
#define CORNER_CLOCKWISE 4

/proc/dirs_to_corner_states(list/dirs)
	if(!istype(dirs))
		return

	var/list/ret = list(NORTHWEST, SOUTHEAST, NORTHEAST, SOUTHWEST)

	for(var/i = 1 to length(ret))
		var/dir = ret[i]
		. = CORNER_NONE
		if(dir in dirs)
			. |= CORNER_DIAGONAL
		if(turn(dir,45) in dirs)
			. |= CORNER_COUNTERCLOCKWISE
		if(turn(dir,-45) in dirs)
			. |= CORNER_CLOCKWISE
		ret[i] = "[.]"

	return ret

#undef CORNER_NONE
#undef CORNER_COUNTERCLOCKWISE
#undef CORNER_DIAGONAL
#undef CORNER_CLOCKWISE

/*
 * Connector walls: corner state -> overlay icon state name. Types with
 * diagonal = TRUE swap the isolated corner (0) and the L-junction corner
 * (5) for the smoother -diagonal variants.
 */
/turf/closed/proc/corner_icon_state(corner)
	if(diagonal && (corner == "0" || corner == "5"))
		return "wall[corner]-diagonal"
	return "wall[corner]"

/turf/closed/mineral/update_icon()
	. = ..()
	if(!special_icon)
		return

	overlays.Cut()
	icon_state = "blank"
	var/image/I
	for(var/i in 1 to 4)
		I = image(icon, "wall[wall_connections[i]]", dir = 1<<(i-1))
		I.plane = GAME_PLANE
		overlays += I
