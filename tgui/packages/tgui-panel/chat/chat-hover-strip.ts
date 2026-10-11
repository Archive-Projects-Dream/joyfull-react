/**
 * Click-through hover strip for the on-map frameless chat.
 *
 * A browser control swallows every click inside its rect, so a chat that
 * floats over the map blocks input on the turfs and screen objects behind
 * it. While this mode is on, the collapsed chat shrinks the browseroutput
 * control down to a thin strip along the chat's bottom edge: everything
 * above the strip is bare map again and clicks fall straight through.
 * Hovering the strip grows the control back to the full chat rect.
 *
 * Panel.tsx drives this module: it turns the mode on and off as the
 * relevant settings change, and routes the body hover events through here.
 * ResizeHandles reports drags so a resize never races the collapse.
 */
import { store } from '../events/store';
import { settingsVisibleAtom } from '../settings/atoms';
import { chatRenderer } from './renderer';

const COLLAPSE_DELAY = 300;
const SELECT_RETRY_DELAY = 500;
const SELECT_MAX_RETRIES = 8;

/** Height of the strip the collapsed chat collapses to, in control pixels. */
export const CHAT_STRIP_HEIGHT = 22;

type RectRatio = {
  x: number;
  y: number;
  w: number;
  h: number;
};

let mode = false;
let collapsed = false;
let fullRect: RectRatio | null = null;
let collapseTimer: ReturnType<typeof setTimeout> | undefined;
let selectRetries = 0;
let dragging = false;
let focusedBeforeCollapse: HTMLElement | null = null;

export function isChatStripCollapsed(): boolean {
  return collapsed;
}

/**
 * True while the user is mid-composition in an input. The command bar
 * auto-focuses even when it is empty, so an empty focused input alone is
 * no reason to keep the chat open.
 */
function isComposing(): boolean {
  const node = document.activeElement;
  if (node instanceof HTMLInputElement) {
    return node.value.length > 0;
  }
  if (
    node instanceof HTMLTextAreaElement ||
    (node instanceof HTMLElement && node.isContentEditable)
  ) {
    return true;
  }
  return false;
}

/** True while a non-empty text selection is being made inside the chat. */
function isSelecting(): boolean {
  const selection = window.getSelection();
  return !!selection && !selection.isCollapsed;
}

function blockedFromCollapsing(): boolean {
  if (dragging) {
    return true;
  }
  if (store.get(settingsVisibleAtom)) {
    return true;
  }
  if (isComposing()) {
    return true;
  }
  // The pointer came back over the chat before the timer fired
  if (document.body.matches(':hover')) {
    return true;
  }
  return false;
}

function setAnchorsForRect(
  x: number,
  y: number,
  w: number,
  h: number,
  mapW: number,
  mapH: number,
): void {
  const a1x = (x / mapW) * 100;
  const a1y = (y / mapH) * 100;
  const a2x = ((x + w) / mapW) * 100;
  const a2y = ((y + h) / mapH) * 100;
  Byond.winset('browseroutput', {
    anchor1: `${a1x.toFixed(2)},${a1y.toFixed(2)}`,
    anchor2: `${a2x.toFixed(2)},${a2y.toFixed(2)}`,
  });
}

/**
 * Shrinks the chat browser down to a strip along its own bottom edge.
 * The full rect is remembered as map ratios so it survives map resizes
 * that happen while the chat is collapsed.
 */
export function collapseChatToStrip(): void {
  if (!mode || collapsed || dragging) {
    return;
  }
  if (blockedFromCollapsing()) {
    return;
  }
  Byond.winget('browseroutput', 'parent').then((parent) => {
    if (parent !== 'mapwindow' || !mode || collapsed) {
      return;
    }
    Promise.all([
      Byond.winget('browseroutput', ['pos', 'size']),
      Byond.winget('mapwindow', ['size']),
    ]).then(([browser, map]) => {
      if (!mode || collapsed) {
        return;
      }
      const x = browser.pos.x;
      const y = browser.pos.y;
      const w = browser.size.x;
      const h = browser.size.y;
      const mapW = map.size.x;
      const mapH = map.size.y;
      if (!mapW || !mapH || w <= 0 || h <= CHAT_STRIP_HEIGHT) {
        return;
      }
      fullRect = { x: x / mapW, y: y / mapH, w: w / mapW, h: h / mapH };
      const stripY = y + h - CHAT_STRIP_HEIGHT;
      collapsed = true;
      // display:none blurs whatever was focused, remember it for the expand
      focusedBeforeCollapse =
        document.activeElement instanceof HTMLElement
          ? document.activeElement
          : null;
      document.body.classList.add('chat-hover-collapsed');
      Byond.winset('browseroutput', {
        pos: `${x},${stripY}`,
        size: `${w}x${CHAT_STRIP_HEIGHT}`,
      });
      setAnchorsForRect(x, stripY, w, CHAT_STRIP_HEIGHT, mapW, mapH);
    });
  });
}

