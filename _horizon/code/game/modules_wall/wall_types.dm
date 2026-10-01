/turf/closed
	/// when walls smooth with one another, the type of junction each wall is.
	var/list/wall_connections = list("0", "0", "0", "0")
	/// Special wall0-diagonal and wall5-diagonal states
	var/diagonal = FALSE
	var/special_icon = TRUE
	smoothing_flags = SMOOTH_CONNECTOR
	smoothing_groups = NONE
	canSmoothWith = NONE

	/*
	 * blend_turfs - Turfs to blending with
	 * noblend_turfs - Turfs to avoid blending with
	 * blend_objects - Objects which to blend with
	 * noblend_objects - Objects to avoid blending with (such as children of listed blend objects).
	 */
	var/list/blend_turfs = list(/turf/closed)
	var/list/noblend_turfs = list(/turf/closed/mineral)
	var/list/blend_objects = list()
	var/list/noblend_objects = list()

/turf/closed/wall/setDir(newDir)
	..()
	QUEUE_SMOOTH(src)

// MARK: Types
/turf/closed/wall/mineral/plastitanium/survival
	icon = '_horizon/icons/turf/walls/modules_wall/survival_pod_walls.dmi'

/turf/closed/wall/concrete
	icon = '_horizon/icons/turf/walls/modules_wall/concentrate.dmi'

/turf/closed/mineral
	icon = '_horizon/icons/turf/walls/modules_wall/stone2.dmi'
	blend_turfs = list(/turf/closed/mineral)
	noblend_turfs = list()

/turf/closed/mineral/setDir(newDir)
	..()
	QUEUE_SMOOTH(src)
