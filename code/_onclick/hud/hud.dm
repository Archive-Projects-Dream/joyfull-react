/*
	The hud datum
	Used to show and hide huds for all the different mob types,
	including inventories and item quick actions.
*/

// The default UI style is the first one in the list
GLOBAL_LIST_INIT(available_ui_styles, list(
	"Midnight" = 'icons/hud/screen_midnight.dmi',
	"Retro" = 'icons/hud/screen_retro.dmi',
	"Plasmafire" = 'icons/hud/screen_plasmafire.dmi',
	"Slimecore" = 'icons/hud/screen_slimecore.dmi',
	"Operative" = 'icons/hud/screen_operative.dmi',
	"Clockwork" = 'icons/hud/screen_clockwork.dmi',
	"Glass" = 'icons/hud/screen_glass.dmi',
	"Trasen-Knox" = 'icons/hud/screen_trasenknox.dmi',
	"Detective" = 'icons/hud/screen_detective.dmi',
))

/proc/ui_style2icon(ui_style)
	return GLOB.available_ui_styles[ui_style] || GLOB.available_ui_styles[GLOB.available_ui_styles[1]]

/datum/hud
	var/mob/mymob
	/// Used for the HUD toggle (F12)
	var/hud_shown = TRUE
	/// Current displayed version of the HUD
	var/hud_version = HUD_STYLE_STANDARD
	/// Equipped item inventory
	var/inventory_shown = FALSE
	/// This is to hide the buttons that can be used via hotkeys. (hotkeybuttons list of buttons)
	var/hotkey_ui_hidden = FALSE

	/// Assoc list of key => "plane master groups"
	/// This is normally just the main window, but it'll occasionally contain things like spyglasses windows
	var/list/datum/plane_master_group/master_groups = list()
	///Assoc list of controller groups, associated with key string group name with value of the plane master controller ref
	var/list/atom/movable/plane_master_controller/plane_master_controllers = list()

	/// UI for screentips that appear when you mouse over things
	/// Stored directly as it is used in very hot MouseEntered code
	var/atom/movable/screen/screentip/screentip_text = null

	/// Whether or not screentips are enabled.
	/// This is updated by the preference for cheaper reads than would be
	/// had with a proc call, especially on one of the hottest procs in the
	/// game (MouseEntered).
	var/screentips_enabled = SCREENTIP_PREFERENCE_ENABLED
	/// Whether to use text or images for click hints.
	/// Same behavior as `screentips_enabled`--very hot, updated when the preference is updated.
	var/screentip_images = TRUE
	/// If this client is being shown atmos debug overlays or not
	var/atmos_debug_overlays = FALSE

	///Boolean on whether they need at least a healths or healdoll, for unit tests.
	var/needs_health_indicator = TRUE
	/// The color to use for the screentips.
	/// This is updated by the preference for cheaper reads than would be
	/// had with a proc call, especially on one of the hottest procs in the game (MouseEntered).
	var/screentip_color = null
	var/datum/action_group/palette/palette_actions = null
	var/datum/action_group/listed/listed_actions = null
	var/list/floating_actions = null

	/// Subtypes can override this to force a specific UI style
	var/ui_style = null
	/// Cached chat browser rect as list(x, y, w, h) in mapwindow pixels, or null if not onmap
	var/list/chat_rect
	/// Chat rect converted to viewport pixel coordinates (bottom-up) as list(left, bottom, w, h)
	var/list/chat_rect_viewport
	/// Cached map view-size for scaling, as list(w, h)
	var/list/cached_map_view_size
	/// Assoc list of hud_key -> original screen_loc for displaced elements
	var/list/displaced_elements = list()
	/// Whether the chat rect debug overlay is currently shown
	var/chat_debug_shown = FALSE
	/// List of screen objects used for the debug overlay
	var/list/atom/movable/screen/chat_debug_objects
	/// Assoc list of all screen objects we hold by their key
	var/list/atom/movable/screen/screen_objects = list()
	/// List of screen objects by their screen group
	var/list/screen_groups[SCREEN_GROUP_AMT]

	/// List of typepaths of /datum/inventory_slot which will be used to automatically create inventory slot UI elements
	/// If assigned a typepath instead of a list, it will instead use all valid subtypes of said typepath
	/// Can be changed in initialize_screen_objects() to add/remove slots
	var/list/datum/inventory_slot/default_inventory_slots = null
	/// Alist of slot_id -> inventory_slot datum of our slots
	/// These are singletons, do not modify individual slots!
	var/list/datum/inventory_slot/inventory_slots = alist()

	/// List of weakrefs to objects that we add to our screen that we don't expect to DO anything
	/// They typically use * in their render target. They exist solely so we can reuse them,
	/// and avoid needing to make changes to all idk 300 consumers if we want to change the appearance
	var/list/asset_refs_for_reuse = list()

/datum/hud/New(mob/owner)
	mymob = owner

	if (!ui_style)
		// will fall back to the default if any of these are null
		ui_style = ui_style2icon(owner.client?.prefs?.read_preference(/datum/preference/choiced/ui_style))

	add_screen_object(/atom/movable/screen/button_palette, HUD_MOB_TOGGLE_PALETTE)
	add_screen_object(/atom/movable/screen/palette_scroll/down, HUD_MOB_PALETTE_DOWN)
	add_screen_object(/atom/movable/screen/palette_scroll/up, HUD_MOB_PALETTE_UP)

	var/datum/plane_master_group/main/main_group = new(PLANE_GROUP_MAIN)
	main_group.attach_to(src)

	var/datum/preferences/preferences = owner?.client?.prefs
	screentip_color = preferences?.read_preference(/datum/preference/color/screentip_color)
	screentips_enabled = preferences?.read_preference(/datum/preference/choiced/enable_screentips)
	screentip_images = preferences?.read_preference(/datum/preference/toggle/screentip_images)
	screentip_text = add_screen_object(/atom/movable/screen/screentip, HUD_MOB_SCREENTIP)

	for(var/mytype in subtypesof(/atom/movable/plane_master_controller))
		var/atom/movable/plane_master_controller/controller_instance = new mytype(null,src)
		plane_master_controllers[controller_instance.name] = controller_instance

	owner.overlay_fullscreen("see_through_darkness", /atom/movable/screen/fullscreen/see_through_darkness)

	// Register onto the global spacelight appearances
	// So they can be render targeted by anything in the world
	for(var/obj/starlight_appearance/starlight as anything in GLOB.starlight_objects)
		register_reuse(starlight)

	RegisterSignal(SSmapping, COMSIG_PLANE_OFFSET_INCREASE, PROC_REF(on_plane_increase))
	RegisterSignal(mymob, COMSIG_MOB_LOGIN, PROC_REF(client_refresh))
	RegisterSignal(mymob, COMSIG_MOB_LOGOUT, PROC_REF(clear_client))
	RegisterSignal(mymob, COMSIG_MOB_SIGHT_CHANGE, PROC_REF(update_sightflags))
	RegisterSignal(mymob, COMSIG_VIEWDATA_UPDATE, PROC_REF(on_viewdata_update))

	initialize_screen_objects()
	create_inventory_slots()
	update_locked_slots()

	update_sightflags(mymob, mymob.sight, NONE)

