import {
  onPanelWindowClosed,
  onPanelWindowOpened,
} from '../../chat/chat-hover-strip';

/**
 * A TGUI window just opened. The on-map chat checks whether the new
 * window landed on the chat's rect and, if so, yields to it by staying
 * collapsed to its peek strip until the window is gone - a window that
 * pops out over the chat would otherwise truncate it in half.
 */
export function panelWindowOpened(payload: { id?: string } | undefined) {
  if (typeof payload?.id === 'string') {
    onPanelWindowOpened(payload.id);
  }
}

/**
 * A TGUI window closed (or was suspended). The chat can take its rect
 * back as soon as nothing is squatting on it anymore.
 */
export function panelWindowClosed(payload: { id?: string } | undefined) {
  if (typeof payload?.id === 'string') {
    onPanelWindowClosed(payload.id);
  }
}
