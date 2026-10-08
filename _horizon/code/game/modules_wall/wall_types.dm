/turf/closed
	var/atom/movable/atom_shadow/shadow // Тень есть всегда на турфах закрытого типа.
	/// when walls smooth with one another, the type of junction each wall is.
	var/list/wall_connections = list("0", "0", "0", "0")
	/// Special wall0-diagonal and wall5-diagonal states
	var/diagonal = FALSE
	var/special_icon = TRUE
	smoothing_flags = SMOOTH_CONNECTOR
	smoothing_groups = null
	canSmoothWith = null

	/*
	 * blend_turfs - Turfs to blending with
	 * noblend_turfs - Turfs to avoid blending with
	 * blend_objects - Objects which to blend with
	 * noblend_objects - Objects to avoid blending with (such as children of listed blend objects).
	 */
	var/list/blend_turfs = list(/turf/closed)
	var/list/noblend_turfs = list(/turf/closed/mineral)
	var/list/blend_objects = list(/obj/structure/window/reinforced/fulltile, /obj/machinery/door)
	var/list/noblend_objects = list(/obj/machinery/door/airlock/public/glass)


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
