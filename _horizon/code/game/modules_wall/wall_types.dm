/turf/closed
	/// when walls smooth with one another, the type of junction each wall is.
	var/list/wall_connections = list("0", "0", "0", "0")
	var/special_icon
	/// Special wall0-diagonal and wall5-diagonal states
	var/diagonal = FALSE

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

/turf/closed/wall/setDir(newDir)
	..()
	QUEUE_SMOOTH(src)

/turf/closed/wall/mineral/plastitanium/survival
	icon = '_horizon/icons/turf/walls/modules_wall/survival_pod_walls.dmi'
	icon_state = "wall"
	special_icon = TRUE

/turf/closed/wall/concrete
	icon = '_horizon/icons/turf/walls/modules_wall/concentrate.dmi'
	icon_state = "wall"
	special_icon = TRUE
	smoothing_flags = SMOOTH_BITMASK_CARDINALS
	smoothing_groups = NONE
	canSmoothWith = NONE

/turf/closed/mineral
	icon_state = "wall"
	special_icon = TRUE
	smoothing_flags = SMOOTH_BITMASK_CARDINALS
	smoothing_groups = NONE
	canSmoothWith = NONE
	blend_turfs = list(/turf/closed/mineral)

/turf/closed/mineral/setDir(newDir)
	..()
	QUEUE_SMOOTH(src)

/turf/closed/mineral/random/desert
	icon = '_horizon/icons/turf/walls/modules_wall/stone2.dmi'
