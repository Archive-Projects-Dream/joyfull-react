/turf/closed/wall
	icon = '_horizon/icons/turf/walls/wall.dmi'
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WALLS + SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_CLOSED_TURFS
	canSmoothWith = SMOOTH_GROUP_WALLS + SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_AIRLOCK

/*
/turf/closed/wall/mineral/bananium
	icon = 'icons/turf/walls/bananium_wall.dmi'

/turf/closed/wall/mineral/bamboo
	icon = 'icons/turf/walls/bamboo_wall.dmi'

/turf/closed/wall/mineral/abductor
	icon = 'icons/turf/walls/abductor_wall.dmi'
*/

// MARK: Titan
/turf/closed/wall/mineral/titanium
	icon = '_horizon/icons/turf/walls/shuttle_wall.dmi'

/turf/closed/wall/mineral/titanium/nodiagonal
	icon = '_horizon/icons/turf/walls/shuttle_wall.dmi'
	icon_state = MAP_SWITCH("shuttle_wall-0", "map-shuttle_nd")

/turf/closed/wall/mineral/titanium/overspace
	icon = '_horizon/icons/turf/walls/shuttle_wall.dmi'
	icon_state = MAP_SWITCH("shuttle_wall-0", "shuttle_overspace")

/turf/closed/wall/mineral/titanium/survival
	icon = '_horizon/icons/turf/walls/survival_pod_walls.dmi'

/turf/closed/wall/mineral/titanium/survival/nodiagonal
	icon = '_horizon/icons/turf/walls/survival_pod_walls.dmi'

// MARK: Plas Titan
/turf/closed/wall/mineral/plastitanium
	icon = '_horizon/icons/turf/walls/plastitanium_wall.dmi'

/turf/closed/wall/mineral/plastitanium/nodiagonal
	icon = MAP_SWITCH('_horizon/icons/turf/walls/plastitanium_wall.dmi', 'icons/turf/walls/misc_wall.dmi')
	icon_state = MAP_SWITCH("plastitanium_wall-0", "plastitanium_nd")

/turf/closed/wall/mineral/plastitanium/overspace
	icon = MAP_SWITCH('_horizon/icons/turf/walls/plastitanium_wall.dmi', 'icons/turf/walls/misc_wall.dmi')
	icon_state = MAP_SWITCH("plastitanium_wall-0", "plastitanium_overspace")

// MARK: Generic Walls
/turf/closed/wall/mineral/wood
	icon = '_horizon/icons/turf/walls/wood_wall.dmi'

/turf/closed/wall/mineral/diamond
	icon = '_horizon/icons/turf/walls/diamond_wall.dmi'

/turf/closed/wall/mineral/gold
	icon = '_horizon/icons/turf/walls/gold_wall.dmi'

/turf/closed/wall/mineral/silver
	icon = '_horizon/icons/turf/walls/silver_wall.dmi'

/turf/closed/wall/mineral/snow  //
	icon = '_horizon/icons/turf/walls/snow_wall.dmi'

/turf/closed/wall/mineral/sandstone
	icon = '_horizon/icons/turf/walls/sandstone_wall.dmi'

/turf/closed/wall/mineral/uranium
	icon = '_horizon/icons/turf/walls/uranium_wall.dmi'

/turf/closed/wall/mineral/plasma
	icon = '_horizon/icons/turf/walls/plasma_wall.dmi'

/turf/closed/wall/mineral/iron
	icon = '_horizon/icons/turf/walls/iron_wall.dmi'

/turf/closed/indestructible/riveted
	icon = '_horizon/icons/turf/walls/riveted.dmi'
	smoothing_groups = SMOOTH_GROUP_WALLS + SMOOTH_GROUP_CLOSED_TURFS + SMOOTH_GROUP_SYNDICATE_WALLS
	canSmoothWith = SMOOTH_GROUP_SHUTTLE_PARTS + SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_PLASTITANIUM_WALLS + SMOOTH_GROUP_SYNDICATE_WALLS

/turf/closed/indestructible/riveted/boss
	icon = '_horizon/icons/turf/walls/boss_wall.dmi'
/*
/turf/closed/wall/concrete
	icon = '_horizon/icons/turf/walls/concrete.dmi'

/turf/closed/wall/concrete/reinforced
	icon = '_horizon/icons/turf/walls/hexacrete.dmi'
*/
/turf/closed/wall/r_wall
	icon = '_horizon/icons/turf/walls/rwalls/reinforced_wall.dmi'