/datum/hud/Destroy()
	if(mymob.hud_used == src)
		mymob.hud_used = null

	QDEL_NULL(palette_actions)
	QDEL_NULL(listed_actions)
	QDEL_LIST(floating_actions)
	QDEL_LIST(chat_debug_objects)
	chat_debug_objects = null
	screentip_text = null
	screen_groups = null
	inventory_slots.Cut()
	QDEL_LIST_ASSOC_VAL(screen_objects)
	QDEL_LIST_ASSOC_VAL(master_groups)
	QDEL_LIST_ASSOC_VAL(plane_master_controllers)
	mymob = null

	return ..()

/// Creates and registers a managed screen object
/datum/hud/proc/add_screen_object(atom/movable/screen/new_object, hud_key, group_key = HUD_GROUP_STATIC, ui_icon, ui_loc, update_screen = FALSE)
	if (ispath(new_object))
		new_object = new new_object(null, src, ui_loc)

	if (isnull(hud_key))
		hud_key = REF(new_object)

	if (!isnull(ui_icon))
		new_object.icon = ui_icon

	if (!isnull(ui_loc))
		new_object.screen_loc = ui_loc

	new_object.hud_key = hud_key
	if (screen_objects[hud_key])
		CRASH("Attempted to add a new [new_object] screen object to the [src] hud while an object with the same key [hud_key] is already present!")

	screen_objects[hud_key] = new_object

	if (group_key)
		LAZYADD(screen_groups[group_key], new_object)
		new_object.hud_group_key = group_key

	// Displace if it overlaps the chat browser
	if(chat_rect && new_object.screen_loc)
		displace_single_element(hud_key, new_object)

	if (update_screen)
		show_hud(hud_version)
	return new_object

/// Removes a screen object and refreshes the hud. Can just be passed a key.
/datum/hud/proc/remove_screen_object(atom/movable/screen/to_remove, update = TRUE)
	if (!istype(to_remove))
		to_remove = screen_objects[to_remove]
		if (!to_remove)
			return
	qdel(to_remove)
	if (update && !QDELETED(src))
		show_hud(hud_version)

/// Proc for children to spawn their screen object in
/datum/hud/proc/initialize_screen_objects()
	return

/// Returns a list of displacement groups for this HUD type.
/// Each group is a list of HUD keys that should move together when displaced by the chat.
/// Elements not in any group are treated as individual groups.
/// Override in subtypes to define groupings for that HUD
/datum/hud/proc/get_displacement_groups()
	return list()

/datum/hud/proc/client_refresh(datum/source)
	SIGNAL_HANDLER
	var/client/client = mymob.canon_client
	RegisterSignal(client, COMSIG_CLIENT_SET_EYE, PROC_REF(on_eye_change))
	on_eye_change(null, null, client.eye)

/datum/hud/proc/clear_client(datum/source)
	SIGNAL_HANDLER
	if(mymob.canon_client)
		UnregisterSignal(mymob.canon_client, COMSIG_CLIENT_SET_EYE)

/datum/hud/proc/on_viewdata_update(datum/source, view)
	SIGNAL_HANDLER

	view_audit_buttons()
	if(chat_rect)
		displace_hud_for_chat(chat_rect)

/datum/hud/proc/on_eye_change(datum/source, atom/old_eye, atom/new_eye)
	SIGNAL_HANDLER
	SEND_SIGNAL(src, COMSIG_HUD_EYE_CHANGED, old_eye, new_eye)

	if(old_eye)
		UnregisterSignal(old_eye, COMSIG_MOVABLE_Z_CHANGED)
	if(new_eye)
		// By the time logout runs, the client's eye has already changed
		// There's just no log of the old eye, so we need to override
		// :sadkirby:
		RegisterSignal(new_eye, COMSIG_MOVABLE_Z_CHANGED, PROC_REF(eye_z_changed), override = TRUE)
	eye_z_changed(new_eye)

/datum/hud/proc/update_sightflags(datum/source, new_sight, old_sight)
	SIGNAL_HANDLER
	// If neither the old and new flags can see turfs but not objects, don't transform the turfs
	// This is to ensure parallax works when you can't see holder objects
	if(should_sight_scale(new_sight) == should_sight_scale(old_sight))
		return

	for(var/group_key in master_groups)
		var/datum/plane_master_group/group = master_groups[group_key]
		group.refresh_planes_offset()

/datum/hud/proc/should_use_scale()
	return should_sight_scale(mymob.sight)

/datum/hud/proc/should_sight_scale(sight_flags)
	return (sight_flags & (SEE_TURFS | SEE_OBJS)) != SEE_TURFS

/datum/hud/proc/eye_z_changed(atom/eye)
	SIGNAL_HANDLER
	var/turf/eye_turf = get_turf(eye)
	if(!eye_turf)
		return
	SEND_SIGNAL(src, COMSIG_HUD_Z_CHANGED, eye_turf.z)

/datum/hud/proc/on_plane_increase(datum/source, old_max_offset, new_max_offset)
	SIGNAL_HANDLER
	for(var/i in old_max_offset + 1 to new_max_offset)
		register_reuse(GLOB.starlight_objects[i + 1])
	build_plane_groups(old_max_offset + 1, new_max_offset)

/// Creates the required plane masters to fill out new z layers (because each "level" of multiz gets its own plane master set)
/datum/hud/proc/build_plane_groups(starting_offset, ending_offset)
	for(var/group_key in master_groups)
		var/datum/plane_master_group/group = master_groups[group_key]
		group.build_plane_masters(starting_offset, ending_offset)

/// Returns the plane master that matches the input plane from the passed in group
/datum/hud/proc/get_plane_master(plane, group_key = PLANE_GROUP_MAIN)
	var/plane_key = "[plane]"
	var/datum/plane_master_group/group = master_groups[group_key]
	return group.plane_masters[plane_key]

/// Returns a list of all plane masters that match the input true plane, drawn from the passed in group (ignores z layer offsets)
/datum/hud/proc/get_true_plane_masters(true_plane, group_key = PLANE_GROUP_MAIN)
	var/list/atom/movable/screen/plane_master/masters = list()
	for(var/plane in TRUE_PLANE_TO_OFFSETS(true_plane))
		masters += get_plane_master(plane, group_key)
	return masters

/// Returns all the planes belonging to the passed in group key
/datum/hud/proc/get_planes_from(group_key)
	var/datum/plane_master_group/group = master_groups[group_key]
	return group.plane_masters

/// Returns the corresponding plane group datum if one exists
/datum/hud/proc/get_plane_group(key)
	return master_groups[key]

///Creates the mob's visible HUD, returns FALSE if it can't, TRUE if it did.
/mob/proc/create_mob_hud()
	if(!client || hud_used)
		return FALSE
	set_hud_used(new hud_type(src))
	update_sight()
	SEND_SIGNAL(src, COMSIG_MOB_HUD_CREATED)
	return TRUE

/mob/proc/set_hud_used(datum/hud/new_hud)
	hud_used = new_hud
	new_hud.build_action_groups()


/**
 * Shows this hud's hud to some mob
 *
 * Arguments
 * * version - denotes which style should be displayed. blank or 0 means "next version"
 * * viewmob - what mob to show the hud to. Can be this hud's mob, can be another mob, can be null (will use this hud's mob if so)
 */