/** Grows the chat browser back to the rect it had before collapsing. */
export function expandChatFromStrip(): void {
  if (!collapsed) {
    return;
  }
  Byond.winget('browseroutput', 'parent').then((parent) => {
    if (parent !== 'mapwindow') {
      // The chat already left the map for another layout; just clean up
      collapsed = false;
      document.body.classList.remove('chat-hover-collapsed');
      return;
    }
    Byond.winget('mapwindow', ['size']).then((map) => {
      collapsed = false;
      if (!fullRect) {
        document.body.classList.remove('chat-hover-collapsed');
        return;
      }
      const mapW = map.size.x;
      const mapH = map.size.y;
      if (!mapW || !mapH) {
        document.body.classList.remove('chat-hover-collapsed');
        return;
      }
      const x = Math.round(fullRect.x * mapW);
      const y = Math.round(fullRect.y * mapH);
      const w = Math.round(fullRect.w * mapW);
      const h = Math.round(fullRect.h * mapH);
      Byond.winset('browseroutput', {
        pos: `${x},${y}`,
        size: `${w}x${h}`,
      });
      setAnchorsForRect(x, y, w, h, mapW, mapH);
      // Let the control grow before the strip stops drawing, so the chat
      // does not flash by squeezed into a strip-sized viewport
      setTimeout(() => {
        if (!collapsed) {
          document.body.classList.remove('chat-hover-collapsed');
          // Give the keyboard back to whatever the collapse had blurred
          const restore = focusedBeforeCollapse;
          focusedBeforeCollapse = null;
          if (restore && document.contains(restore)) {
            restore.focus();
          }
        }
      }, 50);
    });
  });
}

export function cancelChatStripCollapse(): void {
  if (collapseTimer !== undefined) {
    clearTimeout(collapseTimer);
    collapseTimer = undefined;
  }
}

/**
 * Collapses the chat a moment after the pointer leaves it, unless the
 * settings are open, an input is focused, or a selection is in progress.
 */
export function scheduleChatStripCollapse(): void {
  if (!mode || collapsed) {
    return;
  }
  cancelChatStripCollapse();
  selectRetries = 0;
  const fire = () => {
    collapseTimer = undefined;
    if (!mode || collapsed) {
      return;
    }
    if (isSelecting() && selectRetries++ < SELECT_MAX_RETRIES) {
      // Don't snap the chat shut over an active text selection
      collapseTimer = setTimeout(fire, SELECT_RETRY_DELAY);
      return;
    }
    if (blockedFromCollapsing()) {
      return;
    }
    collapseChatToStrip();
  };
  collapseTimer = setTimeout(fire, COLLAPSE_DELAY);
}

/**
 * Turns the hover strip mode on or off. Turning it off restores the full
 * chat rect and clears the collapsed body class.
 */
export function setChatStripMode(active: boolean): void {
  mode = active;
  if (!active) {
    cancelChatStripCollapse();
    if (collapsed) {
      expandChatFromStrip();
    } else {
      document.body.classList.remove('chat-hover-collapsed');
    }
    return;
  }
  collapseChatToStrip();
}

/**
 * ResizeHandles reports drags so a collapse is never scheduled or fired
 * mid-drag; a drag that ends with the pointer outside the chat re-checks.
 */
export function setChatStripDragging(value: boolean): void {
  dragging = value;
  if (!value && mode && !collapsed) {
    scheduleChatStripCollapse();
  }
}

// Flash the strip when new messages land while the chat is collapsed
chatRenderer.events.on('batchProcessed', () => {
  if (!collapsed) {
    return;
  }
  const strip = document.querySelector('.ChatHoverStrip');
  if (strip instanceof HTMLElement) {
    strip.classList.remove('ChatHoverStrip--ping');
    // Restart the CSS animation
    void strip.offsetWidth;
    strip.classList.add('ChatHoverStrip--ping');
  }
});
