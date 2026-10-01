// MARK: Shadow-atom
/atom/movable/atom_shadow
	name = "shadow"
	icon = '_horizon/icons/obj/modular_shadow.dmi'
	icon_state = "wall"
	anchored = TRUE
	plane = ATOMS_FOV_SHADOWS_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/special_icon = TRUE
	var/list/shadow_connections = list("0", "0", "0", "0")

/atom/movable/atom_shadow/door
	icon = '_horizon/icons/obj/airlock_mask.dmi'

// MARK: WALL
/turf/closed/wall
	var/atom/movable/atom_shadow/shadow

/turf/closed/wall/Initialize(mapload)
	. = ..()
	shadow = new(src)

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
	return ..()

/obj/machinery/door/poddoor/update_icon(updates = ALL)
	. = ..()
	if(shadow)
		shadow.icon_state = density ? "closed" : "open"