/datum/hud/proc/show_hud(version = 0, mob/viewmob)
	if (!ismob(mymob))
		return FALSE

	var/mob/screenmob = viewmob || mymob
	if (!screenmob.client)
		return FALSE

	// This code is the absolute fucking worst, I want it to go die in a fire
	// Seriously, why
	// I'm sorry
	screenmob.client.clear_screen()
	screenmob.client.apply_clickcatcher()
	screenmob.client.apply_parallax()

	var/display_hud_version = version
	if (!display_hud_version) // If 0 or blank, display the next hud version
		display_hud_version = hud_version + 1

	// If the requested version number is greater than the available versions, reset back to the first version
	if (display_hud_version > HUD_VERSIONS)
		display_hud_version = HUD_STYLE_STANDARD

	var/list/group_static = screen_groups[HUD_GROUP_STATIC]
	var/list/group_toggleable = screen_groups[HUD_GROUP_TOGGLEABLE_INVENTORY]
	var/list/group_hotkeys = screen_groups[HUD_GROUP_HOTKEYS]
	var/list/group_info = screen_groups[HUD_GROUP_INFO]
	var/list/group_screen = screen_groups[HUD_GROUP_SCREEN_OVERLAYS]
	var/list/group_storage = screen_groups[HUD_GROUP_STORAGE]

	// Screen overlays get added regardless of the HUD state
	if (length(group_screen))
		screenmob.client.screen += group_screen

	var/atom/movable/screen/button_palette/palette = screen_objects[HUD_MOB_TOGGLE_PALETTE]
	var/atom/movable/screen/combattoggle/action_intent = screen_objects[HUD_MOB_INTENTS]

	switch (display_hud_version)
		if (HUD_STYLE_STANDARD)
			hud_shown = TRUE

			if (length(group_static))
				screenmob.client.screen += group_static
			if (length(group_toggleable) && screenmob.hud_used && screenmob.hud_used.inventory_shown)
				screenmob.client.screen += group_toggleable
			if (length(group_hotkeys) && !hotkey_ui_hidden)
				screenmob.client.screen += group_hotkeys
			if (length(group_info))
				screenmob.client.screen += group_info
			// Do not show open storages to viewers, they get their own storage UIs
			if (length(group_storage) && viewmob == mymob)
				screenmob.client.screen += group_storage

			screenmob.client.screen += palette
			//Restore intent selection to the original position
			if(action_intent)
				action_intent.screen_loc = action_intent.default_screen_location

		if (HUD_STYLE_REDUCED)
			hud_shown = FALSE

			if (length(group_info))
				screenmob.client.screen += group_info

			// Hands are apart of the static group but still should be presetn in the reduced mode
			for (var/i in 1 to length(mymob.held_items))
				var/atom/movable/screen/hand = screen_objects[HUD_KEY_HAND_SLOT(i)]
				if (hand)
					screenmob.client.screen += hand

			if(action_intent)
				//move this to the alternative position, where zone_select usually is.
				action_intent.screen_loc = ui_acti_alt

		if (HUD_STYLE_NOHUD)
			hud_shown = FALSE

	hud_version = display_hud_version
	inventory_update(screenmob)
	// Gives all of the actions the screenmob owes to their hud
	screenmob.update_action_buttons(TRUE)
	// Handles alerts - the things on the right side of the screen
	reorganize_alerts(screenmob)
	screenmob.reload_fullscreen()

	update_reuse(screenmob)

	// ensure observers get an accurate and up-to-date view
	if (!viewmob)
		plane_masters_update()
		for(var/M in mymob.observers)
			show_hud(hud_version, M)
	else if (viewmob.hud_used)
		viewmob.hide_other_mob_action_buttons(mymob)
		viewmob.hud_used.plane_masters_update()
		viewmob.show_other_mob_action_buttons(mymob)

	// Re-apply chat browser displacement after HUD rebuild
	if(chat_rect)
		displace_hud_for_chat(chat_rect)

	SEND_SIGNAL(screenmob, COMSIG_MOB_HUD_REFRESHED, src)
	return TRUE

/datum/hud/proc/plane_masters_update()
	for(var/group_key in master_groups)
		var/datum/plane_master_group/group = master_groups[group_key]
		// Plane masters are always shown to OUR mob, never to observers
		group.refresh_hud()

/datum/hud/human/show_hud(version = 0,mob/viewmob)
	. = ..()
	if(!.)
		return
	var/mob/screenmob = viewmob || mymob
	inventory_update(screenmob)

/datum/hud/new_player/show_hud(version = 0, mob/viewmob)
	. = ..()
	if(.)
		show_station_trait_buttons()

/datum/hud/proc/inventory_update(mob/viewer)
	if (isnull(mymob))
		return

	for (var/slot_id in inventory_slots)
		var/datum/inventory_slot/slot = inventory_slots[slot_id]
		if (!isnull(slot))
			slot.update_inventory_slot(src, mymob)

/datum/hud/proc/update_inventory_slot(slot_id, ...)
	if(isnull(mymob))
		return
	var/datum/inventory_slot/slot = inventory_slots[slot_id]
	if (!isnull(slot))
		var/list/slot_args = list(src, mymob) + args.Copy(2)
		slot.update_inventory_slot(arglist(slot_args))

/datum/hud/proc/update_ui_style(new_ui_style)
	// do nothing if overridden by a subtype or already on that style
	if (initial(ui_style) || ui_style == new_ui_style)
		return

	for(var/hud_key in screen_objects)
		var/atom/item = screen_objects[hud_key]
		if (item?.icon == ui_style)
			item.icon = new_ui_style

	ui_style = new_ui_style
	build_hand_slots(update_hud = TRUE)

/datum/hud/proc/register_reuse(atom/movable/screen/reuse)
	asset_refs_for_reuse += WEAKREF(reuse)
	mymob?.client?.screen += reuse

/datum/hud/proc/unregister_reuse(atom/movable/screen/reuse)
	asset_refs_for_reuse -= WEAKREF(reuse)
	mymob?.client?.screen -= reuse

/datum/hud/proc/update_reuse(mob/show_to)
	for(var/datum/weakref/screen_ref as anything in asset_refs_for_reuse)
		var/atom/movable/screen/reuse = screen_ref.resolve()
		if(isnull(reuse))
			asset_refs_for_reuse -= screen_ref
			continue
		show_to.client?.screen += reuse

/// Rebuilds our mob's hand slot screen elements
/datum/hud/proc/build_hand_slots(update_hud = FALSE)
	// Clean up existing hand slot objects
	for (var/atom/movable/screen/inventory/hand/hand in screen_groups[HUD_GROUP_STATIC])
		remove_screen_object(hand, FALSE)

	for(var/i in 1 to length(mymob.held_items))
		var/atom/movable/screen/inventory/hand/hand_box = add_screen_object(/atom/movable/screen/inventory/hand, HUD_KEY_HAND_SLOT(i), HUD_GROUP_STATIC, ui_style, ui_hand_position(i))
		hand_box.name = mymob.get_held_index_name(i)
		hand_box.icon_state = "hand_[mymob.held_index_to_dir(i)]"
		hand_box.held_index = i
		hand_box.update_appearance()

	var/num_of_swaps = 0
	for(var/atom/movable/screen/swap_hand/swap_hands in screen_groups[HUD_GROUP_STATIC])
		num_of_swaps += 1

	var/hand_num = 1
	for(var/atom/movable/screen/swap_hand/swap_hands in screen_groups[HUD_GROUP_STATIC])
		var/hand_ind = RIGHT_HANDS
		if (num_of_swaps > 1)
			hand_ind = IS_RIGHT_INDEX(hand_num) ? LEFT_HANDS : RIGHT_HANDS
		swap_hands.screen_loc = ui_swaphand_position(mymob, hand_ind)
		hand_num += 1

	hand_num = 1

	for(var/atom/movable/screen/drop/swap_hands in screen_groups[HUD_GROUP_STATIC])
		var/hand_ind = LEFT_HANDS
		if (num_of_swaps > 1)
			hand_ind = IS_LEFT_INDEX(hand_num) ? LEFT_HANDS : RIGHT_HANDS
		swap_hands.screen_loc = ui_swaphand_position(mymob, hand_ind)
		hand_num += 1

	if(update_hud && mymob?.hud_used == src)
		show_hud(hud_version)

