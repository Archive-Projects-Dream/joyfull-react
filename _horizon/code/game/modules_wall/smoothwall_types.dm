// MARK: Shadow-atom
/atom/movable/atom_shadow
	name = "shadow"
	icon = '_horizon/icons/obj/solid_wall_mask.dmi'
	icon_state = "wall-0"
	anchored = TRUE
	plane = ATOMS_FOV_SHADOWS_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	smoothing_flags = SMOOTH_BITMASK_CARDINALS
	smooth_diagonals = TRUE

/atom/movable/atom_shadow/Initialize(mapload)
	tiles_with = BASED_TILES
	. = ..()
	QUEUE_SMOOTH(src)
	if(!mapload)
		relativewall_neighbours()

/atom/movable/atom_shadow/smooth_icon()
	smoothing_flags &= ~SMOOTH_QUEUED
	relativewall()

/atom/movable/atom_shadow/handle_icon_junction(junction)
	if(smoothing_junction == junction)
		return
	smoothing_junction = junction
	icon_state = "wall-[junction]"

/atom/movable/atom_shadow/Destroy()
	relativewall_neighbours()
	return ..()

// WALL
/turf/closed/wall
	var/atom/movable/atom_shadow/shadow

/turf/closed/wall/Initialize(mapload)
	. = ..()
	shadow = new(src)

/turf/closed/wall/Destroy()
	shadow?.Destroy()
	return ..()

// MARK: Door Airlock
/atom/movable/atom_shadow/door
	icon = '_horizon/icons/obj/airlock_mask.dmi'

/atom/movable/atom_shadow/door/smooth_icon()
	smoothing_flags &= ~SMOOTH_QUEUED

/atom/movable/atom_shadow/door/handle_icon_junction(junction)
	return

/obj/machinery/door
	var/atom/movable/atom_shadow/door/shadow

/obj/machinery/door/Initialize(mapload)
	tiles_with = BASED_TILES
	. = ..()
	if(!glass)
		shadow = new(loc)
		shadow.icon_state = icon_state
		shadow.dir = dir
	else if(!mapload)
		relativewall_neighbours()

/obj/machinery/door/setDir(newdir)
	. = ..()
	shadow?.dir = newdir

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
	if(shadow)
		shadow.Destroy()
	else
		relativewall_neighbours()
	return ..()

/obj/machinery/door/poddoor/update_icon(updates = ALL)
	. = ..()
	if(shadow)
		shadow.icon_state = density ? "closed" : "open"
