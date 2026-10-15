/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { useAtom, useAtomValue } from 'jotai';
import { useCallback, useEffect, useMemo, useRef } from 'react';
import { createPortal } from 'react-dom';
import { Pane } from 'tgui/layouts';
import { Button, Section, Stack } from 'tgui-core/components';
import { store } from '../events/store';
import { settingsAtom } from '../settings/atoms';
import { chatPagesRecordAtom, detachedChatPanelsAtom } from './atom';
import { ChatPanel } from './ChatPanel';
import { ChatTabs } from './ChatTabs';
import {
  dropTabIntoPanel,
  mergePanelIntoMain,
  updateDetachedPanel,
} from './chat-tab-drag';
import { MAX_PERSISTED_MESSAGES } from './constants';
import { createPage, serializeMessage } from './model';
import {
  ChatRenderer,
  chatRenderer,
  registerChatRenderer,
  unregisterChatRenderer,
} from './renderer';
import type { DetachedChatPanel, Page } from './types';

const MIN_WIDTH = 320;
const MIN_HEIGHT = 240;

export const HEADER_DRAG_GUARD =
  'button, a, input, [role="button"], .Button, .Tab, .Dropdown, .Tabs, .Chat__scrollButton';

const RESIZE_DIRS = [
  'left',
  'right',
  'top',
  'bottom',
  'top-left',
  'top-right',
  'bottom-left',
  'bottom-right',
] as const;

type ResizeDir = (typeof RESIZE_DIRS)[number];

const RESIZE_CURSORS: Record<ResizeDir, string> = {
  left: 'ew-resize',
  right: 'ew-resize',
  top: 'ns-resize',
  bottom: 'ns-resize',
  'top-left': 'nwse-resize',
  'top-right': 'nesw-resize',
  'bottom-left': 'nesw-resize',
  'bottom-right': 'nwse-resize',
};

type Point = { x: number; y: number; width: number; height: number };

function rectsIntersect(a: DOMRect, b: DOMRect) {
  return (
    a.left <= b.right &&
    a.right >= b.left &&
    a.top <= b.bottom &&
    a.bottom >= b.top
  );
}

function clampPanelPosition(point: Point): Point {
  const margin = 80;
  return {
    ...point,
    x: Math.min(
      Math.max(point.x, -(point.width - margin)),
      window.innerWidth - margin,
    ),
    y: Math.min(Math.max(point.y, 0), window.innerHeight - 40),
  };
}

export function startPointerDrag(
  e: React.PointerEvent,
  onMove: (ev: PointerEvent, dx: number, dy: number) => void,
  onEnd: () => void,
) {
  e.preventDefault();
  const target = e.currentTarget as HTMLElement;
  const { pointerId } = e;
  const startX = e.clientX;
  const startY = e.clientY;
  let finished = false;

  try {
    target.setPointerCapture(pointerId);
  } catch {
    // Capture is best-effort; the listeners below still work without it
  }

  const handleMove = (ev: PointerEvent) => {
    if (ev.pointerId !== pointerId) {
      return;
    }
    ev.preventDefault();
    onMove(ev, ev.clientX - startX, ev.clientY - startY);
  };

  const finish = (ev: PointerEvent) => {
    if (finished || ev.pointerId !== pointerId) {
      return;
    }
    finished = true;
    target.removeEventListener('pointermove', handleMove);
    target.removeEventListener('pointerup', finish);
    target.removeEventListener('pointercancel', finish);
    target.removeEventListener('lostpointercapture', finish);
    try {
      target.releasePointerCapture(pointerId);
    } catch {
      // Already released
    }
    onEnd();
  };

  target.addEventListener('pointermove', handleMove);
  target.addEventListener('pointerup', finish);
  target.addEventListener('pointercancel', finish);
  target.addEventListener('lostpointercapture', finish);
}

/**
 * Seeds a detached renderer with the chat history and configuration of the
 * primary renderer, then subscribes it to future batches. Waits until the
 * primary renderer has flushed its queue so the snapshot is complete.
 */
