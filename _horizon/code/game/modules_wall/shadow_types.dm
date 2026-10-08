// MARK: Shadow-atom
/atom/movable/atom_shadow
	name = "shadow"
	icon = '_horizon/icons/obj/modular_shadow.dmi'
	icon_state = "wall"
	anchored = TRUE
	plane = ATOMS_FOV_SHADOWS_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/list/shadow_connections = list("0", "0", "0", "0")
	/// Corners carrying a wall2 pipe on top of the base state - the glass diagonal rule fills this.
	var/list/diag_connections = list()

/*
	 * The wall has already done the junction math - update_connections()
	 * hands its corner list over, glass included; the shadow just renders
	 * it. The only thing it computes on its own is the glass diagonal
	 * rule: where the wall merges with glass, the two diagonals hugging
	 * that glass side are checked for another mask - the corner the
	 * cardinal scan can't reach. Every mask found there gets a wall2 pipe
	 * on top of the corner, and the shadows link around the glass instead
	 * of stopping dead at it.
	 */
/atom/movable/atom_shadow/proc/update_diagonals()
	var/turf/closed/parent = loc
	if(!istype(parent))
		return
	diag_connections = list()
	for(var/dir in parent.glass_dirs)
		for(var/diag in list(turn(dir, 45), turn(dir, -45)))
			if(diag in diag_connections)
				continue
			if(mask_at(diag))
				diag_connections += diag

/// Does the tile on that side of us hold a mask the shadow could link with?
/atom/movable/atom_shadow/proc/mask_at(dir)
	var/turf/T = get_step(src, dir)
	var/turf/closed/wall/WT = T
	if(istype(WT) && WT.shadow) // walls of every family own a mask
		return TRUE
	var/obj/machinery/door/D = locate(/obj/machinery/door) in T
	return D && D.shadow // solid doors own one, glass doors stay empty

/atom/movable/atom_shadow/door
	icon = '_horizon/icons/obj/airlock_mask.dmi'

// MARK: Door Airlock
/obj/machinery/door
	var/atom/movable/atom_shadow/door/shadow

/obj/machinery/door/Initialize(mapload)
	. = ..()
	if(!glass)
		shadow = new(loc)
		shadow.icon_state = icon_state
		shadow.dir = dir
		if(!mapload)
			QUEUE_SMOOTH_NEIGHBORS(src) //walls around a runtime-spawned door need to see it

/obj/machinery/door/setDir(newdir)
	. = ..()
	if(shadow)
		shadow.dir = newdir

/obj/machinery/door/airlock/update_icon(updates = ALL)
	. = ..()
	if(shadow)
		switch(airlock_state)
			if(AIRLOCK_OPENING)
				shadow.icon_state = "opening"
			if(AIRLOCK_OPEN)
				shadow.icon_state = "open"
			if(AIRLOCK_CLOSING)
				shadow.icon_state = "closing"
			if(AIRLOCK_CLOSED)
				shadow.icon_state = "closed"

/obj/machinery/door/Destroy()
	QUEUE_SMOOTH_NEIGHBORS(src) //walls around need to close their junctions once we're gone
	qdel(shadow)
	return ..()

/obj/machinery/door/poddoor/update_icon(updates = ALL)
	. = ..()
	if(shadow)
		shadow.icon_state = density ? "closed" : "open"
