import { atom } from 'jotai';
import { createMainPage } from './model';
import type { DetachedChatPanel } from './types';

export const mainPage = createMainPage();

export const versionAtom = atom(5);
export const scrollTrackingAtom = atom(true);
/** Top-corner chats render the log reversed (newest at the corner). */
export const chatReversedAtom = atom(false);
export const chatPagesAtom = atom([mainPage.id]);
export const currentPageIdAtom = atom(mainPage.id);
export const chatPagesRecordAtom = atom({
  [mainPage.id]: mainPage,
});
export const detachedChatPanelsAtom = atom<DetachedChatPanel[]>([]);

/** Chat has been initialized from storage */
export const chatLoadedAtom = atom(false);

export const allChatAtom = atom((get) => ({
  version: get(versionAtom),
  currentPageId: get(currentPageIdAtom),
  scrollTracking: get(scrollTrackingAtom),
  pages: get(chatPagesAtom),
  pageById: get(chatPagesRecordAtom),
  detachedPanels: get(detachedChatPanelsAtom),
}));

export const currentPageAtom = atom((get) => {
  const pageId = get(currentPageIdAtom);
  const pagesById = get(chatPagesRecordAtom);
  return pagesById[pageId];
});
