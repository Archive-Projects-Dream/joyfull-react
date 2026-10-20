// Soulcatcher system defines.
// Ported from NovaSector (modular_nova/modules/modular_implants) - dependency of the shipbreaking port (PR #7638).

/// Default color of chat messages sent by soulcatcher rooms.
#define SOULCATCHER_DEFAULT_COLOR "#75D5E1"

/// Warning message shown to souls that enter a soulcatcher.
#define SOULCATCHER_WARNING_MESSAGE "You have entered a soulcatcher, do not share any information you have received while a ghost. \
	If you have died within the round, you do not know your identity until your body has been scanned, standard blackout policy also applies."

// SOULCATCHER SIGNALS

/// From /mob/grab_ghost(): sent to check if the mob's soul is currently inside of a soulcatcher.
#define COMSIG_SOULCATCHER_CHECK_SOUL "soulcatcher_check_soul"

/// From /datum/component/soulcatcher/proc/scan_body(): sent when a body that hosts a soulcatcher soul is scanned.
#define COMSIG_SOULCATCHER_SCAN_BODY "soulcatcher_scan_body"

/// From /datum/component/soulcatcher/proc/update_joinability(): sent when the ghost joinability of a soulcatcher changes.
#define COMSIG_SOULCATCHER_UPDATE_JOINABILITY "soulcatcher_update_joinability"

// SOULCATCHER SPANS
// CSS classes for these are added to the chat stylesheets (tgui/packages/tgui-panel/styles/tgchat/).

#define span_cyan_nova(str) ("<span class='cyan_nova'>" + str + "</span>")
#define span_doyourjobidiot(str) ("<span class='doyourjobidiot'>" + str + "</span>")

// SOULCATCHER TRAITS

/// Trait given to a brain that is able to accept souls from a RSD. Granted by /obj/item/rsd_interface.
#define TRAIT_RSD_COMPATIBLE "rsd_compatible"

// SOULCATCHER GHOST HUD BUTTON

/// HUD key of the ghost screen button used to join soulcatchers.
#define HUD_GHOST_SOULCATCHER "ghost_soulcatcher"

/// Screen location of the ghost screen button used to join soulcatchers.
#define ui_ghost_soulcatcher "SOUTH:6, CENTER-4:24"
