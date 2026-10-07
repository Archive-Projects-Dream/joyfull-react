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

// MARK: Wall
/turf/closed/wall/smooth_icon()
	if(!special_icon)
		return ..() //standard bitmask walls keep their normal smoothing
	smoothing_flags &= ~SMOOTH_QUEUED
	update_connections()
	update_icon()

/turf/closed/mineral/smooth_icon()
	smoothing_flags &= ~SMOOTH_QUEUED
	update_connections()
	update_icon()

/turf/closed/wall/update_icon()
	. = ..()
	if(!special_icon)
		return

	overlays.Cut()
	icon_state = "blank"

	for(var/i in 1 to 4)
		overlays += get_wall_object(icon, corner_icon_state(wall_connections[i]), 1<<(i-1), plane = WALL_PLANE, offset_spokesman = src)

	shadow.shadow_connections = wall_connections
	shadow.update_icon()

/turf/closed/proc/corner_icon_state(corner)
	if(diagonal && (corner == "0" || corner == "5"))
		return "wall[corner]-diagonal"
	return "wall[corner]"

/turf/closed/proc/update_connections()
	var/list/wall_dirs = list()
	for(var/turf/T in orange(src, 1))
		if(istype(T, /turf/closed))
			var/turf/closed/W = T
			if(W.type == type || can_join_with(W))
				wall_dirs += get_dir(src, W)
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

/turf/closed/mineral/update_icon()
	. = ..()
	if(!special_icon)
		return

	overlays.Cut()
	icon_state = "blank"

	for(var/i in 1 to 4)
		overlays += get_wall_object(icon, corner_icon_state(wall_connections[i]), 1<<(i-1), plane = GAME_PLANE, offset_spokesman = src)

// MARK: Shadow
/atom/movable/atom_shadow/update_icon()
	. = ..()

	overlays.Cut()
	icon_state = "blank"

	for(var/i in 1 to 4)
		overlays += get_wall_object(icon, "wall[shadow_connections[i]]", 1<<(i-1), plane = ATOMS_FOV_SHADOWS_PLANE, offset_spokesman = src)
