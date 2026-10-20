/// Character text preferences read by the soulcatcher system when a soul joins a room.
/// Minimal port of NovaSector's flavor_text preferences (modular_nova/master_files/code/modules/client/preferences/flavor_text.dm).
/// The soulcatcher reads these directly through `preferences.read_preference()`.
/datum/preference/text/flavor_text
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "flavor_text"
	maximum_value_length = 2000

/datum/preference/text/ooc_notes
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "ooc_notes"
	maximum_value_length = 2000