/// Handles dimming inventory slots that a mob can't equip items to in their current state
/datum/hud/proc/update_locked_slots()
	return

/// Creates inventory slot screen elements based on our assigned default_inventory_slots
/datum/hud/proc/create_inventory_slots()
	var/list/created_paths = default_inventory_slots
	if (ispath(created_paths))
		created_paths = valid_subtypesof(created_paths)

	for (var/datum/inventory_slot/slot_type as anything in created_paths)
		var/datum/inventory_slot/inv_slot = GLOB.inventory_slot_datums[slot_type]
		if (!inv_slot)
			stack_trace("[src] attempted to use an invalid inventory slot: [slot_type]")
			continue
		inv_slot.create_element(src)
		inventory_slots[inv_slot.slot_id] = inv_slot

	// Lets add an abstract "hands" slot to ourselves for native handling
	inventory_slots[ITEM_SLOT_HANDS] = GLOB.inventory_slot_datums[/datum/inventory_slot/hands]
	inventory_update()

/datum/hud/proc/position_action(atom/movable/screen/movable/action_button/button, position)
	// This is kinda a hack, I'm sorry.
	// Basically, FLOATING is never a valid position to pass into this proc. It exists as a generic marker for manually positioned buttons
	// Not as a position to target
	if(position == SCRN_OBJ_FLOATING)
		return

	if(button.location != SCRN_OBJ_DEFAULT)
		hide_action(button)

	switch(position)
		if(SCRN_OBJ_DEFAULT) // Reset to the default
			button.dump_save() // Nuke any existing saves
			position_action(button, button.linked_action.default_button_position)
			return
		if(SCRN_OBJ_IN_LIST)
			listed_actions.insert_action(button)
		if(SCRN_OBJ_IN_PALETTE)
			palette_actions.insert_action(button)
		if(SCRN_OBJ_INSERT_FIRST)
			listed_actions.insert_action(button, index = 1)
			position = SCRN_OBJ_IN_LIST
		else // If we don't have it as a define, this is a screen_loc, and we should be floating
			floating_actions += button
			button.screen_loc = position
			position = SCRN_OBJ_FLOATING
			var/atom/movable/screen/button_palette/toggle_palette = screen_objects[HUD_MOB_TOGGLE_PALETTE]
			toggle_palette.update_state()

	button.location = position

/datum/hud/proc/position_action_relative(atom/movable/screen/movable/action_button/button, atom/movable/screen/movable/action_button/relative_to)
	if(button.location != SCRN_OBJ_DEFAULT)
		hide_action(button)

	switch(relative_to.location)
		if(SCRN_OBJ_IN_LIST)
			listed_actions.insert_action(button, listed_actions.index_of(relative_to))

		if(SCRN_OBJ_IN_PALETTE)
			palette_actions.insert_action(button, palette_actions.index_of(relative_to))

		if(SCRN_OBJ_FLOATING) // If we don't have it as a define, this is a screen_loc, and we should be floating
			floating_actions += button
			var/client/our_client = mymob.canon_client
			if(!our_client)
				position_action(button, button.linked_action.default_button_position)
				return

			// Asks for a location adjacent to our button that won't overflow the map
			button.screen_loc = get_valid_screen_location(relative_to.screen_loc, ICON_SIZE_ALL, our_client.view_size.getView())
			var/atom/movable/screen/button_palette/toggle_palette = screen_objects[HUD_MOB_TOGGLE_PALETTE]
			toggle_palette.update_state()

	button.location = relative_to.location

/// Removes the passed in action from its current position on the screen
/datum/hud/proc/hide_action(atom/movable/screen/movable/action_button/button)
	switch(button.location)
		if(SCRN_OBJ_DEFAULT) // Invalid
			CRASH("We just tried to hide an action buttion that somehow has the default position as its location, you done fucked up")

		if(SCRN_OBJ_FLOATING)
			floating_actions -= button
			var/atom/movable/screen/button_palette/toggle_palette = screen_objects[HUD_MOB_TOGGLE_PALETTE]
			toggle_palette.update_state()

		if(SCRN_OBJ_IN_LIST)
			listed_actions.remove_action(button)

		if(SCRN_OBJ_IN_PALETTE)
			palette_actions.remove_action(button)

	button.screen_loc = null

/// Generates visual landings for all groups that the button is not a memeber of
/datum/hud/proc/generate_landings(atom/movable/screen/movable/action_button/button)
	listed_actions.generate_landing()
	palette_actions.generate_landing()
	var/atom/movable/screen/button_palette/toggle_palette = screen_objects[HUD_MOB_TOGGLE_PALETTE]
	toggle_palette.activate_landing()

/// Clears all currently visible landings
/datum/hud/proc/hide_landings()
	listed_actions.clear_landing()
	palette_actions.clear_landing()
	var/atom/movable/screen/button_palette/toggle_palette = screen_objects[HUD_MOB_TOGGLE_PALETTE]
	toggle_palette.disable_landing()

// Updates any existing "owned" visuals, ensures they continue to be visible
/datum/hud/proc/update_our_owner()
	var/atom/movable/screen/button_palette/toggle_palette = screen_objects[HUD_MOB_TOGGLE_PALETTE]
	var/atom/movable/screen/palette_scroll/palette_down = screen_objects[HUD_MOB_PALETTE_DOWN]
	var/atom/movable/screen/palette_scroll/palette_up = screen_objects[HUD_MOB_PALETTE_UP]

	toggle_palette.refresh_owner()
	palette_down.refresh_owner()
	palette_up.refresh_owner()

	listed_actions.update_landing()
	palette_actions.update_landing()

/// Ensures all of our buttons are properly within the bounds of our client's view, moves them if they're not
/datum/hud/proc/view_audit_buttons()
	var/our_view = mymob?.canon_client?.view
	if(!our_view)
		return
	listed_actions.check_against_view()
	palette_actions.check_against_view()
	for(var/atom/movable/screen/movable/action_button/floating_button as anything in floating_actions)
		var/list/current_offsets = screen_loc_to_offset(floating_button.screen_loc, our_view)
		// We set the view arg here, so the output will be properly hemm'd in by our new view
		floating_button.screen_loc = offset_to_screen_loc(current_offsets[1], current_offsets[2], view = our_view)

