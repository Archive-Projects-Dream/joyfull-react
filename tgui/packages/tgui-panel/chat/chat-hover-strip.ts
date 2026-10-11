/**
 * Click-through peek strip for the on-map frameless chat.
 *
 * A browser control swallows every click inside its rect, so a chat that
 * floats over the map blocks input on the turfs and screen objects behind
 * it. While this mode is on, the collapsed chat shrinks the browseroutput
 * control down to a small strip that keeps showing the live tail of the
 * log: everything beyond the strip is bare map again and clicks fall
 * straight through. Hovering the strip grows the control back to the full
 * chat rect.
 *
 * The strip hugs the edge the chat is anchored to - the map's bottom edge
 * for bottom corners, its top edge for top corners - so the newest
 * messages always sit right at the corner and expanding the chat never
 * moves them. Top-corner chats render the log reversed (see
 * chatRenderer.setReversed), which is what keeps the collapsed and the
 * expanded display identical for them.
 *
 * The collapsed strip keeps the command bar mounted under the log, and
 * the marker bar with it, so the bottom of the window looks exactly the
 * same in both states and hovering the chat open moves nothing.
 *
 * Panel.tsx drives this module: it turns the mode on and off as the
 * relevant settings change, and routes the body hover events through
 * here. ResizeHandles reports drags so a resize or a move never races the
 * collapse.
 */
import { storage } from 'common/storage';
import { store } from '../events/store';
import { settingsVisibleAtom } from '../settings/atoms';
import { saveChatRatioRect } from './chat-ratio';
import { chatRenderer } from './renderer';

const COLLAPSE_DELAY = 300;
const SELECT_RETRY_DELAY = 500;
const SELECT_MAX_RETRIES = 8;
/** Hovering the strip chrome waits this long before expanding, so the
 * marker and the peek grip can be grabbed without the chat snapping
 * open under the pointer. */
const EXPAND_DEFER = 140;

const PEEK_HEIGHT_KEY = 'chat-peek-height';
/** Height of the collapsed strip, in control pixels: marker + command
 * bar + a handful of log lines. The user resizes it with the grip on the
 * marker; until then this default is used. */
const DEFAULT_PEEK_HEIGHT = 140;
const MIN_PEEK_HEIGHT = 100;

type RectRatio = {
  x: number;
  y: number;
  w: number;
  h: number;
};

type RectPx = {
  x: number;
  y: number;
  w: number;
  h: number;
};

let mode = false;
let collapsed = false;
let stripAtTop = false;
let fullRect: RectRatio | null = null;
let collapseTimer: ReturnType<typeof setTimeout> | undefined;
let selectRetries = 0;
let dragging = false;
let pendingExpand = false;
let settling = false;
let focusedBeforeCollapse: HTMLElement | null = null;
let paneObserver: ResizeObserver | null = null;
let paneObserverNode: HTMLElement | null = null;

// Deferred expand bookkeeping: while the pointer sits on the strip's own
// chrome (marker bar, peek grip) the chat must stay collapsed so those
// stay draggable
let chromeHovered = false;
let expandTimer: ReturnType<typeof setTimeout> | undefined;

// TGUI windows that opened over the chat's full rect; the chat yields to
// them by staying collapsed until they are gone (see Panel's window
// event handlers)
const yieldingWindows = new Set<string>();
let yieldTimers: ReturnType<typeof setTimeout>[] = [];
let displaced = false;

let peekHeight = DEFAULT_PEEK_HEIGHT;

export function isChatStripCollapsed(): boolean {
  return collapsed;
}

/** The persisted height of the collapsed peek strip, in control pixels. */
export function getChatStripPeekHeight(): number {
  return peekHeight;
}

function loadPeekHeight(): void {
  // storage.get is async; the value is applied as soon as it arrives.
  // Collapses only happen well after boot, so this wins the race for
  // any practical session
  storage
    .get(PEEK_HEIGHT_KEY)
    .then((value: unknown) => {
      if (typeof value === 'number' && value >= MIN_PEEK_HEIGHT) {
        peekHeight = value;
      }
    })
    .catch(() => undefined);
}

loadPeekHeight();

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

