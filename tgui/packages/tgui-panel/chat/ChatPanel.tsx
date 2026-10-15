/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { useAtom, useAtomValue } from 'jotai';
import { useEffect, useRef, useState } from 'react';
import { Button } from 'tgui-core/components';
import {
  chatPagesRecordAtom,
  chatReversedAtom,
  currentPageIdAtom,
} from './atom';
import { type ChatRenderer, chatRenderer } from './renderer';
import type { Page } from './types';

type Props = {
  fontSize?: string;
  lineHeight: string | number;
  renderer?: ChatRenderer;
  scrollerRef?: React.RefObject<HTMLElement | null>;
  pageId?: string;
  reversed?: boolean;
};

export function ChatPanel(props: Props) {
  const {
    fontSize,
    lineHeight,
    renderer = chatRenderer,
    scrollerRef,
    pageId,
  } = props;
  const ref = useRef<HTMLDivElement>(null);
  const atomReversed = useAtomValue(chatReversedAtom);
  const reversed = props.reversed ?? atomReversed;
  // Page stuff
  const globalPageId = useAtomValue(currentPageIdAtom);
  const currentId = pageId ?? globalPageId;
  const [pagesRecord, setPagesRecord] = useAtom(chatPagesRecordAtom);
  const [scrollTracking, setScrollTracking] = useState(renderer.scrollTracking);

  /** Mounts the renderer */
  useEffect(() => {
    if (ref.current) {
      renderer.mount(ref.current, scrollerRef?.current);
    }
    return () => renderer.unmount();
  }, [renderer, scrollerRef]);

  /** Keeps the scroll button in sync with the renderer's tracking state */
  useEffect(() => {
    const listener = (value: boolean) => setScrollTracking(value);
    renderer.events.on('scrollTracking', listener);
    setScrollTracking(renderer.scrollTracking);
    return () => renderer.events.off('scrollTracking', listener);
  }, [renderer]);

  /** Resets unread count when scroll tracking is enabled */
  useEffect(() => {
    if (scrollTracking) {
      const draft: Page = {
        ...pagesRecord[currentId],
        unreadCount: 0,
      };

      setPagesRecord({
        ...pagesRecord,
        [currentId]: draft,
      });
    }
  }, [scrollTracking]);

  /** Updates the style of the chat panel */
  useEffect(() => {
    renderer.assignStyle({
      width: '100%',
      'white-space': 'pre-wrap',
      'font-size': fontSize,
      'line-height': lineHeight,
    });
  }, [renderer, fontSize, lineHeight]);

  return (
    <>
      <div className="Chat" ref={ref} />
      {!scrollTracking && (
        <Button
          className={
            reversed
              ? 'Chat__scrollButton Chat__scrollButton--reversed'
              : 'Chat__scrollButton'
          }
          icon={reversed ? 'arrow-up' : 'arrow-down'}
          onClick={() => renderer.scrollToBottom()}
        >
          {reversed ? 'Scroll to top' : 'Scroll to bottom'}
        </Button>
      )}
    </>
  );
}
