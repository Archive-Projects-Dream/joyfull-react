/datum/player_ticket_panel
	var/selected_tab = "admin"
	var/selected_ticket = null

/datum/player_ticket_panel/Destroy(force, ...)
	SStgui.close_uis(src)
	return ..()

/datum/player_ticket_panel/proc/instant_update()
	SStgui.update_uis(src)

/datum/player_ticket_panel/ui_state(mob/user)
	return GLOB.always_state

/datum/player_ticket_panel/proc/format_response_author(client/viewer, author)
	if(!istext(author) || author == "System")
		return "System"
	if(ckey(author) == viewer?.ckey)
		return "You"
	return author

/datum/player_ticket_panel/proc/format_player_adminhelp_ticket(datum/admin_help/AH, client/viewer)
	var/status = AH.state == AHELP_ACTIVE ? "open" : AH.state == AHELP_RESOLVED ? "resolved" : "closed"

	var/list/formatted_responses = list()
	for(var/key in AH.ticket_interactions)
		var/list/interaction = AH.ticket_interactions[key]
		var/list/stripped = interaction.Copy()
		stripped["message"] = strip_pm_prefix(stripped["message"])
		stripped["author"] = format_response_author(viewer, stripped["author"])
		formatted_responses += list(stripped)

	return list(
		"id" = AH.id,
		"subject" = AH.subject,
		"status" = status,
		"timestamp" = AH.time_activity["opened_at"],
		"closed_at" = AH.time_activity["closed_at"],
		"claimed_by" = AH.marked_admin,
		"all_responses" = formatted_responses,
		"is_archived" = (AH.state != AHELP_ACTIVE),
	)

/datum/player_ticket_panel/proc/format_player_mentorhelp_ticket(datum/mentorhelp/MH, client/viewer)
	if(!viewer)
		viewer = usr.client

	var/status = MH.open ? (MH.mentor ? "claimed" : "open") : "closed"

	var/list/formatted_responses = list()
	for(var/key in MH.ticket_interactions)
		var/list/interaction = MH.ticket_interactions[key]
		var/list/stripped = interaction.Copy()
		stripped["message"] = strip_pm_prefix(stripped["message"])
		stripped["author"] = format_response_author(viewer, stripped["author"])
		formatted_responses += list(stripped)

	return list(
		"id" = MH.id,
		"subject" = MH.subject,
		"status" = status,
		"timestamp" = MH.time_activity["opened_at"],
		"closed_at" = MH.time_activity["closed_at"],
		"claimed_by" = MH.mentor ? MH.mentor.ckey : null,
		"all_responses" = formatted_responses,
		"is_archived" = !MH.open,
	)

/datum/player_ticket_panel/proc/has_own_tickets(client/C, tab)
	if(!C)
		return FALSE
	if(tab == "admin")
		return length(GLOB.ahelp_tickets.TicketsByCKey(C.ckey)) > 0
	for(var/list/mhelp_list in list(GLOB.mentorhelp_manager.active_tickets, GLOB.mentorhelp_manager.archived_tickets))
		for(var/id in mhelp_list)
			var/datum/mentorhelp/MH = mhelp_list[id]
			if(istype(MH) && ckey(MH.author_key) == C.ckey)
				return TRUE
	return FALSE

/datum/player_ticket_panel/proc/pick_best_ticket(client/C)
	if(!C)
		return
	if(selected_tab == "admin")
		var/datum/admin_help/open_admin = GLOB.ahelp_tickets.CKey2ActiveTicket(C.ckey)
		if(open_admin)
			selected_ticket = open_admin.id
			return
		var/datum/admin_help/last_admin
		for(var/datum/admin_help/AH in GLOB.ahelp_tickets.TicketsByCKey(C.ckey))
			if(AH.state != AHELP_ACTIVE && (!last_admin || AH.id > last_admin.id))
				last_admin = AH
		selected_ticket = last_admin?.id
		return
	var/datum/mentorhelp/open_mentor = GLOB.mentorhelp_manager.get_active_ticket_by_ckey(C.ckey)
	if(open_mentor)
		selected_ticket = open_mentor.id
		return
	var/datum/mentorhelp/last_mentor
	for(var/id in GLOB.mentorhelp_manager.archived_tickets)
		var/datum/mentorhelp/MH = GLOB.mentorhelp_manager.archived_tickets[id]
		if(istype(MH) && ckey(MH.author_key) == C.ckey && (!last_mentor || MH.id > last_mentor.id))
			last_mentor = MH
	selected_ticket = last_mentor?.id

