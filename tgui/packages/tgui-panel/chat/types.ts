import * as z from 'zod';

export type ChatPages = {
  chatPages: Record<string, Page>;
};

export type Page = {
  isMain: boolean;
  id: string;
  name: string;
  acceptedTypes: Record<string, boolean>;
  unreadCount: number;
  hideUnreadCount: boolean;
  createdAt: number;
};

export type DetachedChatPanel = {
  id: string;
  pageIds: string[];
  currentPageId: string;
  x: number;
  y: number;
  width: number;
  height: number;
  scrollTracking?: boolean;
};

export const detachedChatPanelSchema = z.object({
  id: z.string(),
  pageIds: z.array(z.string()),
  currentPageId: z.string(),
  x: z.number(),
  y: z.number(),
  width: z.number(),
  height: z.number(),
});

export const storedSettingsSchema = z.object({
  version: z.number(),
  scrollTracking: z.boolean(),
  currentPageId: z.string(),
  pages: z.array(z.string()),
  pageById: z.record(z.string(), z.any()),
  detachedPanels: z.array(detachedChatPanelSchema).optional(),
});

export type StoredChatSettings = z.infer<typeof storedSettingsSchema>;
