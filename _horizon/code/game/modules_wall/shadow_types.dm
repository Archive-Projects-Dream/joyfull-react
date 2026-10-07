// MARK: Shadow-atom
/atom/movable/atom_shadow
	name = "shadow"
	icon = '_horizon/icons/obj/modular_shadow.dmi'
	icon_state = "wall"
	anchored = TRUE
	plane = ATOMS_FOV_SHADOWS_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	smoothing_flags = SMOOTH_CONNECTOR
	var/list/wall_connections = list("0", "0", "0", "0")
	var/special_icon

	/*
	 * blend_turfs - Turfs to blending with
	 * noblend_turfs - Turfs to avoid blending with
	 * blend_objects - Objects which to blend with
	 * noblend_objects - Objects to avoid blending with (such as children of listed blend objects).
	 */
	var/list/blend_turfs = list()
	var/list/noblend_turfs = list()
	var/list/blend_objects = list()
	var/list/noblend_objects = list()


/atom/movable/atom_shadow/setDir(newDir)
	..()
	QUEUE_SMOOTH(src)

/atom/movable/atom_shadow/door
	icon = '_horizon/icons/obj/airlock_mask.dmi'
	smoothing_flags = NONE
	special_icon = FALSE

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
/obj/machinery/door
	var/atom/movable/atom_shadow/door/shadow

/obj/machinery/door/Initialize(mapload)
	. = ..()
	if(!glass)
		shadow = new(loc)
		shadow.icon_state = icon_state
		shadow.dir = dir

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
	return ..()

/obj/machinery/door/poddoor/update_icon(updates = ALL)
	. = ..()
	if(shadow)
		shadow.icon_state = density ? "closed" : "open"
