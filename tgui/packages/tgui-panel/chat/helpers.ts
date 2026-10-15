import { storage } from 'common/storage';
import { store } from '../events/store';
import {
  allChatAtom,
  chatLoadedAtom,
  chatPagesAtom,
  chatPagesRecordAtom,
  currentPageAtom,
  detachedChatPanelsAtom,
  scrollTrackingAtom,
} from './atom';
import { MAX_PERSISTED_MESSAGES } from './constants';
import { canPageAcceptType, serializeMessage } from './model';
import { chatRenderer } from './renderer';
import type { DetachedChatPanel, StoredChatSettings } from './types';

chatRenderer.events.on(
  'batchProcessed',
  (countByType: Record<string, number>) => {
    // Use this flag to workaround unread messages caused by
    // loading them from storage. Side effect of that, is that
    // message count can not be trusted, only unread count.
    if (store.get(chatLoadedAtom)) {
      updateMessageCount(countByType);
    }
  },
);

function updateMessageCount(countByType: Record<string, number>): void {
  const pagesRecord = store.get(chatPagesRecordAtom);
  const pages = store.get(chatPagesAtom);
  const currentPage = store.get(currentPageAtom);
  const scrollTracking = store.get(scrollTrackingAtom);
  const detachedPanels = store.get(detachedChatPanelsAtom);

  const draftpagesRecord = { ...pagesRecord };

  const applyUnread = (
    pageIds: string[],
    currentPageId: string,
    tracked: boolean,
  ) => {
    for (const pageId of pageIds) {
      const page = pagesRecord[pageId];
      if (!page) {
        continue;
      }
      let unreadCount = 0;

      for (const type in countByType) {
        /// Message does not belong here
        if (!canPageAcceptType(page, type)) continue;

        // Current page scroll tracked
        if (pageId === currentPageId && tracked) continue;

        // This page received the same message which we can read on the current
        // page
        const current = pagesRecord[currentPageId];
        if (
          pageId !== currentPageId &&
          current &&
          canPageAcceptType(current, type)
        ) {
          continue;
        }
        unreadCount += countByType[type];
      }

      if (unreadCount > 0) {
        draftpagesRecord[page.id] = {
          ...page,
          unreadCount: page.unreadCount + unreadCount,
        };
      }
    }
  };

  applyUnread(pages, currentPage?.id ?? 'main', scrollTracking);
  for (const panel of detachedPanels) {
    applyUnread(panel.pageIds, panel.currentPageId, !!panel.scrollTracking);
  }

  store.set(chatPagesRecordAtom, draftpagesRecord);
}

export function saveChatToStorage(): void {
  saveChatMessages();
  const allChat = store.get(allChatAtom);
  saveChatState(allChat);
}

function saveChatMessages(): void {
  const fromIndex = Math.max(
    0,
    chatRenderer.messages.length - MAX_PERSISTED_MESSAGES,
  );

  const messages = chatRenderer.messages
    .slice(fromIndex)
    .map((message) => serializeMessage(message));

  storage.set('chat-messages', messages);
}

export function saveChatState(state: StoredChatSettings): void {
  // Avoid persisting frequently-changing unread counts.
  const pageById = Object.fromEntries(
    Object.entries(state.pageById).map(([id, page]) => [
      id,
      {
        ...page,
        unreadCount: 0,
      },
    ]),
  );
  const detachedPanels = (state.detachedPanels ?? []).map(
    (panel: DetachedChatPanel) => {
      const { scrollTracking, ...rest } = panel;
      return rest;
    },
  );

  storage.set('chat-state', {
    ...state,
    pageById,
    detachedPanels,
  });
}
