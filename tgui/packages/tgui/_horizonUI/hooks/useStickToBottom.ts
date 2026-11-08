import { useEffect, useRef } from 'react';
import type { RefObject } from 'react';
// Max distance (px) from the bottom that still counts as "at the bottom".
const BOTTOM_THRESHOLD = 64;

/**
 * Keeps the container scrolled to the bottom on new content, but only
 * while the user is at the bottom; scrolling up to read history pauses
 * the following until they return.
 *
 * `resetKey` (e.g. selected ticket) forces a jump to the bottom,
 * `updateKey` (e.g. message count) scrolls only if still following.
 */
export function useStickToBottom(
  resetKey: unknown,
  updateKey: unknown,
): {
  ref: RefObject<HTMLDivElement | null>;
  onScroll: () => void;
} {
  const ref = useRef<HTMLDivElement | null>(null);
  const stickRef = useRef(true);

  const onScroll = () => {
    const el = ref.current;
    if (!el) {
      return;
    }
    const distance = el.scrollHeight - el.scrollTop - el.clientHeight;
    stickRef.current = distance <= BOTTOM_THRESHOLD;
  };

  // Ticket switch / first mount: always jump to the bottom.
  useEffect(() => {
    const el = ref.current;
    if (!el) {
      return;
    }
    stickRef.current = true;
    el.scrollTop = el.scrollHeight;
  }, [resetKey]);

  // New content: follow it only while we are at the bottom.
  useEffect(() => {
    const el = ref.current;
    if (!el || !stickRef.current) {
      return;
    }
    el.scrollTop = el.scrollHeight;
  }, [updateKey]);

  return { ref, onScroll };
}
