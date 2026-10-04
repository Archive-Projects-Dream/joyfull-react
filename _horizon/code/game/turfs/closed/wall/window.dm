// MARK: Окна

/obj/structure/window/reinforced/shuttle
	icon = '_horizon/icons/obj/smooth_structures/shuttle_window.dmi'
	plane = ABOVE_WALL_PLANE
	smoothing_flags = SMOOTH_BITMASK | SMOOTH_DIAGONAL_CORNERS
	smoothing_groups = SMOOTH_GROUP_TITANIUM_WALLS + SMOOTH_GROUP_WALLS + SMOOTH_GROUP_CLOSED_TURFS
	canSmoothWith = SMOOTH_GROUP_SHUTTLE_PARTS + SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_TITANIUM_WALLS

/obj/structure/window/reinforced/plasma/plastitanium
	icon = '_horizon/icons/obj/smooth_structures/plastitanium_window.dmi'
	plane = ABOVE_WALL_PLANE

/obj/structure/window/reinforced/fulltile
	icon = '_horizon/icons/obj/smooth_structures/reinforced_window.dmi'
	plane = ABOVE_WALL_PLANE
	smoothing_groups = SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_WALLS
	canSmoothWith = SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_WALLS

/obj/structure/window/fulltile
	icon = '_horizon/icons/obj/smooth_structures/window.dmi'
	plane = ABOVE_WALL_PLANE

/obj/structure/window/plasma/fulltile
	icon = '_horizon/icons/obj/smooth_structures/plasma_window.dmi'
	plane = ABOVE_WALL_PLANE

/obj/structure/window/reinforced/plasma/fulltile
	icon = '_horizon/icons/obj/smooth_structures/rplasma_window.dmi'
	plane = ABOVE_WALL_PLANE

/turf/closed/indestructible/fakeglass
	icon = MAP_SWITCH('_horizon/icons/obj/smooth_structures/reinforced_window.dmi', 'icons/obj/smooth_structures/structure_variations.dmi')
	plane = ABOVE_WALL_PLANE
	smoothing_groups = SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_WALLS
	canSmoothWith = SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_WALLS

/obj/structure/grille
	icon = '_horizon/icons/obj/smooth_structures/grille_simple.dmi'
	icon_state = "grille0"
	plane = ABOVE_WALL_PLANE
	smoothing_flags = SMOOTH_BITMASK_CARDINALS
	smoothing_groups = null
	canSmoothWith = null

/obj/structure/grille/Initialize(mapload)
	tiles_with = BASED_TILES
	. = ..()
	QUEUE_SMOOTH(src)
	if(!mapload)
		relativewall_neighbours()

/obj/structure/grille/smooth_icon()
	smoothing_flags &= ~SMOOTH_QUEUED
	relativewall()

/obj/structure/grille/Destroy()
	relativewall_neighbours()
	return ..()

/obj/structure/grille/handle_icon_junction(junction)
	icon_state = "grille[junction]"
