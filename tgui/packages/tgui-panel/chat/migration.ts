import { store } from '../events/store';
import {
  chatPagesAtom,
  chatPagesRecordAtom,
  currentPageIdAtom,
  detachedChatPanelsAtom,
  mainPage,
  versionAtom,
} from './atom';
import { saveChatState } from './helpers';
import { chatRenderer } from './renderer';
import {
  type DetachedChatPanel,
  type Page,
  type StoredChatSettings,
  storedSettingsSchema,
} from './types';

function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function normalizePageById(input: Record<string, any>): {
  pageById: Record<string, Page>;
  idRemap: Record<string, string>;
  dirty: boolean;
} {
  const pageById: Record<string, Page> = {};
  const idRemap: Record<string, string> = {};
  let dirty = false;

  // Collapse duplicates and ensure keys match `page.id`.
  for (const [key, rawPage] of Object.entries(input)) {
    if (!isRecord(rawPage)) {
      dirty = true;
      continue;
    }

    const page = rawPage as unknown as Page;
    const pageId = typeof page.id === 'string' ? page.id : key;

    // Treat anything marked `isMain` or using the main id as the main page.
    const desiredId =
      page.isMain || pageId === mainPage.id || key === mainPage.id
        ? mainPage.id
        : pageId;

    if (desiredId !== key) {
      idRemap[key] = desiredId;
      dirty = true;
    }

    // If the object claims a different id than its destination key, fix it.
    const normalized: Page = {
      ...page,
      id: desiredId,
      isMain: desiredId === mainPage.id ? true : page.isMain,
    };

    // If a duplicate exists, prefer the entry already under the correct key.
    if (pageById[desiredId]) {
      // Prefer whichever came from the correct key (stability).
      const existingFromCorrectKey = desiredId in input;
      const currentIsCorrectKey = key === desiredId;
      if (currentIsCorrectKey && !existingFromCorrectKey) {
        pageById[desiredId] = normalized;
      }
      dirty = true;
      continue;
    }

    pageById[desiredId] = normalized;
  }

  return { pageById, idRemap, dirty };
}

function createOrderedPages(
  storedPages: string[],
  pageById: Record<string, any>,
  excludedIds?: Set<string>,
): { pages: string[]; dirty: boolean } {
  const pageIds = new Set(Object.keys(pageById));
  const pages: string[] = [];
  const seen = new Set<string>();
  let dirty = false;

  for (const id of storedPages) {
    if (!pageIds.has(id) || seen.has(id) || excludedIds?.has(id)) {
      dirty = true;
      continue;
    }
    seen.add(id);
    pages.push(id);
  }

  for (const id of Object.keys(pageById)) {
    if (seen.has(id) || excludedIds?.has(id)) continue;
    seen.add(id);
    pages.push(id);
    dirty = true;
  }

  return { pages, dirty };
}

function normalizeDetachedPanels(
  rawPanels: unknown,
  pageById: Record<string, Page>,
): { panels: DetachedChatPanel[]; claimedIds: Set<string>; dirty: boolean } {
  const panels: DetachedChatPanel[] = [];
  const claimedIds = new Set<string>();
  let dirty = false;

  if (!Array.isArray(rawPanels)) {
    return { panels, claimedIds, dirty };
  }

  for (const rawPanel of rawPanels) {
    if (!isRecord(rawPanel)) {
      dirty = true;
      continue;
    }

    const pageIds: string[] = [];
    const rawPageIds = Array.isArray(rawPanel.pageIds) ? rawPanel.pageIds : [];
    for (const id of rawPageIds) {
      if (
        typeof id !== 'string' ||
        claimedIds.has(id) ||
        !pageById[id] ||
        pageById[id].isMain ||
        id === mainPage.id
      ) {
        dirty = true;
        continue;
      }
      claimedIds.add(id);
      pageIds.push(id);
    }

    if (pageIds.length === 0) {
      dirty = true;
      continue;
    }

    let currentPageId =
      typeof rawPanel.currentPageId === 'string' ? rawPanel.currentPageId : '';
    if (!pageIds.includes(currentPageId)) {
      currentPageId = pageIds[0];
      dirty = true;
    }

    const x = Number(rawPanel.x) || 0;
    const y = Number(rawPanel.y) || 0;
    const width = Math.max(320, Number(rawPanel.width) || 320);
    const height = Math.max(240, Number(rawPanel.height) || 240);

    panels.push({
      id: typeof rawPanel.id === 'string' ? rawPanel.id : '',
      mode: rawPanel.mode === 'window' ? 'window' : 'onmap',
      pageIds,
      currentPageId,
      x,
      y,
      width,
      height,
    });
  }

  return { panels, claimedIds, dirty };
}