function blockedFromCollapsing(bypassHover = false): boolean {
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
  if (!bypassHover && document.body.matches(':hover')) {
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
 * Keeps the newest message pinned to the strip's anchored edge whenever
 * the chat pane changes size while collapsed. The winset that shrinks
 * the control only resizes the viewport once BYOND has applied it, so the
 * scroll position has to be re-applied after the fact; this also covers
 * map resizes that happen while the chat is collapsed.
 */
function observePaneForRestick(): void {
  const pane = document.getElementById('chat-pane');
  if (!pane || typeof ResizeObserver === 'undefined') {
    return;
  }
  // The pane node does not survive every remount; re-attach when it changes
  if (paneObserver && paneObserverNode === pane) {
    return;
  }
  paneObserver?.disconnect();
  paneObserverNode = pane;
  paneObserver = new ResizeObserver(() => {
    if (collapsed) {
      chatRenderer.scrollToBottom();
    }
  });
  paneObserver.observe(pane);
}

/**
 * Shrinks the chat browser down to a peek strip along its anchored edge -
 * the bottom edge for bottom corners, the top edge for top corners, where
 * the reversed log keeps the newest message right under the corner. The
 * full rect is remembered as map ratios so it survives map resizes that
 * happen while the chat is collapsed.
 */
export function collapseChatToStrip(bypassHover = false): void {
  if (!mode || collapsed || dragging) {
    return;
  }
  if (blockedFromCollapsing(bypassHover)) {
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
      if (!mapW || !mapH || w <= 0 || h <= peekHeight) {
        return;
      }
      fullRect = { x: x / mapW, y: y / mapH, w: w / mapW, h: h / mapH };
      const stripH = Math.min(peekHeight, h);
      const stripY = stripAtTop ? y : y + h - stripH;
      collapsed = true;
      // The command bar is display:none in the collapsed state, so
      // whatever was focused loses focus; remember it for the expand
      focusedBeforeCollapse =
        document.activeElement instanceof HTMLElement
          ? document.activeElement
          : null;
      document.body.classList.add('chat-hover-collapsed');
      Byond.winset('browseroutput', {
        pos: `${x},${stripY}`,
        size: `${w}x${stripH}`,
      });
      setAnchorsForRect(x, stripY, w, stripH, mapW, mapH);
      observePaneForRestick();
      // Re-stick to the newest message now; the observer above re-applies
      // it once the shrunk viewport has actually settled
      chatRenderer.scrollToBottom();
    });
  });
}