/datum/player_ticket_panel/proc/get_own_ticket_history(client/C)
	var/list/history = list()
	if(!C)
		return history

	for(var/datum/admin_help/AH in GLOB.ahelp_tickets.TicketsByCKey(C.ckey))
		history += list(list("tab" = "admin", "id" = AH.id, "opened_at" = AH.opened_at))

	for(var/list/mhelp_list in list(GLOB.mentorhelp_manager.active_tickets, GLOB.mentorhelp_manager.archived_tickets))
		for(var/id in mhelp_list)
			var/datum/mentorhelp/MH = mhelp_list[id]
			if(istype(MH) && ckey(MH.author_key) == C.ckey)
				history += list(list("tab" = "mentor", "id" = MH.id, "opened_at" = MH.opened_at))

	sortTim(history, GLOBAL_PROC_REF(cmp_player_ticket_history_asc))
	return history

/proc/cmp_player_ticket_history_asc(list/a, list/b)
	return a["opened_at"] - b["opened_at"]

/datum/player_ticket_panel/ui_data(mob/user)
	var/client/C = user?.client
	if(!C)
		return

	if(isnull(selected_ticket) || !get_own_ticket(C, selected_ticket))
		pick_best_ticket(C)

	var/list/data = list(
		"selected_tab" = selected_tab,
		"has_admin_tickets" = has_own_tickets(C, "admin"),
		"has_mentor_tickets" = has_own_tickets(C, "mentor"),
		"selected_ticket" = null,
	)

	if(!isnull(selected_ticket))
		var/datum/own_ticket = get_own_ticket(C, selected_ticket)
		if(selected_tab == "admin")
			var/datum/admin_help/AH = own_ticket
			if(AH)
				data["selected_ticket"] = format_player_adminhelp_ticket(AH, C)
		else
			var/datum/mentorhelp/MH = own_ticket
			if(MH)
				data["selected_ticket"] = format_player_mentorhelp_ticket(MH, C)

	var/list/ticket_history = get_own_ticket_history(C)
	var/history_index = 0
	for(var/i in 1 to length(ticket_history))
		var/list/entry = ticket_history[i]
		if(entry["tab"] == selected_tab && entry["id"] == selected_ticket)
			history_index = i
			break
	data["ticket_history_count"] = length(ticket_history)
	data["ticket_history_index"] = history_index

	return data

/datum/player_ticket_panel/proc/get_own_ticket(client/C, ticket_id)
	if(!C || !ticket_id)
		return null
	if(selected_tab == "admin")
		for(var/datum/admin_help/AH in GLOB.ahelp_tickets.TicketsByCKey(C.ckey))
			if(AH.id == ticket_id)
				return AH
	else
		var/datum/mentorhelp/MH = mentorhelp_by_id(ticket_id)
		if(istype(MH) && ckey(MH.author_key) == C.ckey)
			return MH
	return null

