import { createUuid } from 'tgui-core/uuid';
import { store } from '../events/store';
import {
  chatPagesAtom,
  chatPagesRecordAtom,
  currentPageIdAtom,
  detachedChatPanelsAtom,
  mainPage,
} from './atom';
import { chatRenderer } from './renderer';
import type { DetachedChatPanel, Page } from './types';

export type TabDragSource =
  | { kind: 'main' }
  | { kind: 'floating'; panelId: string };

type TabDragState = {
  pageId: string;
  source: TabDragSource;
  lastX: number;
  lastY: number;
  resolved: boolean;
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

function onDocDragOver(e: DragEvent) {
  if (!drag) {
    return;
  }
  drag.lastX = e.clientX;
  drag.lastY = e.clientY;
}

function onDocDragEnd() {
  if (drag && !drag.resolved) {
    resolveTabDragAtPoint(drag.lastX, drag.lastY);
  }
  cleanup();
}

function cleanup() {
  drag = null;
  document.removeEventListener('dragover', onDocDragOver);
  document.removeEventListener('dragend', onDocDragEnd, true);
}

export function beginTabDrag(
  e: React.DragEvent,
  pageId: string,
  source: TabDragSource,
) {
  drag = {
    pageId,
    source,
    lastX: e.clientX,
    lastY: e.clientY,
    resolved: false,
  };
  e.dataTransfer.effectAllowed = 'move';
  e.dataTransfer.setData('text/plain', pageId);
  document.addEventListener('dragover', onDocDragOver);
  document.addEventListener('dragend', onDocDragEnd, true);
}

export function endTabDrag() {
  cleanup();
}

function getMainWindow(): HTMLElement | null {
  return document.querySelector('.Panel__window');
}

function isPointInRect(x: number, y: number, rect: DOMRect) {
  return x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom;
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
  const rect = mainWindow.getBoundingClientRect();
  return !isPointInRect(x, y, rect);
}

function resolveTabDragAtPoint(x: number, y: number) {
  if (!drag) {
    return;
  }
  const { pageId, source } = drag;
  if (
    isPointOutsideMainWindow(x, y) &&
    (source.kind === 'main' || !isPointOverFloatingPanel(x, y))
  ) {
    detachChatTab(pageId, source, x, y);
  }
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
  x: number,
  y: number,
) {
  const pagesRecord = store.get(chatPagesRecordAtom);
  const page = pagesRecord[pageId];
  if (!page || page.isMain || pageId === mainPage.id) {
    return;
  }
  const panels = removePageFromSource(pageId, source);
  const geometry = createPanelGeometry(x, y);
  const panel: DetachedChatPanel = {
    id: createUuid(),
    pageIds: [pageId],
    currentPageId: pageId,
    ...geometry,
  };
  store.set(detachedChatPanelsAtom, [...panels, panel]);
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
