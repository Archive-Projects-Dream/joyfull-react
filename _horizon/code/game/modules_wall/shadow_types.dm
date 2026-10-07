// MARK: Shadow-atom

/*
	* FOV mask renderer, nothing more. The parent wall owns every junction
	* decision: standard walls push their bitmask junction straight into our
	* icon_state through set_smoothed_icon_state(), module (special_icon) walls
	* hand us their corner list and call our update_icon() from theirs. No
	* smoothing flags, no neighbour scans of our own - the mask is just the
	* wall again, drawn on the FOV shadows plane.
	*/
/atom/movable/atom_shadow
	name = "shadow"
	icon = '_horizon/icons/obj/solid_wall_mask.dmi'
	icon_state = "wall-0"
	anchored = TRUE
	plane = ATOMS_FOV_SHADOWS_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// Mirrors the parent wall's special_icon: render four corner overlays
	/// instead of a single junction state.
	var/special_icon
	/// Corner states, shared list owned by the parent wall (module walls only).
	var/list/wall_connections = list("0", "0", "0", "0")

/atom/movable/atom_shadow/door
	icon = '_horizon/icons/obj/airlock_mask.dmi'

// WALL
/turf/closed/wall
	var/atom/movable/atom_shadow/shadow

/turf/closed/wall/Initialize(mapload)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	shadow = new(src)
	if(special_icon)
		shadow.special_icon = TRUE
		shadow.icon = '_horizon/icons/obj/modular_shadow.dmi'

// Standard walls: the bitmask junction doubles as the mask's icon_state, so
// the silhouette the FOV filters see is exactly the wall the player sees.
/turf/closed/wall/set_smoothed_icon_state(new_junction)
	. = ..()
	if(shadow)
		shadow.icon_state = "wall-[smoothing_junction]"

/turf/closed/wall/Destroy()
	qdel(shadow)
	return ..()

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
	qdel(shadow)
	QUEUE_SMOOTH_NEIGHBORS(src)
	return ..()

/obj/machinery/door/poddoor/update_icon(updates = ALL)
	. = ..()
	if(shadow)
		shadow.icon_state = density ? "closed" : "open"