/// Updates the cached chat browser rect and displaces overlapping HUD elements.
/// Pass null to clear displacement (e.g. when switching to panel mode).
/datum/hud/proc/displace_hud_for_chat(list/new_rect)
	// Silently restore original screen_locs before recomputing
	for(var/key in displaced_elements)
		var/atom/movable/screen/obj = screen_objects[key]
		if(obj)
			obj.screen_loc = displaced_elements[key]
	displaced_elements.Cut()
	chat_rect = new_rect
	chat_rect_viewport = null
	if(!chat_rect || !length(chat_rect))
		if(listed_actions)
			listed_actions.check_against_view()
		if(palette_actions)
			palette_actions.check_against_view()
		return
	var/our_view = mymob?.canon_client?.view
	if(!our_view)
		return
	var/chat_x = chat_rect[1]
	var/chat_y = chat_rect[2]
	var/chat_w = chat_rect[3]
	var/chat_h = chat_rect[4]
	// screen_loc_to_offset uses view_to_pixels (tile-based), but chat bounds are in mapwindow pixels
	// We need to scale chat bounds from mapwindow coords to viewport coords
	var/list/view_size = view_to_pixels(our_view)
	if(!cached_map_view_size)
		return
	var/map_w = cached_map_view_size[1]
	var/map_h = cached_map_view_size[2]
	if(!map_w || !map_h)
		return
	var/scale_x = view_size[1] / map_w
	var/scale_y = view_size[2] / map_h
	// Scale chat bounds from mapwindow pixels to viewport pixels
	var/scaled_x = chat_x * scale_x
	var/scaled_y = chat_y * scale_y
	var/scaled_w = chat_w * scale_x
	var/scaled_h = chat_h * scale_y
	// BYOND screen_loc Y is bottom-up but winset pos Y is top-down
	var/chat_bottom = view_size[2] - (scaled_y + scaled_h)
	var/chat_left = scaled_x
	chat_rect_viewport = list(chat_left, chat_bottom, scaled_w, scaled_h)
	// Determine shift direction based on which half of the screen the chat center is in
	var/chat_center_x = chat_left + chat_w / 2
	var/chat_center_y = chat_bottom + chat_h / 2
	var/shift_x_dir = (chat_center_x > view_size[1] / 2) ? -1 : 1
	var/shift_y_dir = (chat_center_y > view_size[2] / 2) ? -1 : 1
	// Build list of all element rects for collision checking
	var/list/element_rects = list()
	for(var/key in screen_objects)
		if(key == HUD_MOB_SCREENTIP)
			continue
		var/atom/movable/screen/obj = screen_objects[key]
		if(!obj.screen_loc || obj.screen_loc == "")
			continue
		// Skip elements with spanning screen_locs (contain "to")
		if(findtext(obj.screen_loc, " to "))
			continue
		// Skip elements with * in screen_loc (render targets)
		if(findtext(obj.screen_loc, "*"))
			continue
		var/list/offsets = screen_loc_to_offset(obj.screen_loc, our_view)
		if(!offsets)
			continue
		element_rects[key] = list(offsets[1], offsets[2], ICON_SIZE_X, ICON_SIZE_Y)
	// Build displacement groups from the HUD subtype's override, plus ungrouped elements
	var/list/defined_groups = get_displacement_groups()
	var/list/in_a_group = list()
	var/list/groups = list()
	for(var/list/group in defined_groups)
		var/list/valid_group = list()
		for(var/key in group)
			if(element_rects[key])
				valid_group += key
				in_a_group[key] = TRUE
		if(length(valid_group))
			groups += list(valid_group)
	// Add ungrouped elements as individual groups
	for(var/key in element_rects)
		if(!in_a_group[key])
			groups += list(list(key))
	// For each group, check if ANY element overlaps the chat. If so, compute the delta to clear the worst overlap and apply to ALL elements in the group.
	var/displaced_count = 0
	for(var/list/group in groups)
		// Find all overlapping elements in this group
		var/has_overlap = FALSE
		var/worst_key
		var/worst_overlap = 0
		for(var/key in group)
			var/list/rect = element_rects[key]
			if(rects_overlap(rect[1], rect[2], rect[3], rect[4], chat_left, chat_bottom, scaled_w, scaled_h))
				has_overlap = TRUE
				var/overlap_x = min(rect[1] + rect[3], chat_left + scaled_w) - max(rect[1], chat_left)
				var/overlap_y = min(rect[2] + rect[4], chat_bottom + scaled_h) - max(rect[2], chat_bottom)
				var/overlap_area = max(overlap_x, 0) * max(overlap_y, 0)
				if(overlap_area > worst_overlap || !worst_key)
					worst_overlap = overlap_area
					worst_key = key
		if(!has_overlap)
			continue
		// Find the element closest to the chat center, it's deepest inside and needs the most shift
		var/chat_cx = chat_left + scaled_w / 2
		var/chat_cy = chat_bottom + scaled_h / 2
		var/closest_key = group[1]
		var/closest_dist = INFINITY
		for(var/key in group)
			var/list/rect = element_rects[key]
			var/dx = rect[1] + ICON_SIZE_X / 2 - chat_cx
			var/dy = rect[2] + ICON_SIZE_Y / 2 - chat_cy
			var/dist = dx * dx + dy * dy
			if(dist < closest_dist)
				closest_dist = dist
				closest_key = key
		var/list/worst_rect = element_rects[closest_key]
		var/el_x = worst_rect[1]
		var/el_y = worst_rect[2]
		var/dist_to_h_edge = min(abs(el_x - chat_left), abs(el_x - (chat_left + scaled_w)))
		var/dist_to_v_edge = min(abs(el_y - chat_bottom), abs(el_y - (chat_bottom + scaled_h)))
		var/horizontal_first = dist_to_h_edge < dist_to_v_edge
		// Determine per-element shift direction: away from chat center
		var/el_shift_x = (el_x > chat_left + scaled_w / 2) ? 1 : -1
		var/el_shift_y = (el_y > chat_bottom + scaled_h / 2) ? 1 : -1
		// Find minimum shift to clear the chat for the worst element
		// Try all 4 directions, preferring the one closest to the chat edge
		var/list/try_dirs = list()
		if(horizontal_first)
			try_dirs = list(list(el_shift_x, 0), list(0, el_shift_y), list(-el_shift_x, 0), list(0, -el_shift_y))
		else
			try_dirs = list(list(0, el_shift_y), list(el_shift_x, 0), list(0, -el_shift_y), list(-el_shift_x, 0))
		var/delta_x = 0
		var/delta_y = 0
		var/found = FALSE
		for(var/list/dir in try_dirs)
			if(found)
				break
			var/dx = dir[1]
			var/dy = dir[2]
			// Compute exact pixel shift needed to clear the chat rect in this direction
			// using the element deepest inside the chat (closest_key)
			var/shift = 0
			if(dx > 0) // moving right: element left edge must clear chat right edge
				shift = (chat_left + scaled_w) - el_x
			else if(dx < 0) // moving left: element right edge must clear chat left edge
				shift = el_x + ICON_SIZE_X - chat_left
			else if(dy > 0) // moving up: element bottom edge must clear chat top edge
				shift = (chat_bottom + scaled_h) - el_y
			else if(dy < 0) // moving down: element top edge must clear chat bottom edge
				shift = el_y + ICON_SIZE_Y - chat_bottom
			shift = ceil(shift)
			if(shift <= 0)
				continue
			var/test_dx = dx * shift
			var/test_dy = dy * shift
			// Verify ALL group members clear the chat at this exact shift
			var/still_overlaps = FALSE
			for(var/g_key in group)
				var/list/g_rect = element_rects[g_key]
				var/g_new_x = g_rect[1] + test_dx
				var/g_new_y = g_rect[2] + test_dy
				if(rects_overlap(g_new_x, g_new_y, g_rect[3], g_rect[4], chat_left, chat_bottom, scaled_w, scaled_h))
					still_overlaps = TRUE
					break
			// If some group members still overlap, find the max shift needed across all members
			if(still_overlaps)
				var/max_shift = shift
				for(var/g_key in group)
					var/list/g_rect = element_rects[g_key]
					var/member_shift = 0
					if(dx > 0)
						member_shift = (chat_left + scaled_w) - g_rect[1]
					else if(dx < 0)
						member_shift = g_rect[1] + g_rect[3] - chat_left
					else if(dy > 0)
						member_shift = (chat_bottom + scaled_h) - g_rect[2]
					else if(dy < 0)
						member_shift = g_rect[2] + g_rect[4] - chat_bottom
					max_shift = max(max_shift, member_shift)
				test_dx = dx * ceil(max_shift)
				test_dy = dy * ceil(max_shift)
			// Check the shifted position is on-screen
			var/ref_new_x = el_x + test_dx
			var/ref_new_y = el_y + test_dy
			if(ref_new_x < ICON_SIZE_X || ref_new_x > view_size[1] || ref_new_y < ICON_SIZE_Y || ref_new_y > view_size[2])
				continue
			delta_x = test_dx
			delta_y = test_dy
			found = TRUE
		if(!found)
			continue
		// Apply the same delta to every element in the group
		for(var/key in group)
			var/atom/movable/screen/obj = screen_objects[key]
			displaced_elements[key] = obj.screen_loc
			var/new_loc = apply_screen_loc_delta(obj.screen_loc, delta_x, delta_y)
			obj.screen_loc = new_loc
			var/list/rect = element_rects[key]
			element_rects[key] = list(rect[1] + delta_x, rect[2] + delta_y, rect[3], rect[4])
			displaced_count++
	// Cascade pass: check if any group overlaps another group's elements (handles both displaced-vs-displaced and undisplaced-vs-displaced)
	for(var/pass in 1 to 5)
		var/cascade_found = FALSE
		for(var/list/group in groups)
			// Check if any element in this group overlaps any element NOT in this group
			var/needs_move = FALSE
			for(var/key in group)
				var/list/rect = element_rects[key]
				for(var/other_key in element_rects)
					if(other_key in group)
						continue
					var/list/other_rect = element_rects[other_key]
					if(rects_overlap(rect[1], rect[2], rect[3], rect[4], other_rect[1], other_rect[2], other_rect[3], other_rect[4]))
						needs_move = TRUE
						break
				if(needs_move)
					break
			if(!needs_move)
				continue
			cascade_found = TRUE
			// Shift this group to clear all collisions (chat rect + other elements)
			var/ref_key = group[1]
			var/list/ref_rect = element_rects[ref_key]
			var/el_x = ref_rect[1]
			var/el_y = ref_rect[2]
			var/el_shift_x = (el_x > chat_left + scaled_w / 2) ? 1 : -1
			var/el_shift_y = (el_y > chat_bottom + scaled_h / 2) ? 1 : -1
			var/dist_to_h_edge = min(abs(el_x - chat_left), abs(el_x - (chat_left + scaled_w)))
			var/dist_to_v_edge = min(abs(el_y - chat_bottom), abs(el_y - (chat_bottom + scaled_h)))
			var/horizontal_first = dist_to_h_edge < dist_to_v_edge
			var/list/try_dirs = list()
			if(horizontal_first)
				try_dirs = list(list(el_shift_x, 0), list(0, el_shift_y), list(-el_shift_x, 0), list(0, -el_shift_y))
			else
				try_dirs = list(list(0, el_shift_y), list(el_shift_x, 0), list(0, -el_shift_y), list(-el_shift_x, 0))
			var/delta_x = 0
			var/delta_y = 0
			var/found = FALSE
			for(var/list/dir in try_dirs)
				if(found)
					break
				var/dx = dir[1]
				var/dy = dir[2]
				// Compute max pixel shift needed across all group members to clear all obstacles
				var/max_shift = 0
				for(var/g_key in group)
					var/list/g_rect = element_rects[g_key]
					// Check against chat rect
					if(rects_overlap(g_rect[1], g_rect[2], g_rect[3], g_rect[4], chat_left, chat_bottom, scaled_w, scaled_h))
						var/needed = 0
						if(dx > 0)
							needed = (chat_left + scaled_w) - g_rect[1]
						else if(dx < 0)
							needed = g_rect[1] + g_rect[3] - chat_left
						else if(dy > 0)
							needed = (chat_bottom + scaled_h) - g_rect[2]
						else if(dy < 0)
							needed = g_rect[2] + g_rect[4] - chat_bottom
						max_shift = max(max_shift, needed)
					// Check against all elements not in this group
					for(var/other_key in element_rects)
						if(other_key in group)
							continue
						var/list/other_rect = element_rects[other_key]
						if(rects_overlap(g_rect[1], g_rect[2], g_rect[3], g_rect[4], other_rect[1], other_rect[2], other_rect[3], other_rect[4]))
							var/needed = 0
							if(dx > 0)
								needed = (other_rect[1] + other_rect[3]) - g_rect[1]
							else if(dx < 0)
								needed = g_rect[1] + g_rect[3] - other_rect[1]
							else if(dy > 0)
								needed = (other_rect[2] + other_rect[4]) - g_rect[2]
							else if(dy < 0)
								needed = g_rect[2] + g_rect[4] - other_rect[2]
							max_shift = max(max_shift, needed)
				if(max_shift <= 0)
					continue
				max_shift = ceil(max_shift)
				var/test_dx = dx * max_shift
				var/test_dy = dy * max_shift
				// Verify the shifted position is on-screen and fully clear
				var/ref_new_x = el_x + test_dx
				var/ref_new_y = el_y + test_dy
				if(ref_new_x < ICON_SIZE_X || ref_new_x > view_size[1] || ref_new_y < ICON_SIZE_Y || ref_new_y > view_size[2])
					continue
				// Final verification: make sure no group member still collides
				var/still_collides = FALSE
				for(var/g_key in group)
					var/list/g_rect = element_rects[g_key]
					var/g_new_x = g_rect[1] + test_dx
					var/g_new_y = g_rect[2] + test_dy
					if(rects_overlap(g_new_x, g_new_y, g_rect[3], g_rect[4], chat_left, chat_bottom, scaled_w, scaled_h))
						still_collides = TRUE
						break
					for(var/other_key in element_rects)
						if(other_key in group)
							continue
						var/list/other_rect = element_rects[other_key]
						if(rects_overlap(g_new_x, g_new_y, g_rect[3], g_rect[4], other_rect[1], other_rect[2], other_rect[3], other_rect[4]))
							still_collides = TRUE
							break
					if(still_collides)
						break
				if(!still_collides)
					delta_x = test_dx
					delta_y = test_dy
					found = TRUE
			if(found)
				for(var/key in group)
					var/atom/movable/screen/obj = screen_objects[key]
					if(!displaced_elements[key])
						displaced_elements[key] = obj.screen_loc
					obj.screen_loc = apply_screen_loc_delta(obj.screen_loc, delta_x, delta_y)
					var/list/rect = element_rects[key]
					element_rects[key] = list(rect[1] + delta_x, rect[2] + delta_y, rect[3], rect[4])
					displaced_count++
		if(!cascade_found)
			break
	// Re-check action groups against the new chat rect
	if(listed_actions)
		listed_actions.check_against_view()
	if(palette_actions)
		palette_actions.check_against_view()
	// Refresh the debug overlay if active
	if(chat_debug_shown)
		update_chat_debug()

