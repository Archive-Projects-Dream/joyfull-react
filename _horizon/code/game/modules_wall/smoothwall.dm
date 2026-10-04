//Separate dm because it relates to two types of atoms + ease of removal in case it's needed.
//Also assemblies.dm for falsewall checking for this when used.
//I should really make the shuttle wall check run every time it's moved, but centcom uses unsimulated floors so !effort

//Junction bits for diagonal (corner-cut) links. Cardinal bits keep the BYOND
//dir values (NORTH=1, SOUTH=2, EAST=4, WEST=8), diagonals take the high nibble,
//so handle_icon_junction() can keep using one plain number for icon_state.
#define SMOOTH_JUNCTION_NE (1<<4)
#define SMOOTH_JUNCTION_SE (1<<5)
#define SMOOTH_JUNCTION_SW (1<<6)
#define SMOOTH_JUNCTION_NW (1<<7)

/*
 * The shared "second type" neighbour set: everything that tiles cardinally
 * with walls and their masks. ONE list instance for the whole world - the
 * typecache built by tiles_typecache() is keyed by list identity, so a
 * shared instance also means a single shared cache entry.
 */
GLOBAL_LIST_INIT(base_tiles, list(
	/atom/movable/atom_shadow,
	/obj/machinery/door,
	/obj/structure/grille,
	/obj/structure/window/fulltile,
	/obj/structure/window/reinforced/fulltile,
	/obj/structure/window/reinforced/plasma/fulltile,
	/obj/structure/window/reinforced/tinted/fulltile,
))

/// Same trick for the simple walls - they only ever tile with themselves.
GLOBAL_LIST_INIT(simple_wall_tiles, list(/turf/closed/wall/simple))

/// tiles_with list instance -> assoc typecache (every subtype -> TRUE).
/// Turns the old "istype() per path per neighbour per direction" chain into
/// one O(1) hash lookup per atom we look at.
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
	//A list of paths only that each turf should tile with
	var/list/tiles_with
	/// When TRUE, relativewall() also computes diagonal (corner-cut) links.
	/// Everything in tiles_with connects cardinally, but only atoms that
	/// carry a shadow mask (walls, opaque doors) actually seal a corner:
	/// glass doors, windows and grilles keep it open, so masks meeting
	/// across such a neighbour have to bridge it with a diagonal link.
	var/smooth_diagonals = FALSE

/*
 * Recompute our junction from the four cardinal neighbours.
 *
 * Scheduling: don't call this from Initialize - ride the SSicon_smooth queue
 * instead. Set smoothing_flags = SMOOTH_BITMASK_CARDINALS on the type (it is
 * only a queue ticket, the standard bitmask code never runs for us) and
 * override smooth_icon() to call this. The queue batches work, deduplicates
 * cascades through the SMOOTH_QUEUED bit and spreads the drain across ticks,
 * which kills both the "everyone refreshes everyone at mapload" cascade and
 * the single-frame LateInitialize pileup on runtime template loads.
 *
 * Matching: one typecache lookup per candidate. The old loop rescanned every
 * neighbour's contents once per path in tiles_with (4 dirs x 7 paths = 28
 * full contents scans) and its break only left the innermost loop, so a hit
 * on the first path still paid for the remaining six. We now do a single
 * contents pass per direction and bail out the moment we have everything.
 *
 * While we are in there (only when smooth_diagonals is on) we also note
 * which cardinals carry an /atom/movable/atom_shadow, so the diagonal pass
 * below can test sealed corners with bit ops instead of locate()ing again.
 */
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

/*
 * Diagonal (corner-cut) junction bits, for masks that must stay connected when
 * two runs meet without a sealing corner tile:
 *
 *      ..#..             ..#..
 *      --...     ->      --%.. (% = diagonal link, drawn by BOTH shadows)
 *
 * A corner only counts as sealed when one of its two cardinal sides carries a
 * real shadow mask (a wall or an opaque door). Glass doors, windows and
 * grilles are second-type connections: they tile cardinally like everything
 * else in BASED_TILES, but they cast no shadow of their own, so the corner
 * behind them stays open and the two masks have to bridge it diagonally.
 *
 * `cardinal_shadow_bits` comes from the cardinal pass above. NORTHEAST is
 * literally NORTH|EAST, so one & per side splits a diagonal back into its
 * cardinal components - no locate()s needed for the seal test anymore.
 */
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
