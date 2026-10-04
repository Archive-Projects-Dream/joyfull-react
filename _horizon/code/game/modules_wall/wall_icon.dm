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
 * Connector walls ride the SSicon_smooth queue. SMOOTH_CONNECTOR is the queue
 * ticket: every entry into the queue is gated on `smoothing_flags &
 * USES_SMOOTHING` (/turf/Initialize, QUEUE_SMOOTH, QUEUE_SMOOTH_NEIGHBORS),
 * and the same gate drives the UPDATE_SMOOTHING re-queue hooks (shuttle
 * rotation, holodeck and friends). Drop the flag and nothing ever calls
 * update_connections(): at mapload the wall keeps its raw "wall" state, and
 * later neighbour changes never refresh the corners. The standard bitmask
 * semantics never run for these types - smooth_icon() is overridden and
 * never calls ..() - the orange(src, 1) scan below is the payload, not the
 * trigger.
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

/*
 * One pass over the 3x3 neighbourhood: closed neighbours join through
 * can_join_with(), objects only matter on the cardinal sides and only when
 * blend_objects actually lists any.
 */
/turf/closed/proc/update_connections(propagate = 0)
	var/list/wall_dirs = list()

	for(var/turf/T in orange(src, 1))
		if(istype(T, /turf/closed))
			var/turf/closed/W = T
			if(W.type == type || can_join_with(W))
				wall_dirs += get_dir(src, W)
			if(propagate)
				W.update_connections()
				W.update_icon()
			continue
		if(!length(blend_objects) || !(get_dir(src, T) in GLOB.cardinals))
			continue
		for(var/obj/O in T)
			if(is_type_in_list(O, noblend_objects))
				continue
			if(is_type_in_list(O, blend_objects))
				wall_dirs += get_dir(src, T)
				break

	wall_connections = dirs_to_corner_states(wall_dirs)

/// Closed-turf blending: same type always joins; otherwise the blend lists
/// decide, noblend has priority over blend, subtypes included.
/turf/closed/proc/can_join_with(turf/closed/W)
	if(W.type == type)
		return TRUE
	if(is_type_in_list(W, noblend_turfs))
		return FALSE
	return is_type_in_list(W, blend_turfs)

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
		I = image(icon, corner_icon_state(wall_connections[i]), dir = 1<<(i-1))
		I.plane = GAME_PLANE
		overlays += I
