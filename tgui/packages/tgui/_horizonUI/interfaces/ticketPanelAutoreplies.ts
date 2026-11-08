/**
 * Canned auto-replies for the staff ticket panel.
 *
 * This data used to live in the BYOND backend (_horizon autoreply.dm) and was
 * picked through a tgui_input_list modal. It is presentation data, so it now
 * lives here; the backend only receives the chosen title and message text
 * through the `autoreply` ui_act and applies it.
 */

export type AutoReply = {
  /** Shown on the picker button and in the "- AdminHelp marked as X! -" header. */
  title: string;
  /** The canned message sent to the player. */
  message: string;
  /** Whether sending this reply also resolves the ticket (admin replies only). */
  resolve?: boolean;
};

export const ADMIN_AUTOREPLIES: AutoReply[] = [
  {
    title: 'Being Handled',
    message:
      'Staff are aware of this issue and it is being handled',
    resolve: false,
  },
  {
    title: 'IC Issue',
    message:
      'Your issue has been determined by an administrator to be an in character issue and does NOT require administrator intervention at this time. For further resolution you should pursue options that are in character.',
    resolve: true,
  },
  {
    title: 'Bug Report',
    message:
      'Please report all bugs on our Github. Administrative staff are unable to fix most bugs on a round to round basis and only round critical bugs, or exploits, should be ahelped.',
    resolve: true,
  },
  {
    title: 'Changelog',
    message:
      'The answer to your question can be found in the Changelog. Click the changelog button at the top-right of the screen to view it in-game.',
    resolve: true,
  },
  {
    title: 'Intended',
    message:
      'This is an intended feature and therefore does not need admin intervention.',
    resolve: true,
  },
  {
    title: 'Event',
    message:
      'There is currently a special event running and many things may be changed or different, however normal rules still apply unless you have been specifically instructed otherwise by a staff member.',
    resolve: true,
  },
  {
    title: 'Clear Cache',
    message:
      'In order to clear cache, you need to click on gear icon located in upper-right corner of your BYOND client and select preferences. Switch to Games tab and click Clear Cache button. In some cases you need to manually delete cache. To do that, select Advanced tab and click Open User Directory and delete "cache" folder there.',
    resolve: false,
  },
  {
    title: 'Cryo and Ghost to Lobby',
    message:
      'Staff have approved your request to be returned to the lobby. In order to do so, you must enter a cryogenics bay and ghost. You will be then manually returned to the lobby by staff.',
    resolve: false,
  },
];

export const MENTOR_AUTOREPLIES: AutoReply[] = [
  {
    title: 'A: Staff Issue',
    message:
      'This is not something that mentors can help with, please contact the staff team via AdminHelp.',
  },
  {
    title: 'A: Event in Progress',
    message:
      'There is currently a special event running and many things may be changed or different, however normal rules still apply unless you have been specifically instructed otherwise by a staff member.',
  },
  {
    title: 'C: Changelog',
    message:
      'The answer to your question can be found in the Changelog. Click the changelog button at the top-right of the screen to view it in-game.',
  },
  {
    title: 'C: Joining the Server',
    message:
      'Joining for new players is disabled for the current round due to either a staff member or an automatic setting during the end of the round. You can observe while it ends and wait for a new round to start.',
  },
  {
    title: 'C: Leaving the Server',
    message:
      'If you need to leave the server, go to cryo (cryogenic sleep) or ask someone to put you in cryo before leaving.',
  },
  {
    title: 'C: Clear Cache',
    message:
      'In order to clear cache, you need to click on gear icon located in upper-right corner of your BYOND client and select preferences. Switch to Games tab and click Clear Cache button. In some cases you need to manually delete cache. To do that, select Advanced tab and click Open User Directory and delete "cache" folder there.',
  },
  {
    title: 'C: Combat Click-Drag Override',
    message:
      'When clicking while moving the mouse, Byond sometimes detects it as a click-and-drag attempt and prevents the click from taking effect, even if the button was only held down for an instant. This toggle means that when you\'re on disarm or harm intent, depressing the mouse triggers a click immediately even if you hold it down - unless you\'re trying to click-drag yourself, an ally, or something in your own inventory.',
  },
  {
    title: 'L: Bug Report',
    message:
      'Please report all bugs on our Github. Administrative staff are unable to fix most bugs on a round to round basis and only round critical bugs, or exploits, should be ahelped.',
  },
  {
    title: 'L: Macros',
    message:
      'You can set up macros in your client preferences. Go to the gear icon in the upper-right corner, select Preferences, then Keybindings to customize your hotkeys.',
  },
  {
    title: 'H: Radio',
    message:
      'Take your headset in hand and activate it by clicking it or pressing "Page Down" or "Z" (in Hotkey Mode). This will open a window with all available channels, which also contains channel keys. Department headsets have access to their respective department channel on ":h" key and the common channel on ";" key.',
  },
];
