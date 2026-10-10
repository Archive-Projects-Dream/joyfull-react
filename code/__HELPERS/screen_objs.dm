/// Takes a screen loc string in the format
/// "+-left-offset:+-pixel,+-bottom-offset:+-pixel"
/// Where the :pixel is optional, and returns
/// A list in the format (x_offset, y_offset)
/// We require context to get info out of screen locs that contain relative info, so NORTH, SOUTH, etc
/proc/screen_loc_to_offset(screen_loc, view)
	if(!screen_loc)
		return list(64, 64)
	var/list/view_size = view_to_pixels(view)
	var/x = 0
	var/y = 0

	var/list/parts = splittext(screen_loc, ",")

	// BYOND allows arbitrary ordering when directional keywords are used.
	// Determine which part is X and which is Y based on keyword presence.
	var/x_part = trim(parts[1])
	var/y_part = trim(parts[2])
	// If first part has a Y-direction keyword and second has an X-direction or CENTER, swap
	var/first_is_y = findtext(x_part, "NORTH") || findtext(x_part, "SOUTH") || findtext(x_part, "TOP") || findtext(x_part, "BOTTOM")
	var/second_is_x = findtext(y_part, "EAST") || findtext(y_part, "WEST") || findtext(y_part, "LEFT") || findtext(y_part, "RIGHT")
	if(first_is_y && !findtext(x_part, "EAST") && !findtext(x_part, "WEST"))
		// First part is Y, second is X, swap
		x_part = parts[2]
		y_part = parts[1]
	else if(second_is_x && !findtext(y_part, "NORTH") && !findtext(y_part, "SOUTH"))
		// Second part is X, first is Y, swap
		x_part = parts[2]
		y_part = parts[1]

	var/list/x_pack = splittext(x_part, ":")
	var/list/y_pack = splittext(y_part, ":")

	var/x_coord = x_pack[1]
	var/y_coord = y_pack[1]

	// Parse directional anchors
	if(findtext(x_coord, "EAST") || findtext(x_coord, "RIGHT"))
		x += view_size[1]
	else if(findtext(x_coord, "WEST") || findtext(x_coord, "LEFT"))
		x += ICON_SIZE_X

	if(findtext(y_coord, "NORTH") || findtext(y_coord, "TOP"))
		y += view_size[2]
	else if(findtext(y_coord, "SOUTH") || findtext(y_coord, "BOTTOM"))
		y += ICON_SIZE_Y

	if (findtext(x_coord, "CENTER"))
		x += view_size[1] / 2

	if (findtext(y_coord, "CENTER"))
		y += view_size[2] / 2

	x_coord = text2num(cut_relative_direction(x_coord))
	y_coord = text2num(cut_relative_direction(y_coord))

	x += x_coord * ICON_SIZE_X
	y += y_coord * ICON_SIZE_Y

	if(length(x_pack) > 1)
		x += text2num(x_pack[2])
	if(length(y_pack) > 1)
		y += text2num(y_pack[2])
	return list(x, y)

/// Takes a list in the form (x_offset, y_offset)
/// And converts it to a screen loc string
/// Accepts an optional view string/size to force the screen_loc around, so it can't go out of scope
/proc/offset_to_screen_loc(x_offset, y_offset, view = null)
	if(view)
		var/list/view_bounds = view_to_pixels(view)
		x_offset = clamp(x_offset, ICON_SIZE_X, view_bounds[1])
		y_offset = clamp(y_offset, ICON_SIZE_Y, view_bounds[2])

	// Round with no argument is floor, so we get the non pixel offset here
	var/x = round(x_offset / ICON_SIZE_X)
	var/pixel_x = x_offset % ICON_SIZE_X
	var/y = round(y_offset / ICON_SIZE_Y)
	var/pixel_y = y_offset % ICON_SIZE_Y

	var/list/generated_loc = list()
	generated_loc += "[x]"
	if(pixel_x)
		generated_loc += ":[pixel_x]"
	generated_loc += ",[y]"
	if(pixel_y)
		generated_loc += ":[pixel_y]"
	return jointext(generated_loc, "")

/**
 * Returns a valid location to place a screen object without overflowing the viewport
 *
 * * target: The target location as a purely number based screen_loc string "+-left-offset:+-pixel,+-bottom-offset:+-pixel"
 * * target_offset: The amount we want to offset the target location by. We explictly don't care about direction here, we will try all 4
 * * view: The view variable of the client we're doing this for. We use this to get the size of the screen
 *
 * Returns a screen loc representing the valid location
**/
/proc/get_valid_screen_location(target_loc, target_offset, view)
	var/list/offsets = screen_loc_to_offset(target_loc)
	var/base_x = offsets[1]
	var/base_y = offsets[2]

	var/list/view_size = view_to_pixels(view)

	// Bias to the right, down, left, and then finally up
	if(base_x + target_offset < view_size[1])
		return offset_to_screen_loc(base_x + target_offset, base_y, view)
	if(base_y - target_offset > ICON_SIZE_Y)
		return offset_to_screen_loc(base_x, base_y - target_offset, view)
	if(base_x - target_offset > ICON_SIZE_X)
		return offset_to_screen_loc(base_x - target_offset, base_y, view)
	if(base_y + target_offset < view_size[2])
		return offset_to_screen_loc(base_x, base_y + target_offset, view)
	stack_trace("You passed in a scren location {[target_loc]} and offset {[target_offset]} that can't be fit in the viewport Width {[view_size[1]]}, Height {[view_size[2]]}. what did you do lad")
	return null // The fuck did you do lad

