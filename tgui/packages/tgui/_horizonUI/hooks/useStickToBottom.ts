import { useEffect, useRef } from 'react';
import type { RefObject } from 'react';
/**
 * Distance (in px) from the bottom within which the chat is
 * considered "scrolled to the bottom".
 */
const BOTTOM_THRESHOLD = 64;

/**
 * Keeps a scrollable container pinned to the bottom when new content
 * arrives, but only if the user was already at the bottom. If they
 * scrolled up to read history, the scroll position is left untouched.
 *
 * - `resetKey`: when this changes (e.g. another ticket is selected or
 *   the window is first opened), the container jumps to the bottom and
 *   re-enables sticking.
 * - `updateKey`: when this changes (e.g. a new message arrives), the
 *   container scrolls to the bottom only if sticking is still enabled.
 *
 * Returns the ref to attach to the scrollable element and the onScroll
 * handler that tracks the user's position.
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