/// Restores all HUD elements to their original positions
/datum/hud/proc/restore_hud_displacement()
	for(var/key in displaced_elements)
		var/atom/movable/screen/obj = screen_objects[key]
		if(obj)
			obj.screen_loc = displaced_elements[key]
	displaced_elements.Cut()
	chat_rect_viewport = null
	// Restore action groups to their default sizing
	if(listed_actions)
		listed_actions.check_against_view()
	if(palette_actions)
		palette_actions.check_against_view()
	// Clear debug overlay since there's no chat rect anymore
	if(chat_debug_shown)
		update_chat_debug()

/// Displaces a single screen element if it overlaps the chat rect. Used for late-added elements.
/datum/hud/proc/displace_single_element(hud_key, atom/movable/screen/obj)
	if(!chat_rect_viewport || !obj.screen_loc || findtext(obj.screen_loc, " to ") || findtext(obj.screen_loc, "*"))
		return
	var/our_view = mymob?.canon_client?.view
	if(!our_view)
		return
	var/list/offsets = screen_loc_to_offset(obj.screen_loc, our_view)
	if(!offsets)
		return
	var/list/view_size = view_to_pixels(our_view)
	var/cv_left = chat_rect_viewport[1]
	var/cv_bottom = chat_rect_viewport[2]
	var/cv_w = chat_rect_viewport[3]
	var/cv_h = chat_rect_viewport[4]
	if(!rects_overlap(offsets[1], offsets[2], ICON_SIZE_X, ICON_SIZE_Y, cv_left, cv_bottom, cv_w, cv_h))
		return
	var/shift_y_dir = ((cv_bottom + cv_h / 2) > view_size[2] / 2) ? -1 : 1
	var/shift_x_dir = ((cv_left + cv_w / 2) > view_size[1] / 2) ? -1 : 1
	var/list/element_rects = list()
	for(var/key in screen_objects)
		if(key == hud_key)
			continue
		var/atom/movable/screen/other = screen_objects[key]
		if(!other.screen_loc || findtext(other.screen_loc, " to ") || findtext(other.screen_loc, "*"))
			continue
		var/list/other_offsets = screen_loc_to_offset(other.screen_loc, our_view)
		if(other_offsets)
			element_rects[key] = list(other_offsets[1], other_offsets[2], ICON_SIZE_X, ICON_SIZE_Y)
	var/new_x = offsets[1]
	var/new_y = offsets[2]
	var/displaced = FALSE
	for(var/attempt in 1 to 20)
		new_y += shift_y_dir * ICON_SIZE_Y
		if(!rects_overlap(new_x, new_y, ICON_SIZE_X, ICON_SIZE_Y, cv_left, cv_bottom, cv_w, cv_h) && !collides_with_any(new_x, new_y, ICON_SIZE_X, ICON_SIZE_Y, element_rects, hud_key))
			displaced = TRUE
			break
	if(!displaced)
		new_x = offsets[1]
		new_y = offsets[2]
		for(var/attempt in 1 to 20)
			new_x += shift_x_dir * ICON_SIZE_X
			if(!rects_overlap(new_x, new_y, ICON_SIZE_X, ICON_SIZE_Y, cv_left, cv_bottom, cv_w, cv_h) && !collides_with_any(new_x, new_y, ICON_SIZE_X, ICON_SIZE_Y, element_rects, hud_key))
				displaced = TRUE
				break
	if(displaced)
		displaced_elements[hud_key] = obj.screen_loc
		var/delta_x = new_x - offsets[1]
		var/delta_y = new_y - offsets[2]
		obj.screen_loc = apply_screen_loc_delta(obj.screen_loc, delta_x, delta_y)

