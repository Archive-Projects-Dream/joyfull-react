/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { useAtom } from 'jotai';
import { Fragment, useEffect, useState } from 'react';
import { Box, Button, Stack, Tabs } from 'tgui-core/components';
import { settingsVisibleAtom } from '../settings/atoms';
import {
  beginTabDrag,
  dropTabIntoMain,
  endTabDrag,
  getTabDrag,
  type TabDragSource,
} from './chat-tab-drag';
import type { Page } from './types';
import { useChatPages } from './use-chat-pages';

type UnreadCountWidgetProps = {
  value: number;
};

function UnreadCountWidget(props: UnreadCountWidgetProps) {
  const { value } = props;

  return <Box className="UnreadCount">{Math.min(value, 99)}</Box>;
}

type Props = {
  pageIds?: string[];
  currentPageId?: string;
  onChangePage?: (page: Page) => void;
  onAddPage?: () => void;
  dragSource?: TabDragSource;
  onDropTab?: (pageId: string, insertIndex: number) => void;
};

function computeInsertIndex(strip: HTMLElement, clientX: number) {
  const tabs = strip.querySelectorAll('.Tabs__Tab');
  for (let i = 0; i < tabs.length; i++) {
    const rect = tabs[i].getBoundingClientRect();
    if (clientX < rect.left + rect.width / 2) {
      return i;
    }
  }
  return tabs.length;
}

export function ChatTabs(props: Props) {
  const {
    pageIds,
    currentPageId,
    onChangePage,
    onAddPage,
    dragSource = { kind: 'main' } as TabDragSource,
    onDropTab = dropTabIntoMain,
  } = props;
  const {
    pages: mainPages,
    currentPageId: mainCurrentPageId,
    pagesRecord,
    changeChatPage,
    addChatPage,
  } = useChatPages();

  const [, setSettingsVisible] = useAtom(settingsVisibleAtom);
  const [insertIndex, setInsertIndex] = useState<number | null>(null);
  const [draggingPageId, setDraggingPageId] = useState<string | null>(null);

  const resolvedPageIds = pageIds ?? mainPages;
  const resolvedCurrentPageId = currentPageId ?? mainCurrentPageId;
  const resolvedChangePage = onChangePage ?? changeChatPage;
  const resolvedAddPage =
    onAddPage ??
    (() => {
      addChatPage();
      setSettingsVisible(true);
    });

  useEffect(() => {
    if (insertIndex === null && draggingPageId === null) {
      return;
    }
    const clear = () => {
      setInsertIndex(null);
      setDraggingPageId(null);
    };
    document.addEventListener('dragend', clear);
    return () => document.removeEventListener('dragend', clear);
  }, [insertIndex, draggingPageId]);

  const handleStripDragOver = (e: React.DragEvent) => {
    if (!getTabDrag()) {
      return;
    }
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    const index = computeInsertIndex(e.currentTarget as HTMLElement, e.clientX);
    setInsertIndex((prev) => (prev === index ? prev : index));
  };

  const handleStripDragLeave = (e: React.DragEvent) => {
    const strip = e.currentTarget as HTMLElement;
    if (!strip.contains(e.relatedTarget as Node)) {
      setInsertIndex(null);
    }
  };

  const handleStripDrop = (e: React.DragEvent) => {
    const dragState = getTabDrag();
    if (!dragState) {
      return;
    }
    e.preventDefault();
    e.stopPropagation();
    const index = computeInsertIndex(e.currentTarget as HTMLElement, e.clientX);
    setInsertIndex(null);
    onDropTab(dragState.pageId, index);
  };

  const handleTabDragStart = (e: React.DragEvent, page: Page) => {
    setDraggingPageId(page.id);
    beginTabDrag(e, page.id, dragSource);
  };

  const handleTabDragEnd = () => {
    setDraggingPageId(null);
    setInsertIndex(null);
    endTabDrag();
  };

  return (
    <Stack align="center">
      <Stack.Item>
        <Tabs
          scrollable
          textAlign="center"
          onDragOver={handleStripDragOver}
          onDragLeave={handleStripDragLeave}
          onDrop={handleStripDrop}
        >
          {resolvedPageIds.map((pageId, index) => {
            const actual = pagesRecord[pageId];
            if (!actual) {
              return null;
            }
            return (
              <Fragment key={pageId}>
                {insertIndex === index && (
                  <div className="ChatTabDropIndicator" />
                )}
                <Tabs.Tab
                  selected={pageId === resolvedCurrentPageId}
                  draggable={!actual.isMain}
                  className={
                    draggingPageId === pageId ? 'Tab--dragging' : undefined
                  }
                  onClick={() => resolvedChangePage(actual)}
                  onDragStart={(e: React.DragEvent) =>
                    handleTabDragStart(e, actual)
                  }
                  onDragEnd={handleTabDragEnd}
                >
                  {actual.name}
                  {!actual.hideUnreadCount && actual.unreadCount > 0 && (
                    <UnreadCountWidget value={actual.unreadCount} />
                  )}
                </Tabs.Tab>
              </Fragment>
            );
          })}
          {insertIndex === resolvedPageIds.length &&
            resolvedPageIds.length > 0 && (
              <div className="ChatTabDropIndicator" />
            )}
        </Tabs>
      </Stack.Item>
      <Stack.Item>
        <Button
          color="transparent"
          icon="plus"
          onClick={() => {
            resolvedAddPage();
          }}
        />
      </Stack.Item>
    </Stack>
  );
}