function seedDetachedRenderer(renderer: ChatRenderer): () => void {
  let finished = false;
  let listener: (() => void) | null = null;
  let timer: ReturnType<typeof setInterval> | null = null;

  const finish = () => {
    if (finished) {
      return;
    }
    if (!chatRenderer.isReady() || chatRenderer.queue.length > 0) {
      return;
    }
    finished = true;
    if (listener) {
      chatRenderer.events.off('batchProcessed', listener);
    }
    if (timer) {
      clearInterval(timer);
    }
    renderer.copyConfigFrom(chatRenderer);
    const fromIndex = Math.max(
      0,
      chatRenderer.messages.length - MAX_PERSISTED_MESSAGES,
    );
    const messages = chatRenderer.messages
      .slice(fromIndex)
      .map((message) => serializeMessage(message));
    renderer.processBatch(messages, {
      notifyListeners: false,
      suppressHighlightSound: true,
    });
    renderer.onStateLoaded();
    registerChatRenderer(renderer);
  };

  listener = finish;
  chatRenderer.events.on('batchProcessed', listener);
  timer = setInterval(finish, 250);
  finish();

  return () => {
    if (finished) {
      unregisterChatRenderer(renderer);
      return;
    }
    finished = true;
    if (listener) {
      chatRenderer.events.off('batchProcessed', listener);
    }
    if (timer) {
      clearInterval(timer);
    }
  };
}

type FrameProps = {
  panel: DetachedChatPanel;
  rootRef?: React.Ref<HTMLDivElement>;
  rootStyle?: React.CSSProperties;
  onHeaderPointerDown?: (e: React.PointerEvent) => void;
  resizeHandles?: React.ReactNode;
};

/**
 * The exact chat panel structure of the main window (framed Pane, header with
 * chat tabs, scrollable message log), mounted into whatever detached container
 * its host provides. Owns a dedicated ChatRenderer instance so the detached
 * copy carries its own page context while staying visually identical.
 */
export function DetachedChatPanelFrame(props: FrameProps) {
  const { panel, rootRef, rootStyle, onHeaderPointerDown, resizeHandles } =
    props;
  const settings = useAtomValue(settingsAtom);
  const [pagesRecord, setPagesRecord] = useAtom(chatPagesRecordAtom);
  const scrollerRef = useRef<HTMLDivElement>(null);

  const renderer = useMemo(() => new ChatRenderer(), []);

  useEffect(() => {
    const seedCancel = seedDetachedRenderer(renderer);
    return () => {
      seedCancel();
      renderer.destroy();
    };
  }, [renderer]);

  useEffect(() => {
    const page = pagesRecord[panel.currentPageId];
    if (page) {
      renderer.changePage(page);
    }
  }, [panel.currentPageId]);

  useEffect(() => {
    const listener = (value: boolean) =>
      updateDetachedPanel(panel.id, { scrollTracking: value });
    updateDetachedPanel(panel.id, { scrollTracking: renderer.scrollTracking });
    renderer.events.on('scrollTracking', listener);
    return () => renderer.events.off('scrollTracking', listener);
  }, [renderer, panel.id]);

  const changePage = useCallback(
    (page: Page) => {
      updateDetachedPanel(panel.id, { currentPageId: page.id });
      const draft: Page = { ...page, unreadCount: 0 };
      setPagesRecord({ ...pagesRecord, [page.id]: draft });
    },
    [panel.id, pagesRecord, setPagesRecord],
  );

  const addPage = useCallback(() => {
    const draft = createPage();
    const record = store.get(chatPagesRecordAtom);
    store.set(chatPagesRecordAtom, { ...record, [draft.id]: draft });
    updateDetachedPanel(panel.id, {
      pageIds: [...panel.pageIds, draft.id],
      currentPageId: draft.id,
    });
  }, [panel.id, panel.pageIds]);

  const dropTab = useCallback(
    (pageId: string, insertIndex: number) => {
      dropTabIntoPanel(panel.id, pageId, insertIndex);
    },
    [panel.id],
  );

  return (
    <div className="ChatFloatingPanel" ref={rootRef} style={rootStyle}>
      <Pane theme={settings.theme} canSuspend={false}>
        {resizeHandles}
        <Stack fill vertical className="Panel__stack">
          <Stack.Item>
            <Section fitted className="Panel__header">
              <div
                className="ChatFloatingPanel__drag"
                onPointerDown={onHeaderPointerDown}
              >
                <Stack mr={1} align="center">
                  <Stack.Item grow>
                    <ChatTabs
                      pageIds={panel.pageIds}
                      currentPageId={panel.currentPageId}
                      onChangePage={changePage}
                      onAddPage={addPage}
                      dragSource={{ kind: 'floating', panelId: panel.id }}
                      onDropTab={dropTab}
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      color="transparent"
                      icon="window-restore"
                      tooltip="Merge tabs back into the main window"
                      tooltipPosition="bottom-start"
                      onClick={() => mergePanelIntoMain(panel.id)}
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      color="transparent"
                      icon="times"
                      tooltip="Close and merge tabs back"
                      tooltipPosition="bottom-start"
                      onClick={() => mergePanelIntoMain(panel.id)}
                    />
                  </Stack.Item>
                </Stack>
              </div>
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Section fill fitted position="relative">
              <div
                className="Window__content Layout__content Layout__content--scrollable ChatFloatingPanel__scrollable"
                ref={scrollerRef}
              >
                <ChatPanel
                  renderer={renderer}
                  scrollerRef={scrollerRef}
                  pageId={panel.currentPageId}
                  lineHeight={settings.lineHeight}
                  reversed={false}
                />
              </div>
            </Section>
          </Stack.Item>
        </Stack>
      </Pane>
    </div>
  );
}

