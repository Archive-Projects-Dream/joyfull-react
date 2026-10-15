import { createUuid } from 'tgui-core/uuid';
import { store } from '../events/store';
import { settingsAtom } from '../settings/atoms';
import {
  chatPagesAtom,
  chatPagesRecordAtom,
  currentPageIdAtom,
  detachedChatPanelsAtom,
  mainPage,
} from './atom';
import { chatRenderer } from './renderer';
import type { DetachedChatPanel, DetachedChatPanelMode, Page } from './types';

export type TabDragSource =
  | { kind: 'main' }
  | { kind: 'floating'; panelId: string };

type TabDragState = {
  pageId: string;
  source: TabDragSource;
  lastX: number;
  lastY: number;
  lastScreenX: number;
  lastScreenY: number;
  overMainDoc: boolean;
  resolved: boolean;
  releaseFns: (() => void)[];
};

const MIN_PANEL_WIDTH = 320;
const MIN_PANEL_HEIGHT = 240;
const PANEL_MARGIN = 24;

let drag: TabDragState | null = null;

export function getTabDrag(): TabDragState | null {
  return drag;
}

export function markTabDragResolved() {
  if (drag) {
    drag.resolved = true;
  }
}

function isPointInRect(x: number, y: number, rect: DOMRect) {
  return (
    x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom
  );
}

function getMainWindow(): HTMLElement | null {
  return document.querySelector('.Panel__window');
}

function isPointOverFloatingPanel(x: number, y: number): boolean {
  const nodes = document.querySelectorAll('.ChatFloatingPanel');
  for (let i = 0; i < nodes.length; i++) {
    const rect = nodes[i].getBoundingClientRect();
    if (isPointInRect(x, y, rect)) {
      return true;
    }
  }
  return false;
}

export function isPointOutsideMainWindow(x: number, y: number): boolean {
  const mainWindow = getMainWindow();
  if (!mainWindow) {
    return false;
  }
  return !isPointInRect(x, y, mainWindow.getBoundingClientRect());
}

function isPointOverMainWindowScreen(x: number, y: number): boolean {
  const left = window.screenX;
  const top = window.screenY;
  return (
    x >= left &&
    x <= left + window.outerWidth &&
    y >= top &&
    y <= top + window.outerHeight
  );
}

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}

function createPanelGeometry(x: number, y: number) {
  const mainWindow = getMainWindow();
  const viewportW = window.innerWidth;
  const viewportH = window.innerHeight;
  let width = Math.round(viewportW / 3);
  let height = Math.round(viewportH / 3);
  if (mainWindow) {
    const rect = mainWindow.getBoundingClientRect();
    width = Math.round(Math.min(rect.width, viewportW * 0.5));
    height = Math.round(Math.min(rect.height, viewportH * 0.6));
  }
  width = Math.max(width, MIN_PANEL_WIDTH);
  height = Math.max(height, MIN_PANEL_HEIGHT);
  const left = clamp(
    Math.round(x - PANEL_MARGIN),
    -(width - PANEL_MARGIN),
    viewportW - PANEL_MARGIN,
  );
  const top = clamp(Math.round(y - PANEL_MARGIN), 0, viewportH - PANEL_MARGIN);
  return { x: left, y: top, width, height };
}

function createWindowGeometry(screenX: number, screenY: number) {
  const width = Math.round(
    clamp(window.innerWidth * 0.4, MIN_PANEL_WIDTH, 720),
  );
  const height = Math.round(
    clamp(window.innerHeight * 0.5, MIN_PANEL_HEIGHT, 640),
  );
  const screen = window.screen as Screen & {
    availLeft?: number;
    availTop?: number;
  };
  const availLeft = screen.availLeft || 0;
  const availTop = screen.availTop || 0;
  const availWidth = screen.availWidth || screen.width;
  const availHeight = screen.availHeight || screen.height;
  const x = Math.round(
    clamp(screenX - width / 2, availLeft, availLeft + availWidth - width),
  );
  const y = Math.round(
    clamp(screenY - 32, availTop, availTop + availHeight - height),
  );
  return { x, y, width, height };
}

export function resolveDetachMode(): DetachedChatPanelMode {
  const settings = store.get(settingsAtom);
  const preference = settings.chatDetachMode ?? 'auto';
  if (preference === 'onmap' || preference === 'window') {
    return preference;
  }
  return document.body.classList.contains('onmap') ? 'onmap' : 'window';
}

