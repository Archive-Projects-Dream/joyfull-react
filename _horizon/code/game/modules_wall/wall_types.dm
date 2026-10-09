/turf/closed
	var/atom/movable/atom_shadow/wall/shadow

	var/list/wall_connections = list("0", "0", "0", "0")
	var/list/blend_turfs = list(/turf/closed)
	var/list/noblend_turfs = list(/turf/closed/mineral, /turf/closed/wall/mineral/titanium)
	var/list/blend_objects = list(/obj/structure/window/reinforced/fulltile, /obj/structure/window/framed, /obj/structure/window_frame, /obj/machinery/door)
	var/list/noblend_objects = list()

	var/special_icon = TRUE
	var/diagonal = FALSE /// Special wall0-diagonal and wall5-diagonal states
	smoothing_flags = SMOOTH_CONNECTOR
	smoothing_groups = null
	canSmoothWith = null

/turf/closed/wall/Initialize(mapload)
	. = ..()
	shadow = new(src)

/turf/closed/wall/Destroy()
	qdel(shadow)
	return ..()

/turf/closed/wall/setDir(newDir)
	..()
	QUEUE_SMOOTH(src)

// MARK: Types
/turf/closed/wall/mineral/plastitanium/survival
	icon = '_horizon/icons/turf/walls/modules_wall/survival_pod_walls.dmi'

/turf/closed/wall/concrete
	icon = '_horizon/icons/turf/walls/modules_wall/concentrate.dmi'
