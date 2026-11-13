/// Adds balloons next to wallmounts so they can be seen and clicked while holding the examine hotkey
/// Ported from wallening (wall-nerds/wallening). Adapted for our wallmount dir convention:
/// our wallmount dirs point INTO the wall, so north-mounted wallmounts already face the camera and get no balloon.
/// The balloon of the others is drawn opposite their dir (into the room, away from the wall they are mounted on), keeps their dir,
/// and the arrow is turned to point back at the wallmount.
/datum/component/examine_balloon
	/// Store the overlays applied in the previous turn and clean them up (because of how managed_overlays checks for changes we need to do this manually)
	var/list/previous_overlays
	/// How far from the wallmount the hologram is drawn, in pixels, opposite the dir of the wallmount
	var/hologram_distance
	/// Our x and y size is multiplied by this, for small sprites like buttons
	var/size_upscaling

	/// How far from the wallmount the arrow is drawn, in pixels, opposite the dir of the wallmount
	var/arrow_distance = 16
	/// The alpha we apply to the hologram
	var/hologram_alpha = 200
	/// Add a hologram when the wallmount is mounted on these walls (our dirs point into the wall, north is the obvious exception)
	var/draw_in_dirs = SOUTH | EAST | WEST

/datum/component/examine_balloon/Initialize(hologram_distance = 28, arrow_distance = 16, size_upscaling = 1)
	. = ..()

	if(!ismovable(parent))
		return COMPONENT_INCOMPATIBLE

	src.hologram_distance = hologram_distance
	src.size_upscaling = size_upscaling
	src.arrow_distance = arrow_distance

	var/atom/atom_parent = parent

	// We use UPDATED_ICON specifically because we need to be last in the icon chain, even if UPDATE_OVERLAYS would otherwise be more apt
	RegisterSignal(atom_parent, COMSIG_ATOM_UPDATED_ICON, PROC_REF(on_updated_icon))

	atom_parent.update_icon(UPDATE_OVERLAYS)

/datum/component/examine_balloon/proc/on_updated_icon(atom/movable/parent, updates)
	SIGNAL_HANDLER

	if(!(updates & UPDATE_OVERLAYS))
		return

	// Wallmounts on the north wall already show their face to the camera, so we don't add a hologram
	if(!(parent.dir & draw_in_dirs))
		return

	parent.cut_overlay(previous_overlays)

	// The balloon goes opposite the dir of the wallmount, away from the wall and into the room, and the arrow (its sprite points down) is turned by the same angle to point back at it
	var/dir_angle = dir2angle(turn(parent.dir, 180))

	// Make a copy of the wallmount, it keeps the dir the wallmount has
	var/mutable_appearance/hologram = new /mutable_appearance(parent)
	SET_PLANE_EXPLICIT(hologram, EXAMINE_BALLOONS_PLANE, parent)

	hologram.pixel_w = 0
	hologram.pixel_x = round(sin(dir_angle) * hologram_distance)
	hologram.pixel_y = round(cos(dir_angle) * hologram_distance)
	hologram.pixel_z = 0

	// We need to set all our overlay's planes to the wallmount balloons plane, or we get stuff like emissives sticking through the lighting plane
	var/list/new_overlays = list()
	for(var/mutable_appearance/immutable_appearance as anything in parent.overlays)
		var/mutable_appearance/actually_mutable_appearance = new(immutable_appearance)
		if(PLANE_TO_TRUE(actually_mutable_appearance.plane) != FLOAT_PLANE)
			continue
		new_overlays += actually_mutable_appearance

	hologram.overlays = new_overlays

	hologram.transform = hologram.transform.Scale(size_upscaling, size_upscaling)
	hologram.alpha = hologram_alpha

	var/mutable_appearance/examine_arrow = mutable_appearance(
		'icons/effects/effects.dmi',
		"examine_arrow",
	)

	examine_arrow.pixel_x = round(sin(dir_angle) * arrow_distance)
	examine_arrow.pixel_y = round(cos(dir_angle) * arrow_distance)
	examine_arrow.transform = examine_arrow.transform.Turn(dir_angle)

	SET_PLANE_EXPLICIT(examine_arrow, EXAMINE_BALLOONS_PLANE, parent)

	previous_overlays = list(hologram, examine_arrow)

	parent.add_overlay(previous_overlays)