function removePageFromSource(
  pageId: string,
  source: TabDragSource,
): DetachedChatPanel[] {
  const panels = store.get(detachedChatPanelsAtom);
  if (source.kind === 'main') {
    const mainPages = store
      .get(chatPagesAtom)
      .filter((id) => id !== pageId || id === mainPage.id);
    const currentPageId = store.get(currentPageIdAtom);
    if (currentPageId === pageId) {
      const nextId = mainPages[0] ?? mainPage.id;
      const pagesRecord = store.get(chatPagesRecordAtom);
      const nextPage = pagesRecord[nextId] ?? mainPage;
      store.set(currentPageIdAtom, nextId);
      store.set(chatPagesRecordAtom, {
        ...pagesRecord,
        [nextId]: { ...nextPage, unreadCount: 0 },
      });
      chatRenderer.changePage({ ...nextPage, unreadCount: 0 });
    }
    store.set(chatPagesAtom, mainPages);
    return panels;
  }
  return panels
    .map((panel) => {
      if (panel.id !== source.panelId) {
        return panel;
      }
      const pageIds = panel.pageIds.filter((id) => id !== pageId);
      if (pageIds.length === 0) {
        return null;
      }
      const nextPageId =
        panel.currentPageId === pageId ? pageIds[0] : panel.currentPageId;
      return { ...panel, pageIds, currentPageId: nextPageId };
    })
    .filter((panel) => panel !== null);
}

export function detachChatTab(
  pageId: string,
  source: TabDragSource,
  screenX: number,
  screenY: number,
  clientX: number,
  clientY: number,
) {
  const pagesRecord = store.get(chatPagesRecordAtom);
  const page = pagesRecord[pageId];
  if (!page || page.isMain || pageId === mainPage.id) {
    return;
  }
  const panels = removePageFromSource(pageId, source);
  const mode = resolveDetachMode();
  const panel: DetachedChatPanel = {
    id: createUuid(),
    mode,
    pageIds: [pageId],
    currentPageId: pageId,
    ...(mode === 'window'
      ? createWindowGeometry(screenX, screenY)
      : createPanelGeometry(clientX, clientY)),
  };
  store.set(detachedChatPanelsAtom, [...panels, panel]);
}

export function downgradeDetachedPanel(panelId: string) {
  const panels = store.get(detachedChatPanelsAtom);
  const panel = panels.find((entry) => entry.id === panelId);
  if (!panel || panel.mode === 'onmap') {
    return;
  }
  const viewportW = window.innerWidth;
  const viewportH = window.innerHeight;
  const width = clamp(panel.width, MIN_PANEL_WIDTH, viewportW - 16);
  const height = clamp(panel.height, MIN_PANEL_HEIGHT, viewportH - 16);
  const x = clamp(panel.x, 8, Math.max(8, viewportW - width - 8));
  const y = clamp(panel.y, 8, Math.max(8, viewportH - height - 8));
  store.set(
    detachedChatPanelsAtom,
    panels.map((entry) =>
      entry.id === panelId ? { ...entry, mode: 'onmap', x, y, width, height } : entry,
    ),
  );
}

function resolveTabDrag(
  rawClientX: number,
  rawClientY: number,
  screenX: number,
  screenY: number,
) {
  if (!drag) {
    return;
  }
  const { pageId, source } = drag;
  const clientX = rawClientX || drag.lastX;
  const clientY = rawClientY || drag.lastY;

  if (source.kind === 'main') {
    const droppedOutsideViewport = rawClientX === 0 && rawClientY === 0;
    const outsideByScreen = !isPointOverMainWindowScreen(screenX, screenY);
    const outsideByContainer =
      drag.overMainDoc && isPointOutsideMainWindow(clientX, clientY);
    if (droppedOutsideViewport || outsideByScreen || outsideByContainer) {
      detachChatTab(pageId, source, screenX, screenY, clientX, clientY);
    }
    return;
  }

  if (
    drag.overMainDoc &&
    !isPointOutsideMainWindow(clientX, clientY) &&
    !isPointOverFloatingPanel(clientX, clientY)
  ) {
    dropTabIntoMain(pageId, store.get(chatPagesAtom).length);
  }
}

function attachDragListeners(doc: Document) {
  if (!drag) {
    return;
  }
  const isMainDoc = doc === document;
  const onDragOver = (e: DragEvent) => {
    if (!drag) {
      return;
    }
    e.preventDefault();
    if (e.dataTransfer) {
      e.dataTransfer.dropEffect = 'move';
    }
    drag.lastX = e.clientX;
    drag.lastY = e.clientY;
    drag.lastScreenX = e.screenX;
    drag.lastScreenY = e.screenY;
    drag.overMainDoc = isMainDoc;
  };
  const onDragEnd = (e: DragEvent) => {
    if (!drag) {
      return;
    }
    if (drag.resolved) {
      cleanup();
      return;
    }
    const screenX = e.screenX || drag.lastScreenX;
    const screenY = e.screenY || drag.lastScreenY;
    resolveTabDrag(e.clientX, e.clientY, screenX, screenY);
    cleanup();
  };
  doc.addEventListener('dragover', onDragOver);
  doc.addEventListener('dragend', onDragEnd, true);
  drag.releaseFns.push(() => {
    doc.removeEventListener('dragover', onDragOver);
    doc.removeEventListener('dragend', onDragEnd, true);
  });
}

function cleanup() {
  if (drag) {
    for (const release of drag.releaseFns) {
      release();
    }
  }
  drag = null;
}