type Props = {
  panel: DetachedChatPanel;
};

/**
 * Detached chat in on-map mode: the shared chat panel frame portaled straight
 * into document.body, floating above the map and the main UI layout with its
 * own fixed geometry, pointer-driven move/resize and header-drag merge.
 */
export function ChatFloatingPanel(props: Props) {
  const { panel } = props;
  const [, setDetachedPanels] = useAtom(detachedChatPanelsAtom);
  const rootRef = useRef<HTMLDivElement>(null);

  const applyGeometry = (point: Point) => {
    const root = rootRef.current;
    if (!root) {
      return;
    }
    root.style.left = `${point.x}px`;
    root.style.top = `${point.y}px`;
    root.style.width = `${point.width}px`;
    root.style.height = `${point.height}px`;
  };

  const beginMove = (e: React.PointerEvent) => {
    if ((e.target as HTMLElement).closest(HEADER_DRAG_GUARD)) {
      return;
    }
    const root = rootRef.current;
    if (!root) {
      return;
    }
    const start = root.getBoundingClientRect();
    let current: Point = {
      x: start.left,
      y: start.top,
      width: start.width,
      height: start.height,
    };
    let mergeArmed = false;
    const header = e.currentTarget as HTMLElement;

    const setMergeHint = (value: boolean) => {
      const strip = document.querySelector('.Panel__window .Panel__header');
      if (strip) {
        strip.classList.toggle('Panel__header--mergeHint', value);
      }
      root.classList.toggle('ChatFloatingPanel--merging', value);
    };

    startPointerDrag(
      e,
      (_ev, dx, dy) => {
        current = clampPanelPosition({
          x: start.left + dx,
          y: start.top + dy,
          width: start.width,
          height: start.height,
        });
        applyGeometry(current);
        const strip = document.querySelector('.Panel__window .Panel__header');
        const armed =
          !!strip &&
          rectsIntersect(
            header.getBoundingClientRect(),
            strip.getBoundingClientRect(),
          );
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
        setDetachedPanels((panels) =>
          panels.map((entry) =>
            entry.id === panel.id ? { ...entry, ...current } : entry,
          ),
        );
      },
    );
  };

  const beginResize = (dir: ResizeDir) => (e: React.PointerEvent) => {
    e.stopPropagation();
    const root = rootRef.current;
    if (!root) {
      return;
    }
    const start = root.getBoundingClientRect();
    let current: Point = {
      x: start.left,
      y: start.top,
      width: start.width,
      height: start.height,
    };

    startPointerDrag(
      e,
      (_ev, dx, dy) => {
        let { x, y, width, height } = start;
        if (dir.includes('e')) {
          width = Math.max(MIN_WIDTH, start.width + dx);
        }
        if (dir.includes('s')) {
          height = Math.max(MIN_HEIGHT, start.height + dy);
        }
        if (dir.includes('w')) {
          width = Math.max(MIN_WIDTH, start.width - dx);
          x = start.right - width;
        }
        if (dir.includes('n')) {
          height = Math.max(MIN_HEIGHT, start.height - dy);
          y = start.bottom - height;
        }
        current = { x, y, width, height };
        applyGeometry(current);
      },
      () => {
        setDetachedPanels((panels) =>
          panels.map((entry) =>
            entry.id === panel.id ? { ...entry, ...current } : entry,
          ),
        );
      },
    );
  };

  const resizeHandles = RESIZE_DIRS.map((dir) => (
    <div
      key={dir}
      className={`ResizeHandle ResizeHandle--${dir}`}
      style={{ cursor: RESIZE_CURSORS[dir] }}
      onPointerDown={beginResize(dir)}
    />
  ));

  return createPortal(
    <DetachedChatPanelFrame
      panel={panel}
      rootRef={rootRef}
      rootStyle={{
        left: `${panel.x}px`,
        top: `${panel.y}px`,
        width: `${panel.width}px`,
        height: `${panel.height}px`,
      }}
      onHeaderPointerDown={beginMove}
      resizeHandles={resizeHandles}
    />,
    document.body,
  );
}