/datum/player_ticket_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/client/C = ui.user?.client
	if(!C)
		return

	switch(action)
		if("select_tab")
			var/tab = params["tab"]
			if(tab != "admin" && tab != "mentor")
				return FALSE
			selected_tab = tab
			selected_ticket = null
			pick_best_ticket(C)
			return TRUE

		if("cycle_ticket")
			var/direction = text2num(params["direction"])
			if(!direction)
				return FALSE
			var/list/history = get_own_ticket_history(C)
			if(length(history) < 2)
				return FALSE
			var/current_index = 0
			for(var/i in 1 to length(history))
				var/list/entry = history[i]
				if(entry["tab"] == selected_tab && entry["id"] == selected_ticket)
					current_index = i
					break
			if(!current_index)
				return FALSE
			var/new_index = clamp(current_index + (direction > 0 ? 1 : -1), 1, length(history))
			if(new_index == current_index)
				return FALSE
			var/list/new_entry = history[new_index]
			selected_tab = new_entry["tab"]
			selected_ticket = new_entry["id"]
			return TRUE

		if("new_ticket")
			GLOB.admin_help_ui_handler.ui_interact(C.mob)
			return TRUE

		if("reply_ticket")
			var/message = sanitize_text(trim(params["message"]))
			var/ticket_id = text2num(params["ticket_id"])
			if(!message || !ticket_id)
				return FALSE

			var/datum/own_ticket = get_own_ticket(C, ticket_id)
			if(!own_ticket)
				return FALSE

			if(selected_tab == "admin")
				var/datum/admin_help/AH = own_ticket
				if(AH.state != AHELP_ACTIVE || C.current_ticket != AH)
					to_chat(C, span_warning("This ticket is closed. Please open a new one instead."), confidential = TRUE)
					return FALSE
				// Reuses the F1 window pipeline (mute, spam and say_disabled checks)
				GLOB.admin_help_ui_handler.perform_adminhelp(C, message, FALSE)
			else
				var/datum/mentorhelp/MH = own_ticket
				if(!MH.open || C.current_mhelp != MH)
					to_chat(C, span_warning("This mentor ticket is closed. Please open a new one instead."), confidential = TRUE)
					return FALSE
				GLOB.admin_help_ui_handler.perform_mentorhelp(C, message)

			instant_update()
			return TRUE

		if("close_ticket")
			var/ticket_id = text2num(params["ticket_id"])
			if(!ticket_id)
				return FALSE

			if(selected_tab == "mentor")
				var/datum/mentorhelp/MH = get_own_ticket(C, ticket_id)
				if(!istype(MH) || !MH.open)
					return FALSE

				MH.close(C)
			else
				var/datum/admin_help/AH = get_own_ticket(C, ticket_id)
				if(!istype(AH) || AH.state != AHELP_ACTIVE)
					return FALSE

				AH.player_close(C)

			instant_update()
			return TRUE

/datum/player_ticket_panel/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PlayerTicketPanel", "Ticket Panel")
		ui.set_autoupdate(TRUE)
		ui.open()

/datum/player_ticket_panel/proc/open_for(client/C)
	if(!C)
		return

	selected_ticket = null
	selected_tab = "admin"

	if(istype(C.current_ticket))
		selected_ticket = C.current_ticket.id
	else if(istype(C.current_mhelp) && C.current_mhelp.open)
		selected_tab = "mentor"
	else
		// No open ticket: prefer whichever type has the newest archived one
		var/datum/admin_help/last_admin
		for(var/datum/admin_help/AH in GLOB.ahelp_tickets.TicketsByCKey(C.ckey))
			if(AH.state != AHELP_ACTIVE && (!last_admin || AH.id > last_admin.id))
				last_admin = AH
		var/datum/mentorhelp/last_mentor
		for(var/id in GLOB.mentorhelp_manager.archived_tickets)
			var/datum/mentorhelp/MH = GLOB.mentorhelp_manager.archived_tickets[id]
			if(istype(MH) && ckey(MH.author_key) == C.ckey && (!last_mentor || MH.id > last_mentor.id))
				last_mentor = MH
		if(!last_admin && last_mentor)
			selected_tab = "mentor"

	// Fill in the selection for the chosen tab if it was not set above
	if(isnull(selected_ticket))
		pick_best_ticket(C)

	if(C.mob)
		ui_interact(C.mob)