export function beginTabDrag(
  e: React.DragEvent,
  pageId: string,
  source: TabDragSource,
) {
  const sourceDoc =
    (e.target as HTMLElement | null)?.ownerDocument ?? document;
  drag = {
    pageId,
    source,
    lastX: e.clientX,
    lastY: e.clientY,
    lastScreenX: e.screenX,
    lastScreenY: e.screenY,
    overMainDoc: sourceDoc === document,
    resolved: false,
    releaseFns: [],
  };
  e.dataTransfer.effectAllowed = 'move';
  e.dataTransfer.setData('text/plain', pageId);
  attachDragListeners(sourceDoc);
  if (sourceDoc !== document) {
    attachDragListeners(document);
  }
}

export function endTabDrag() {
  cleanup();
}

function insertIntoList(list: string[], pageId: string, insertIndex: number) {
  const from = list.indexOf(pageId);
  const without = list.filter((id) => id !== pageId);
  let index = insertIndex;
  if (from !== -1 && insertIndex > from) {
    index -= 1;
  }
  index = Math.min(Math.max(index, 0), without.length);
  without.splice(index, 0, pageId);
  return without;
}

export function dropTabIntoMain(pageId: string, insertIndex: number) {
  const dragState = getTabDrag();
  if (!dragState || dragState.pageId !== pageId) {
    return;
  }
  const source = dragState.source;
  markTabDragResolved();

  const pagesRecord = store.get(chatPagesRecordAtom);
  const page = pagesRecord[pageId];
  if (!page) {
    return;
  }

  if (source.kind === 'main') {
    const mainPages = store.get(chatPagesAtom);
    store.set(
      chatPagesAtom,
      insertIntoList(mainPages, pageId, Math.max(1, insertIndex)),
    );
    return;
  }

  const mainPages = store.get(chatPagesAtom);
  const pages = insertIntoList(mainPages, pageId, Math.max(1, insertIndex));
  const panels = removePageFromSource(pageId, source);
  const draft: Page = { ...page, unreadCount: 0 };

  store.set(chatPagesAtom, pages);
  store.set(chatPagesRecordAtom, {
    ...pagesRecord,
    [pageId]: draft,
  });
  store.set(detachedChatPanelsAtom, panels);
  store.set(currentPageIdAtom, pageId);
  chatRenderer.changePage(draft);
}

export function dropTabIntoPanel(
  panelId: string,
  pageId: string,
  insertIndex: number,
) {
  const dragState = getTabDrag();
  if (!dragState || dragState.pageId !== pageId) {
    return;
  }
  const source = dragState.source;
  if (source.kind === 'floating' && source.panelId === panelId) {
    markTabDragResolved();
    const panels = store.get(detachedChatPanelsAtom);
    store.set(
      detachedChatPanelsAtom,
      panels.map((panel) =>
        panel.id === panelId
          ? {
              ...panel,
              pageIds: insertIntoList(panel.pageIds, pageId, insertIndex),
            }
          : panel,
      ),
    );
    return;
  }
  markTabDragResolved();

  const pagesRecord = store.get(chatPagesRecordAtom);
  const page = pagesRecord[pageId];
  if (!page) {
    return;
  }

  const panels = removePageFromSource(pageId, source);
  const nextPanels = panels
    .map((panel) => {
      if (panel.id !== panelId) {
        return panel;
      }
      const pageIds = insertIntoList(panel.pageIds, pageId, insertIndex);
      return { ...panel, pageIds, currentPageId: pageId };
    })
    .filter((panel) => panel !== null);

  store.set(chatPagesRecordAtom, {
    ...pagesRecord,
    [pageId]: { ...page, unreadCount: 0 },
  });
  store.set(detachedChatPanelsAtom, nextPanels);
}

export function mergePanelIntoMain(panelId: string) {
  const panels = store.get(detachedChatPanelsAtom);
  const panel = panels.find((entry) => entry.id === panelId);
  if (!panel) {
    return;
  }
  const pagesRecord = store.get(chatPagesRecordAtom);
  const mainPages = store.get(chatPagesAtom);
  const mergedPages = [
    ...mainPages.filter((id) => !panel.pageIds.includes(id)),
    ...panel.pageIds.filter((id) => pagesRecord[id]),
  ];
  const currentPageId = pagesRecord[panel.currentPageId]
    ? panel.currentPageId
    : mergedPages[mergedPages.length - 1];

  store.set(
    detachedChatPanelsAtom,
    panels.filter((p) => p.id !== panelId),
  );
  store.set(chatPagesAtom, mergedPages);
  const page = pagesRecord[currentPageId];
  if (page) {
    const draft: Page = { ...page, unreadCount: 0 };
    store.set(currentPageIdAtom, currentPageId);
    store.set(chatPagesRecordAtom, {
      ...pagesRecord,
      [currentPageId]: draft,
    });
    chatRenderer.changePage(draft);
  }
}

export function updateDetachedPanel(
  panelId: string,
  patch: Partial<DetachedChatPanel>,
) {
  const panels = store.get(detachedChatPanelsAtom);
  store.set(
    detachedChatPanelsAtom,
    panels.map((panel) =>
      panel.id === panelId ? { ...panel, ...patch } : panel,
    ),
  );
}