/** Grows the chat browser back to the rect it had before collapsing. */
export function expandChatFromStrip(): void {
  if (!collapsed) {
    return;
  }
  if (dragging || settling) {
    // A move-drag (or its bookkeeping) is in progress; expanding now
    // would race the drag's own winsets or restore a stale rect, so it
    // waits for the drag to settle instead
    pendingExpand = true;
    return;
  }
  Byond.winget('browseroutput', 'parent').then((parent) => {
    if (parent !== 'mapwindow') {
      // The chat already left the map for another layout; just clean up
      collapsed = false;
      pendingExpand = false;
      document.body.classList.remove('chat-hover-collapsed');
      return;
    }
    Byond.winget('mapwindow', ['size']).then((map) => {
      collapsed = false;
      pendingExpand = false;
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
      // Let the control grow before the strip chrome stops drawing, so the
      // chat does not flash by squeezed into a strip-sized viewport
      setTimeout(() => {
        if (!collapsed) {
          document.body.classList.remove('chat-hover-collapsed');
          // The expanded chat shows its window chrome again, unless the
          // pointer already left in the meantime
          if (
            mode &&
            (document.body.matches(':hover') ||
              store.get(settingsVisibleAtom))
          ) {
            document.body.classList.add('frameless-visible');
          }
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
 * Expands the chat out of the strip on hover. The actual expansion is
 * deferred for a moment so the strip's own chrome (the marker bar, the
 * peek grip) can be grabbed without the chat snapping open under the
 * pointer - while that chrome is hovered the request is simply parked.
 */
export function requestChatStripExpand(): void {
  if (!mode) {
    return;
  }
  cancelChatStripCollapse();
  if (displaced) {
    // A TGUI window is squatting on the chat's rect; the strip stays put
    // until it moves away or closes
    scheduleYieldCheck();
    return;
  }
  if (!collapsed) {
    document.body.classList.add('frameless-visible');
    return;
  }
  if (expandTimer !== undefined) {
    clearTimeout(expandTimer);
  }
  expandTimer = setTimeout(() => {
    expandTimer = undefined;
    if (!mode || !collapsed || chromeHovered || displaced) {
      return;
    }
    expandChatFromStrip();
  }, EXPAND_DEFER);
}

/**
 * Panel calls this while the pointer is over the strip's own chrome (the
 * marker bar and everything on it); those must stay reachable instead of
 * being expanded away.
 */
export function setStripChromeHovered(value: boolean): void {
  chromeHovered = value;
  if (value && expandTimer !== undefined) {
    clearTimeout(expandTimer);
    expandTimer = undefined;
    return;
  }
  // Leaving the chrome for the log itself: no body mouseenter will fire
  // (the pointer never left the control), so pick the expand back up
  if (!value && mode && collapsed && document.body.matches(':hover')) {
    requestChatStripExpand();
  }
}

/**
 * Turns the hover strip mode on or off. Turning it off restores the full
 * chat rect and clears the collapsed body class.
 */
export function setChatStripMode(active: boolean): void {
  mode = active;
  if (!active) {
    cancelChatStripCollapse();
    if (expandTimer !== undefined) {
      clearTimeout(expandTimer);
      expandTimer = undefined;
    }
    clearYieldTracking();
    if (collapsed) {
      pendingExpand = false;
      expandChatFromStrip();
    } else {
      document.body.classList.remove('chat-hover-collapsed');
    }
    paneObserver?.disconnect();
    paneObserver = null;
    paneObserverNode = null;
    return;
  }
  collapseChatToStrip();
}

/**
 * Tells the strip which edge of the chat rect to hug: the top edge for
 * chats anchored into a top corner (the log is reversed there, newest
 * message right under the corner), the bottom edge for everyone else.
 */
export function setChatStripEdge(atTop: boolean): void {
  stripAtTop = atTop;
}

/**
 * Called by ResizeHandles when a drag ends on the collapsed strip. The
 * control is only strip-sized while collapsed, so the remembered full
 * rect is rebased to wherever the strip was dropped (its anchored edge
 * stays put), persisted, and reported to DM so the HUD displacement
 * keeps pointing at the real chat rect instead of flickering with the
 * strip on every hover.
 */
export function settleChatStripAfterDrag(): void {
  if (!collapsed || !fullRect) {
    return;
  }
  settling = true;
  Promise.all([
    Byond.winget('browseroutput', ['pos', 'size']),
    Byond.winget('mapwindow', ['size']),
  ]).then(([browser, map]) => {
    settling = false;
    if (!collapsed || !fullRect) {
      return;
    }
    const mapW = map.size.x;
    const mapH = map.size.y;
    if (!mapW || !mapH) {
      return;
    }
    const fullW = fullRect.w;
    const fullH = fullRect.h;
    // The move kept the width; the anchored edge of the strip is where the
    // full rect attaches: its top for a top-edge strip, its bottom
    // otherwise
    const stripBottom = browser.pos.y + browser.size.y;
    const pxY = stripAtTop
      ? browser.pos.y
      : stripBottom - Math.round(fullH * mapH);
    let x = browser.pos.x / mapW;
    let y = pxY / mapH;
    // Keep the expanded rect on the map even if the strip was dropped at
    // the very edge
    x = Math.min(Math.max(x, 0), Math.max(1 - fullW, 0));
    y = Math.min(Math.max(y, 0), Math.max(1 - fullH, 0));
    fullRect = { x, y, w: fullW, h: fullH };
    saveChatRatioRect(fullRect);
    Byond.sendMessage('panel/bounds', {
      x: Math.round(fullRect.x * mapW),
      y: Math.round(fullRect.y * mapH),
      w: Math.round(fullRect.w * mapW),
      h: Math.round(fullRect.h * mapH),
    });
    // A hover-expand that arrived mid-drag was postponed until now
    if (pendingExpand) {
      pendingExpand = false;
      if (document.body.matches(':hover')) {
        expandChatFromStrip();
      }
    }
  });
}

/**
 * ResizeHandles reports drags so a collapse is never scheduled or fired
 * mid-drag; a drag that ends with the pointer still over the chat either
 * expands it (a hover-expand was postponed by the drag) or re-checks the
 * collapse.
 */
export function setChatStripDragging(value: boolean): void {
  dragging = value;
  if (value || !mode) {
    return;
  }
  if (collapsed) {
    if (pendingExpand) {
      pendingExpand = false;
      if (document.body.matches(':hover')) {
        expandChatFromStrip();
      }
    }
    return;
  }
  scheduleChatStripCollapse();
}

/**
 * Drags the peek strip's height with the grip on its marker bar. Only
 * the visible area changes - the chat's full rect is left exactly as it
 * was, so expanding afterwards still restores the same window.
 */
export function startChatStripPeekResize(e: React.PointerEvent): void {
  if (!collapsed) {
    return;
  }
  e.preventDefault();
  e.stopPropagation();
  // Hover-strip collapse or expand must not fire mid-drag
  setChatStripDragging(true);
  const target = e.currentTarget as HTMLElement;
  const { pointerId } = e;
  const startMouseY = e.screenY * (window.devicePixelRatio ?? 1);
  let startPosX = 0;
  let startPosY = 0;
  let startSizeH = 0;
  let startWidth = 0;
  let mapW = 0;
  let mapH = 0;
  let maxHeight = Infinity;
  let ready = false;
  let latest: PointerEvent | null = null;
  let finished = false;
  let appliedH = peekHeight;

  const applyHeight = (newH: number) => {
    if (!ready) {
      return;
    }
    const h = Math.max(MIN_PEEK_HEIGHT, Math.min(newH, maxHeight));
    appliedH = h;
    const stripBottom = startPosY + startSizeH;
    const y = stripAtTop ? startPosY : stripBottom - h;
    Byond.winset('browseroutput', {
      pos: `${startPosX},${y}`,
      size: `${startWidth}x${h}`,
    });
    if (mapW && mapH) {
      setAnchorsForRect(startPosX, y, startWidth, h, mapW, mapH);
    }
  };

  const handleMove = (ev: PointerEvent) => {
    if (ev.pointerId !== pointerId) {
      return;
    }
    ev.preventDefault();
    latest = ev;
    const dy = ev.screenY * (window.devicePixelRatio ?? 1) - startMouseY;
    // Dragging away from the anchored edge grows the peek
    applyHeight(startSizeH + (stripAtTop ? dy : -dy));
  };

  const finish = (ev: PointerEvent) => {
    if (finished || ev.pointerId !== pointerId) {
      return;
    }
    finished = true;
    if (latest) {
      const dy =
        latest.screenY * (window.devicePixelRatio ?? 1) - startMouseY;
      applyHeight(startSizeH + (stripAtTop ? dy : -dy));
    }
    target.removeEventListener('pointermove', handleMove);
    target.removeEventListener('pointerup', finish);
    target.removeEventListener('pointercancel', finish);
    target.removeEventListener('lostpointercapture', finish);
    try {
      target.releasePointerCapture(pointerId);
    } catch {
      // Already released
    }
    peekHeight = appliedH;
    storage.set(PEEK_HEIGHT_KEY, peekHeight);
    setChatStripDragging(false);
  };

  try {
    target.setPointerCapture(pointerId);
  } catch {
    // Capture is best-effort; the listeners below still work without it
  }
  target.addEventListener('pointermove', handleMove);
  target.addEventListener('pointerup', finish);
  target.addEventListener('pointercancel', finish);
  // Fires if the browser takes capture away, e.g. the window loses focus
  target.addEventListener('lostpointercapture', finish);

  Promise.all([
    Byond.winget('browseroutput', ['pos', 'size']),
    Byond.winget('mapwindow', ['size']),
  ]).then(([browser, map]) => {
    if (finished) {
      return;
    }
    startPosX = browser.pos.x;
    startPosY = browser.pos.y;
    startSizeH = browser.size.y;
    startWidth = browser.size.x;
    mapW = map.size.x;
    mapH = map.size.y;
    ready = true;
    // The peek never grows past the chat's own full rect
    maxHeight = fullRect ? Math.round(fullRect.h * mapH) : Infinity;
    if (latest) {
      const dy = latest.screenY * (window.devicePixelRatio ?? 1) - startMouseY;
      applyHeight(startSizeH + (stripAtTop ? dy : -dy));
    }
  });
}

// --- TGUI window yielding -------------------------------------------------

function rectsOverlap(a: RectPx, b: RectPx): boolean {
  return (
    a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
  );
}

/**
 * The chat's full rect in the same coordinate space another BYOND window
 * reports its pos in: the main window's own offset plus the map pane's
 * offset plus the browser control's offset inside it. Null when the chat
 * is not on the map.
 */
async function chatRectForYield(): Promise<RectPx | null> {
  const parent = await Byond.winget('browseroutput', 'parent');
  if (parent !== 'mapwindow') {
    return null;
  }
  const [main, map, browser, mapSize] = await Promise.all([
    Byond.winget('mainwindow', ['pos']).catch(() => null),
    Byond.winget('mapwindow', ['pos']),
    Byond.winget('browseroutput', ['pos', 'size']),
    Byond.winget('mapwindow', ['size']),
  ]);
  const mapW = mapSize.size.x;
  const mapH = mapSize.size.y;
  if (!mapW || !mapH) {
    return null;
  }
  // The main window's origin is (0,0) when skin coordinates are already
  // relative to it, and the real screen offset otherwise - adding it is
  // correct either way
  const originX = main ? main.pos.x : 0;
  const originY = main ? main.pos.y : 0;
  if (collapsed && fullRect) {
    // The control is strip-sized right now; what the window would cover
    // is the chat's full rect
    return {
      x: originX + map.pos.x + Math.round(fullRect.x * mapW),
      y: originY + map.pos.y + Math.round(fullRect.y * mapH),
      w: Math.round(fullRect.w * mapW),
      h: Math.round(fullRect.h * mapH),
    };
  }
  return {
    x: originX + map.pos.x + browser.pos.x,
    y: originY + map.pos.y + browser.pos.y,
    w: browser.size.x,
    h: browser.size.y,
  };
}

async function windowRect(id: string): Promise<RectPx | null> {
  try {
    const win = await Byond.winget(id, ['pos', 'size']);
    if (!win || !win.pos || !win.size) {
      return null;
    }
    return {
      x: win.pos.x,
      y: win.pos.y,
      w: win.size.x,
      h: win.size.y,
    };
  } catch {
    return null;
  }
}

async function runYieldCheck(): Promise<void> {
  if (!mode) {
    return;
  }
  const chatRect = await chatRectForYield();
  if (!chatRect) {
    displaced = false;
    return;
  }
  let anyOverlap = false;
  for (const id of yieldingWindows) {
    const rect = await windowRect(id);
    if (rect && rectsOverlap(chatRect, rect)) {
      anyOverlap = true;
      break;
    }
  }
  if (anyOverlap) {
    displaced = true;
    // Step aside for the window, even from under a pointer that is
    // merely hovering the chat
    collapseChatToStrip(true);
    return;
  }
  if (displaced) {
    displaced = false;
    // The coast is clear; a pointer parked on the chat can have it back
    if (document.body.matches(':hover') && !chromeHovered) {
      requestChatStripExpand();
    }
  }
}

function scheduleYieldCheck(): void {
  for (const timer of yieldTimers) {
    clearTimeout(timer);
  }
  yieldTimers = [];
  // The freshly opened window places itself from its own script a few
  // frames after the browse lands, so the first check races it - check
  // again once it has had time to settle
  yieldTimers.push(setTimeout(() => void runYieldCheck(), 250));
  yieldTimers.push(setTimeout(() => void runYieldCheck(), 900));
}

function clearYieldTracking(): void {
  for (const timer of yieldTimers) {
    clearTimeout(timer);
  }
  yieldTimers = [];
  yieldingWindows.clear();
  displaced = false;
}

/** A TGUI window was just opened; yield the chat's rect to it if they overlap. */
export function onPanelWindowOpened(id: string): void {
  if (!mode || !id) {
    return;
  }
  yieldingWindows.add(id);
  scheduleYieldCheck();
}

/** A TGUI window closed (or suspended); the chat can take its rect back. */
export function onPanelWindowClosed(id: string): void {
  if (!id) {
    return;
  }
  yieldingWindows.delete(id);
  if (yieldingWindows.size === 0) {
    scheduleYieldCheck();
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