/// Applies a pixel delta to an existing screen_loc, preserving relative keywords.
/// dx and dy are in viewport pixels (positive = right/up).
/proc/apply_screen_loc_delta(screen_loc, dx, dy)
	var/list/parts = splittext(screen_loc, ",")
	if(length(parts) < 2)
		return screen_loc

	// Detect if parts are swapped (Y-direction keyword in first slot)
	var/first_part = trim(parts[1])
	var/second_part = trim(parts[2])
	var/swapped = FALSE
	if((findtext(first_part, "NORTH") || findtext(first_part, "SOUTH") || findtext(first_part, "TOP") || findtext(first_part, "BOTTOM")) && !findtext(first_part, "EAST") && !findtext(first_part, "WEST"))
		swapped = TRUE

	var/x_part = swapped ? second_part : first_part
	var/y_part = swapped ? first_part : second_part

	var/list/x_pack = splittext(x_part, ":")
	var/list/y_pack = splittext(y_part, ":")

	// Apply dx to x pixel offset
	var/x_pixel = length(x_pack) > 1 ? text2num(x_pack[2]) : 0
	x_pixel += dx
	var/x_tile_delta = round(x_pixel / ICON_SIZE_X)
	x_pixel = x_pixel % ICON_SIZE_X
	if(x_pixel < 0)
		x_tile_delta -= 1
		x_pixel += ICON_SIZE_X

	// Apply dy to y pixel offset
	var/y_pixel = length(y_pack) > 1 ? text2num(y_pack[2]) : 0
	y_pixel += dy
	var/y_tile_delta = round(y_pixel / ICON_SIZE_Y)
	y_pixel = y_pixel % ICON_SIZE_Y
	if(y_pixel < 0)
		y_tile_delta -= 1
		y_pixel += ICON_SIZE_Y

	// Rebuild the tile coordinate with delta applied
	var/x_base = x_pack[1]
	if(x_tile_delta)
		x_base = apply_tile_delta(x_base, x_tile_delta)

	var/y_base = y_pack[1]
	if(y_tile_delta)
		y_base = apply_tile_delta(y_base, y_tile_delta)

	var/new_x = x_pixel ? "[x_base]:[x_pixel]" : "[x_base]"
	var/new_y = y_pixel ? "[y_base]:[y_pixel]" : "[y_base]"

	if(swapped)
		return "[new_y],[new_x]"
	return "[new_x],[new_y]"

/// Applies a tile offset delta to a screen_loc coordinate component like "CENTER-3" or "EAST+1"
/// Returns the modified component string with proper sign handling
/proc/apply_tile_delta(component, delta)
	var/keyword = cut_relative_direction(component)
	// keyword is now just the numeric part like "-3" or "+1" or ""
	var/direction = replacetext(component, keyword, "") // just the keyword like "CENTER" or "EAST"
	var/numeric = text2num(keyword)
	if(isnull(numeric))
		numeric = 0
	numeric += delta
	if(numeric == 0)
		return direction
	if(numeric > 0)
		return "[direction]+[numeric]"
	return "[direction][numeric]"

/// Takes a screen_loc string and cut out any directions like NORTH or SOUTH
/proc/cut_relative_direction(fragment)
	var/static/regex/regex = regex(@"([A-Z])\w+", "g")
	return regex.Replace(fragment, "")

/// Returns a screen_loc format for a tiling screen objects from start and end positions. Start should be bottom left corner, and end top right corner.
/proc/spanning_screen_loc(start_px, start_py, end_px, end_py)
	var/starting_tile_x = round(start_px / ICON_SIZE_X)
	start_px -= starting_tile_x * ICON_SIZE_X
	var/starting_tile_y = round(start_py/ ICON_SIZE_Y)
	start_py -= starting_tile_y * ICON_SIZE_Y
	var/ending_tile_x = round(end_px / ICON_SIZE_X)
	end_px -= ending_tile_x * ICON_SIZE_X
	var/ending_tile_y = round(end_py / ICON_SIZE_Y)
	end_py -= ending_tile_y * ICON_SIZE_Y
	return "[starting_tile_x]:[start_px],[starting_tile_y]:[start_py] to [ending_tile_x]:[end_px],[ending_tile_y]:[end_py]"
