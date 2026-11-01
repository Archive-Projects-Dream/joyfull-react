/**
 * # Planet Turfs
 *
 * Turf variants used by dynamically generated planet stacks.
 */

/// Sky layer above generated planet surfaces.
/// space_lit keeps this ghost layer out of the lighting subsystem: every
/// lighting object creation path (SSlighting init, ChangeTurf, area
/// transfers) skips space_lit turfs, so the tens of thousands of sky tiles
/// never spawn one. init_air = FALSE leaves the layer without an atmosphere
/// tile, same as regular space, so LINDA never processes it either.
/// Follows the SS220 Paradise overmap pattern of keeping non-gameplay levels
/// cheap and immune to init-order issues. Floors built by players on top of
/// it opt back in normally (they are not space_lit).
/turf/open/openspace/planet_sky
	space_lit = TRUE
	init_air = FALSE