ADMIN_VERB(debug_chat_rect, R_DEBUG, "Debug Chat Rect", "Toggles a debug overlay showing the chat browser rect as screen_loc tiles.", ADMIN_CATEGORY_DEBUG)
	var/datum/hud/hud = user.mob?.hud_used
	if(!hud)
		to_chat(user, span_warning("No HUD found."))
		return
	hud.toggle_chat_debug()
	to_chat(user, span_notice("Chat rect debug overlay [hud.chat_debug_shown ? "enabled" : "disabled"]."))

/// Checks if two rectangles overlap
/proc/rects_overlap(x1, y1, w1, h1, x2, y2, w2, h2)
	return !(x1 + w1 <= x2 || x2 + w2 <= x1 || y1 + h1 <= y2 || y2 + h2 <= y1)

/// Checks if a rect collides with any element rect in the list, excluding a specific key
/proc/collides_with_any(x, y, w, h, list/element_rects, exclude_key)
	for(var/key in element_rects)
		if(key == exclude_key)
			continue
		var/list/other = element_rects[key]
		if(rects_overlap(x, y, w, h, other[1], other[2], other[3], other[4]))
			return TRUE
	return FALSE

/// Toggles the debug overlay that visualizes the chat rect as converted to screen_loc coordinates
/datum/hud/proc/toggle_chat_debug()
	chat_debug_shown = !chat_debug_shown
	if(chat_debug_shown)
		update_chat_debug()
	else
		clear_chat_debug()

/// Clears the chat rect debug overlay
/datum/hud/proc/clear_chat_debug()
	var/client/client = mymob?.canon_client
	if(client && length(chat_debug_objects))
		client.screen -= chat_debug_objects
	QDEL_LIST(chat_debug_objects)
	chat_debug_objects = null

