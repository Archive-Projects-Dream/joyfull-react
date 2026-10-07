// Это конечно круто, но есть более лучший вариант в модульном виде алгоритма
#define SMOOTH_JUNCTION_NE (1<<4)
#define SMOOTH_JUNCTION_SE (1<<5)
#define SMOOTH_JUNCTION_SW (1<<6)
#define SMOOTH_JUNCTION_NW (1<<7)

GLOBAL_LIST_INIT(base_tiles, list(
	/atom/movable/atom_shadow,
	/obj/machinery/door,
	/obj/structure/grille,
	/obj/structure/window/fulltile,
	/obj/structure/window/reinforced/fulltile,
	/obj/structure/window/reinforced/plasma/fulltile,
	/obj/structure/window/reinforced/tinted/fulltile,
))

GLOBAL_LIST_EMPTY(tiles_with_typecaches)

/proc/tiles_typecache(list/tiles)
	if(!tiles) //defensive: an atom without tiles_with just matches nothing
		return list()
	var/list/typecache = GLOB.tiles_with_typecaches[tiles]
	if(!typecache)
		typecache = typecacheof(tiles)
		GLOB.tiles_with_typecaches[tiles] = typecache
	return typecache

/atom
	var/list/tiles_with
	var/smooth_diagonals = FALSE

/atom/proc/relativewall() //atom because it should be useable both for walls, false walls, doors, windows, etc
	var/junction = 0 //flag used for icon_state
	var/shadow_bits = 0 //cardinal neighbours that carry a shadow mask
	var/list/typecache = tiles_typecache(tiles_with)
	var/turf/turf_check //The turf we are checking

	for(var/first_iterator in GLOB.cardinals) //For all cardinal dir turfs
		turf_check = get_step(src, first_iterator)
		if(!istype(turf_check))
			continue
		var/matched = typecache[turf_check.type]
		if(!matched || smooth_diagonals && !(shadow_bits & first_iterator))
			for(var/atom/third_iterator in turf_check)
				var/is_mask = smooth_diagonals && istype(third_iterator, /atom/movable/atom_shadow)
				if(is_mask)
					shadow_bits |= first_iterator
				if(!matched && (is_mask || typecache[third_iterator.type]))
					matched = TRUE
				if(matched && (!smooth_diagonals || shadow_bits & first_iterator))
					break
		if(matched)
			junction |= first_iterator

	if(smooth_diagonals)
		junction |= relativewall_diagonals(shadow_bits)

	handle_icon_junction(junction)

/atom/proc/relativewall_diagonals(cardinal_shadow_bits)
	var/diagonal_junction = 0
	var/turf/turf_check //The turf we are checking

	for(var/first_iterator in GLOB.diagonals)
		if(cardinal_shadow_bits & (first_iterator & (NORTH|SOUTH)))
			continue //that side of the corner is sealed by a mask
		if(cardinal_shadow_bits & (first_iterator & (EAST|WEST)))
			continue //...or that one
		turf_check = get_step(src, first_iterator)
		if(!istype(turf_check))
			continue
		if(locate(/atom/movable/atom_shadow) in turf_check)
			diagonal_junction |= diagonal_junction_bit(first_iterator)

	return diagonal_junction

/proc/diagonal_junction_bit(diagonal_dir)
	switch(diagonal_dir)
		if(NORTHEAST)
			return SMOOTH_JUNCTION_NE
		if(SOUTHEAST)
			return SMOOTH_JUNCTION_SE
		if(SOUTHWEST)
			return SMOOTH_JUNCTION_SW
		if(NORTHWEST)
			return SMOOTH_JUNCTION_NW
	return 0

/atom/proc/relativewall_neighbours()
	QUEUE_SMOOTH_NEIGHBORS(src)

/atom/proc/handle_icon_junction(junction)
	return

#undef SMOOTH_JUNCTION_NE
#undef SMOOTH_JUNCTION_SE
#undef SMOOTH_JUNCTION_SW
#undef SMOOTH_JUNCTION_NW
