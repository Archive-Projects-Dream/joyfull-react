import { useAtomValue } from 'jotai';
import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { settingsAtom } from '../settings/atoms';
import { chatPagesRecordAtom } from './atom';
import {
  downgradeDetachedPanel,
  mergePanelIntoMain,
  updateDetachedPanel,
} from './chat-tab-drag';
import {
  DetachedChatPanelFrame,
  HEADER_DRAG_GUARD,
  startPointerDrag,
} from './ChatFloatingPanel';
import type { DetachedChatPanel } from './types';

const WINDOW_TITLE = 'Chat';
const WINDOW_EDGE_TOLERANCE = 12;

function isPointOverMainWindowScreen(x: number, y: number): boolean {
  const left = window.screenX;
  const top = window.screenY;
  return (
    x >= left - WINDOW_EDGE_TOLERANCE &&
    x <= left + window.outerWidth + WINDOW_EDGE_TOLERANCE &&
    y >= top - WINDOW_EDGE_TOLERANCE &&
    y <= top + window.outerHeight + WINDOW_EDGE_TOLERANCE
  );
}

function syncWindowDocumentStyles(doc: Document) {
  doc.documentElement.className = document.documentElement.className;
  doc.documentElement.style.setProperty(
    'font-family',
    document.documentElement.style.getPropertyValue('font-family'),
  );
  doc.body.style.setProperty(
    'font-family',
    document.body.style.getPropertyValue('font-family'),
  );
  doc.body.style.setProperty(
    'font-size',
    document.body.style.getPropertyValue('font-size'),
  );
}

function populateWindowDocument(doc: Document) {
  if (doc.documentElement.dataset.chatPanelReady !== 'true') {
    doc.documentElement.dataset.chatPanelReady = 'true';
    const base = doc.createElement('base');
    base.href = document.baseURI;
    doc.head.appendChild(base);
    const sheets = document.querySelectorAll<
      HTMLLinkElement | HTMLStyleElement
    >('link[rel="stylesheet"], style');
    for (const sheet of sheets) {
      doc.head.appendChild(sheet.cloneNode(true));
    }
    const reset = doc.createElement('style');
    reset.textContent =
      'html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden}';
    doc.head.appendChild(reset);
  }
  while (doc.body.firstChild) {
    doc.body.firstChild.remove();
  }
}

type Props = {
  panel: DetachedChatPanel;
};

/**
 * Detached chat in native window mode: a real browser window created with
 * window.open, hosting the very same chat panel frame through a React portal.
 * The document of the new window is fed the stylesheets of the main window so
 * the panel looks identical, and closing the window merges its tabs back.
 */
export function ChatWindowPanel(props: Props) {
  const { panel } = props;
  const settings = useAtomValue(settingsAtom);
  const pagesRecord = useAtomValue(chatPagesRecordAtom);
  const [childDoc, setChildDoc] = useState<Document | null>(null);
  const winRef = useRef<Window | null>(null);
  const closingByAppRef = useRef(false);

  useEffect(() => {
    let win: Window | null = null;
    try {
      win = window.open(
        '',
        `chat-${panel.id}`,
        `popup,width=${Math.round(panel.width)},height=${Math.round(
          panel.height,
        )},left=${Math.round(panel.x)},top=${Math.round(panel.y)}`,
      );
    } catch {
      win = null;
    }
    if (!win || win.closed || !win.document) {
      downgradeDetachedPanel(panel.id);
      return;
    }
    const child = win;
    winRef.current = child;
    const doc = child.document;
    doc.title = WINDOW_TITLE;
    populateWindowDocument(doc);
    syncWindowDocumentStyles(doc);
    setChildDoc(doc);

    const mergeBack = () => {
      if (closingByAppRef.current) {
        return;
      }
      mergePanelIntoMain(panel.id);
    };

    let pollTimer: ReturnType<typeof setInterval> | null = null;
    const onMainPageHide = () => {
      cleanup();
    };
    const cleanup = () => {
      if (pollTimer !== null) {
        clearInterval(pollTimer);
        pollTimer = null;
      }
      child.removeEventListener('pagehide', mergeBack);
      document.removeEventListener('pagehide', onMainPageHide);
    };

    child.addEventListener('pagehide', mergeBack);
    pollTimer = setInterval(() => {
      if (child.closed) {
        cleanup();
        mergeBack();
      }
    }, 500);
    document.addEventListener('pagehide', onMainPageHide);

    return () => {
      closingByAppRef.current = true;
      cleanup();
      try {
        if (!child.closed) {
          child.close();
        }
      } catch {
        // The window may already be gone
      }
      closingByAppRef.current = false;
    };
  }, [panel.id]);

  useEffect(() => {
    if (childDoc) {
      syncWindowDocumentStyles(childDoc);
    }
  }, [childDoc, settings.theme, settings.fontSize, settings.fontFamily]);

  const pageTitle = pagesRecord[panel.currentPageId]?.name ?? WINDOW_TITLE;
  useEffect(() => {
    if (childDoc) {
      childDoc.title = pageTitle;
    }
  }, [childDoc, pageTitle]);

  const beginHeaderDrag = (e: React.PointerEvent) => {
    if ((e.target as HTMLElement).closest(HEADER_DRAG_GUARD)) {
      return;
    }
    const win = winRef.current;
    if (!win || win.closed) {
      return;
    }
    const startScreenX = e.screenX;
    const startScreenY = e.screenY;
    const startWindowX = win.screenX;
    const startWindowY = win.screenY;
    let mergeArmed = false;
    let moved = false;

    const setMergeHint = (value: boolean) => {
      const strip = document.querySelector('.Panel__window .Panel__header');
      if (strip) {
        strip.classList.toggle('Panel__header--mergeHint', value);
      }
      const root = winRef.current?.document?.querySelector(
        '.ChatFloatingPanel',
      );
      if (root) {
        root.classList.toggle('ChatFloatingPanel--merging', value);
      }
    };

    startPointerDrag(
      e,
      (ev) => {
        moved =
          moved ||
          Math.abs(ev.screenX - startScreenX) > 3 ||
          Math.abs(ev.screenY - startScreenY) > 3;
        try {
          win.moveTo(
            startWindowX + (ev.screenX - startScreenX),
            startWindowY + (ev.screenY - startScreenY),
          );
        } catch {
          // Moving the window is best-effort
        }
        const armed = isPointOverMainWindowScreen(ev.screenX, ev.screenY);
        if (armed !== mergeArmed) {
          mergeArmed = armed;
          setMergeHint(armed);
        }
      },
      () => {
        setMergeHint(false);
        if (mergeArmed) {
          mergePanelIntoMain(panel.id);
          return;
        }
        if (moved) {
          try {
            updateDetachedPanel(panel.id, {
              x: win.screenX,
              y: win.screenY,
            });
          } catch {
            // The window may be gone
          }
        }
      },
    );
  };

  if (!childDoc) {
    return null;
  }

  return createPortal(
    <DetachedChatPanelFrame
      panel={panel}
      rootStyle={{
        left: 0,
        top: 0,
        width: '100%',
        height: '100%',
      }}
      onHeaderPointerDown={beginHeaderDrag}
    />,
    childDoc.body,
  );
}