/// Updates the chat rect debug overlay to reflect the current chat_rect_viewport
/datum/hud/proc/update_chat_debug()
	clear_chat_debug()
	if(!chat_debug_shown)
		to_chat(world, span_boldannounce("DEBUG CHAT RECT: update called but debug not shown"))
		return
	if(!chat_rect_viewport || !length(chat_rect_viewport))
		to_chat(world, span_boldannounce("DEBUG CHAT RECT: no chat_rect_viewport! chat_rect=[chat_rect ? json_encode(chat_rect) : "null"] cached_map_view_size=[cached_map_view_size ? json_encode(cached_map_view_size) : "null"]"))
		return
	var/our_view = mymob?.canon_client?.view
	if(!our_view)
		to_chat(world, span_boldannounce("DEBUG CHAT RECT: no view"))
		return
	var/client/client = mymob.canon_client
	if(!client)
		to_chat(world, span_boldannounce("DEBUG CHAT RECT: no client"))
		return

	var/cv_left = chat_rect_viewport[1]
	var/cv_bottom = chat_rect_viewport[2]
	var/cv_w = chat_rect_viewport[3]
	var/cv_h = chat_rect_viewport[4]

	to_chat(world, span_boldannounce("DEBUG CHAT RECT: viewport rect = left:[cv_left] bottom:[cv_bottom] w:[cv_w] h:[cv_h]"))
	to_chat(world, span_boldannounce("DEBUG CHAT RECT: raw chat_rect = [json_encode(chat_rect)]"))
	to_chat(world, span_boldannounce("DEBUG CHAT RECT: cached_map_view_size = [json_encode(cached_map_view_size)]"))
	to_chat(world, span_boldannounce("DEBUG CHAT RECT: view = [our_view]"))

	chat_debug_objects = list()

	// Clamp to viewport pixel bounds
	var/list/view_size = view_to_pixels(our_view)
	var/clamped_left = max(cv_left, 0)
	var/clamped_bottom = max(cv_bottom, 0)
	var/clamped_right = min(cv_left + cv_w, view_size[1])
	var/clamped_top = min(cv_bottom + cv_h, view_size[2])
	var/rect_w = round(clamped_right - clamped_left)
	var/rect_h = round(clamped_top - clamped_bottom)
	if(rect_w <= 0 || rect_h <= 0)
		return

	// Chat rect is in viewport pixel space — use manual tile:pixel with +1 for 1-indexing
	var/left_tile = round(clamped_left / ICON_SIZE_X) + 1
	var/left_px = round(clamped_left) % ICON_SIZE_X
	var/bottom_tile = round(clamped_bottom / ICON_SIZE_Y) + 1
	var/bottom_px = round(clamped_bottom) % ICON_SIZE_Y
	var/bottom_left_loc = "[left_tile]:[left_px],[bottom_tile]:[bottom_px]"

	var/top_rounded = round(clamped_top)
	var/top_tile = round(top_rounded / ICON_SIZE_Y) + 1
	var/top_px = top_rounded % ICON_SIZE_Y
	var/top_left_loc = "[left_tile]:[left_px],[top_tile]:[top_px]"

	to_chat(world, span_boldannounce("DEBUG CHAT RECT: screen_loc [bottom_left_loc] size [rect_w]x[rect_h]"))

	// Create a single icon scaled to the exact rect size
	var/icon/debug_rect = icon('icons/blanks/32x32.dmi', "nothing")
	debug_rect.Scale(rect_w, rect_h)
	debug_rect.DrawBox("#FFFFFF", 1, 1, rect_w, rect_h)

	var/atom/movable/screen/fill = new
	fill.icon = debug_rect
	fill.screen_loc = bottom_left_loc
	fill.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	fill.color = "#ff0000"
	fill.alpha = 50
	chat_debug_objects += fill

	// Info label at top-left of the rect
	var/atom/movable/screen/label = new
	label.icon = null
	label.screen_loc = top_left_loc
	label.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	label.maptext_width = 256
	label.maptext_height = 48
	label.maptext = {"<span style='font-size:6pt;font-family:monospace;background:rgba(0,0,0,0.7);padding:1px 3px'>
		<span style='color:#ff4444'>chat_vp: [round(cv_left)]x[round(cv_bottom)] [round(cv_w)]x[round(cv_h)]</span><br>
		<span style='color:#44ff44'>chat_raw: [chat_rect[1]]x[chat_rect[2]] [chat_rect[3]]x[chat_rect[4]]</span>
		</span>"}
	chat_debug_objects += label

	// Build group name lookup from get_displacement_groups()
	var/list/key_to_group_name = list()
	var/list/debug_groups = get_displacement_groups()
	for(var/group_idx in 1 to length(debug_groups))
		var/list/group = debug_groups[group_idx]
		for(var/key in group)
			key_to_group_name[key] = "group_[group_idx]"

	// Collect displaced elements into groups with bounding boxes
	// group_name -> list("min_x", "min_y", "max_x", "max_y", "dx", "dy", "count", "members")
	var/list/group_bounds = list()
	for(var/key in displaced_elements)
		var/original_loc = displaced_elements[key]
		var/atom/movable/screen/obj = screen_objects[key]
		if(!obj)
			continue
		var/list/new_offsets = screen_loc_to_offset(obj.screen_loc, our_view)
		var/list/orig_offsets = screen_loc_to_offset(original_loc, our_view)
		if(!new_offsets || !orig_offsets)
			continue
		var/gname = key_to_group_name[key] || "u:[key]"
		var/dx = new_offsets[1] - orig_offsets[1]
		var/dy = new_offsets[2] - orig_offsets[2]
		to_chat(world, span_boldannounce("DEBUG DISPLACED: [key] ([gname]) loc=[obj.screen_loc] orig=[original_loc] offset=[new_offsets[1]],[new_offsets[2]] d=[dx],[dy]"))
		if(!group_bounds[gname])
			group_bounds[gname] = list(
				"min_x" = new_offsets[1],
				"min_y" = new_offsets[2],
				"max_x" = new_offsets[1] + ICON_SIZE_X,
				"max_y" = new_offsets[2] + ICON_SIZE_Y,
				"dx" = dx,
				"dy" = dy,
				"count" = 1,
			)
		else
			var/list/bounds = group_bounds[gname]
			bounds["min_x"] = min(bounds["min_x"], new_offsets[1])
			bounds["min_y"] = min(bounds["min_y"], new_offsets[2])
			bounds["max_x"] = max(bounds["max_x"], new_offsets[1] + ICON_SIZE_X)
			bounds["max_y"] = max(bounds["max_y"], new_offsets[2] + ICON_SIZE_Y)
			bounds["count"] += 1

	// Draw a box and label per group
	var/static/list/group_colors = list("#4488ff", "#44ff88", "#ff8844", "#ff44ff", "#ffff44", "#44ffff", "#ff4444", "#88ff44")
	var/color_idx = 0
	for(var/gname in group_bounds)
		color_idx++
		var/list/bounds = group_bounds[gname]
		var/gcolor = group_colors[((color_idx - 1) % length(group_colors)) + 1]
		var/box_x = bounds["min_x"]
		var/box_y = bounds["min_y"]
		var/box_w = round(bounds["max_x"] - bounds["min_x"])
		var/box_h = round(bounds["max_y"] - bounds["min_y"])
		if(box_w <= 0 || box_h <= 0)
			continue
		// Box fill
		// screen_loc_to_offset returns values with a 1-tile bias (tile 1 = offset 32, not 0)
		// but offset_to_screen_loc renders tile 1 at viewport pixel 0, so subtract the bias
		var/icon/group_icon = icon('icons/blanks/32x32.dmi', "nothing")
		group_icon.Scale(box_w, box_h)
		group_icon.DrawBox("#FFFFFF", 1, 1, box_w, box_h)
		var/box_loc = offset_to_screen_loc(round(box_x), round(box_y))
		var/atom/movable/screen/group_box = new
		group_box.icon = group_icon
		group_box.screen_loc = box_loc
		group_box.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		group_box.color = gcolor
		group_box.alpha = 60
		chat_debug_objects += group_box
		// Label at top-left of group box
		var/label_loc = offset_to_screen_loc(round(box_x), round(bounds["max_y"]))
		var/atom/movable/screen/group_label = new
		group_label.icon = null
		group_label.screen_loc = label_loc
		group_label.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		group_label.maptext_width = 200
		group_label.maptext_height = 24
		group_label.maptext = {"<span style='font-size:5pt;font-family:monospace;background:rgba(0,0,0,0.85);color:[gcolor];padding:1px 2px;white-space:nowrap'>
			[gname] ([bounds["count"]]) d:[bounds["dx"]],[bounds["dy"]]
			</span>"}
		chat_debug_objects += group_label

	client.screen += chat_debug_objects
	to_chat(world, span_boldannounce("DEBUG CHAT RECT: done, [length(chat_debug_objects)] objects on screen, [length(displaced_elements)] displaced in [length(group_bounds)] groups"))

/// Generates and fills new action groups with our mob's current actions
/datum/hud/proc/build_action_groups()
	listed_actions = new(src)
	palette_actions = new(src)
	floating_actions = list()
	for(var/datum/action/action as anything in mymob.actions)
		var/atom/movable/screen/movable/action_button/button = action.viewers[src]
		if(!button)
			action.ShowTo(mymob)
		else
			position_action(button, button.location)