export function normalizeChatSettings(loaded: StoredChatSettings): {
  settings: StoredChatSettings;
  dirty: boolean;
} {
  let dirty = false;

  // `pageById` is the source of truth.
  const {
    pageById: draft,
    idRemap,
    dirty: pageByIdDirty,
  } = normalizePageById(loaded.pageById);
  dirty ||= pageByIdDirty;

  if (!draft[mainPage.id]) {
    draft[mainPage.id] = { ...mainPage };
    dirty = true;
  }

  const {
    panels: detachedPanels,
    claimedIds,
    dirty: panelsDirty,
  } = normalizeDetachedPanels(loaded.detachedPanels, draft);
  dirty ||= panelsDirty;

  // Remap `pages` according to any id changes.
  const remappedPages = loaded.pages.map((id) => idRemap[id] ?? id);
  if (remappedPages.some((id, idx) => id !== loaded.pages[idx])) {
    dirty = true;
  }

  const { pages, dirty: pagesDirty } = createOrderedPages(
    remappedPages,
    draft,
    claimedIds,
  );
  dirty ||= pagesDirty;

  // Ensures at least one page exists.
  const normalizedPages = pages.length ? pages : [mainPage.id];
  if (!pages.length) dirty = true;

  let currentPageId = idRemap[loaded.currentPageId] ?? loaded.currentPageId;
  if (currentPageId !== loaded.currentPageId) dirty = true;
  if (!draft[currentPageId] || claimedIds.has(currentPageId)) {
    currentPageId = normalizedPages[0];
    dirty = true;
  }

  // Normalize per-page state. This is the canonical place where we
  // compensate for older/broken stored settings.
  const defaultFilters = mainPage.acceptedTypes;
  for (const id of normalizedPages) {
    const page = draft[id];
    if (!page) {
      dirty = true;
      continue;
    }

    if (!page.acceptedTypes || typeof page.acceptedTypes !== 'object') {
      page.acceptedTypes = {};
      dirty = true;
    }

    for (const type of Object.keys(defaultFilters)) {
      if (page.acceptedTypes[type] === undefined) {
        page.acceptedTypes[type] = defaultFilters[type];
        dirty = true;
      }
    }

    // Avoid persisting and restoring unread counts.
    if (page.unreadCount !== 0) {
      page.unreadCount = 0;
      dirty = true;
    }
  }

  return {
    settings: {
      ...loaded,
      pages: normalizedPages,
      currentPageId,
      pageById: draft,
      detachedPanels,
    },
    dirty,
  };
}

export function startChatStateMigration(state: StoredChatSettings): void {
  const parsed = storedSettingsSchema.safeParse(state);
  if (!parsed.success) {
    console.error('Failed to parse stored chat settings:', parsed.error);
    return;
  }
  const { settings: loaded, dirty: wasInconsistent } = normalizeChatSettings(
    parsed.data,
  );

  if (wasInconsistent) {
    console.error('Chat settings were inconsistent, rewriting to storage');
    console.log('Comparison, stored vs update:', state, loaded);
  }

  store.set(versionAtom, loaded.version);
  store.set(chatPagesAtom, loaded.pages);
  store.set(currentPageIdAtom, loaded.currentPageId);
  store.set(chatPagesRecordAtom, loaded.pageById);
  store.set(detachedChatPanelsAtom, loaded.detachedPanels ?? []);

  chatRenderer.changePage(loaded.pageById[loaded.currentPageId]);

  saveChatState(loaded);
  console.log('Restored chat settings:', loaded);
}
