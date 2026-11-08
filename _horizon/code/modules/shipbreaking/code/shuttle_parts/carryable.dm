/**
 * ## Ship components
 *
 * Two-handed carryable forms of ship fixtures, covering the shipbreaking round trip:
 *
 * cutting or unfastening a fixture leaves a heavy loose structure on the floor.
 * Clicking that loose structure with an empty hand folds it into a
 * [/obj/item/ship_component], which takes both hands to carry. Using the component
 * on a fitting target installs the fixture back:
 *
 * * hull wall plating - used on a girder or titanium framing: rebuilds the hull wall
 * * hull floor plating - used on an open floor or bare space: restores the hull floor turf
 * * cut shuttle window - used on a grille: rebuilds the window
 * * stamped wall plates - used on any open turf: re-mounts the wall plate decoration
 * * everything else - used on any open turf: re-places the fixture, fastened down
 */
/obj/item/ship_component
	name = "ship component"
	desc = "A heavy piece of ship hardware, waiting to be bolted back onto a hull."
	icon = '_horizon/code/modules/shipbreaking/icons/exterior.dmi'
	icon_state = "rcs"
	w_class = WEIGHT_CLASS_BULKY
	item_flags = SLOWS_WHILE_IN_HAND
	force = 5
	throwforce = 10
	throw_range = 2
	throw_speed = 1
	slowdown = 1
	/// What structure or machinery we install back onto a plain turf
	var/obj/installs_type
	/// What wall turf we rebuild when used on a girder or titanium framing
	var/turf/reinstalls_wall
	/// What floor turf we restore when used on an open floor
	var/turf/restores_turf
	/// What window we rebuild when used on a grille
	var/obj/reinstalls_window
	/// What wall plate decoration we re-mount (stamped onto plating when it's cut free)
	var/obj/reinstalls_decoration
	/// How long installing this component takes
	var/install_time = 2 SECONDS

/obj/item/ship_component/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/two_handed, require_twohands = TRUE, force_wielded = 12, force_unwielded = 4)

/obj/item/ship_component/examine(mob/user)
	. = ..()
	. += span_notice("It takes <b>both hands</b> to carry. Use it on a girder, a grille or an open floor to install it back.")

/// Copies everything that makes us "this exact fixture" off the structure we absorb
/obj/item/ship_component/proc/absorb(atom/movable/source)
	installs_type = source.type
	setDir(source.dir)
	icon = source.icon
	icon_state = source.icon_state
	color = source.color
	name = source.name
	desc = source.desc
	custom_materials = source.custom_materials?.Copy()
	lefthand_file = icon
	righthand_file = icon
	if(istype(source, /obj/structure/hull_plating))
		var/obj/structure/hull_plating/plating = source
		reinstalls_wall = plating.reinstalls_wall
		restores_turf = plating.restores_turf
		reinstalls_window = plating.reinstalls_window
		reinstalls_decoration = plating.reinstalls_decoration

/obj/item/ship_component/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ITEM_INTERACT_SKIP_TO_ATTACK
	// Only install on turfs and structures, so mobs can still be bonked
	if(!isturf(interacting_with) && !isstructure(interacting_with))
		return NONE
	var/turf/target_turf = get_turf(interacting_with)
	if(!target_turf || target_turf.density)
		return NONE

	// Hull wall plating: bolt it back onto the framing
	if(reinstalls_wall && (istype(interacting_with, /obj/structure/girder) || istype(interacting_with, /obj/structure/titanium_structure)))
		balloon_alert(user, "installing hull...")
		if(!do_after(user, install_time, interacting_with))
			return ITEM_INTERACT_BLOCKING
		playsound(src, 'sound/items/tools/ratchet.ogg', 50, TRUE)
		var/turf/new_wall = target_turf.place_on_top(reinstalls_wall)
		if(istype(new_wall, /turf/closed/wall))
			var/turf/closed/wall/wall = new_wall
			// Remember which framing this wall came from, so it breaks back into it
			wall.girder_type = interacting_with.type
			if(color)
				wall.color = color
		qdel(interacting_with)
		qdel(src)
		return ITEM_INTERACT_SUCCESS

	// Cut windows: glaze them back into a grille
	if(reinstalls_window && istype(interacting_with, /obj/structure/grille))
		balloon_alert(user, "installing window...")
		if(!do_after(user, install_time, interacting_with))
			return ITEM_INTERACT_BLOCKING
		playsound(src, 'sound/items/unsheath.ogg', 50, TRUE)
		new reinstalls_window(target_turf)
		qdel(src)
		return ITEM_INTERACT_SUCCESS

	// Floor plating: lay the hull floor back down (stamped plates re-mount as their decoration instead)
	if(restores_turf && !reinstalls_decoration && (isfloorturf(interacting_with) || istype(interacting_with, /turf/open/space)))
		if(istype(interacting_with, restores_turf))
			balloon_alert(user, "already plated!")
			return ITEM_INTERACT_BLOCKING
		balloon_alert(user, "laying plating...")
		if(!do_after(user, install_time, interacting_with))
			return ITEM_INTERACT_BLOCKING
		playsound(src, 'sound/items/tools/ratchet.ogg', 50, TRUE)
		var/turf/new_floor = target_turf.place_on_top(restores_turf, flags = CHANGETURF_INHERIT_AIR)
		if(color)
			new_floor.color = color
		qdel(src)
		return ITEM_INTERACT_SUCCESS

	// Generic placement: re-mount the wall plate we were cut from, or the fixture itself
	var/obj/place_type = reinstalls_decoration || installs_type
	if(!place_type)
		return NONE
	if(target_turf.is_blocked_turf(TRUE))
		balloon_alert(user, "no room to install!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "installing...")
	if(!do_after(user, install_time, interacting_with))
		return ITEM_INTERACT_BLOCKING
	playsound(src, 'sound/items/tools/ratchet.ogg', 50, TRUE)
	var/obj/installed = new place_type(target_turf)
	installed.setDir(dir)
	if(color)
		installed.color = color
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/// Folds a detached, unfastened ship fixture into its two-handed carryable form
/proc/try_carry_component(atom/movable/component, mob/living/user)
	if(!isliving(user))
		return FALSE
	if(component.anchored)
		component.balloon_alert(user, "still fastened down!")
		return FALSE
	var/obj/item/ship_component/carried = new(component.loc)
	carried.absorb(component)
	if(!user.put_in_hands(carried))
		qdel(carried)
		component.balloon_alert(user, "need a free hand!")
		return FALSE
	component.transfer_fingerprints_to(carried)
	user.visible_message(
		span_notice("[user] hefts [carried] off the ground."),
		span_notice("You heft [carried] into your arms."),
	)
	playsound(component, 'sound/effects/bang.ogg', 25, TRUE)
	qdel(component)
	return TRUE
