import { useCallback } from 'react';
import type { ChatCorner } from '../settings/constants';
import { saveChatRatio } from './chat-ratio';

const pixelRatio = window.devicePixelRatio ?? 1;
const MIN_WIDTH = 200;
const MIN_HEIGHT = 100;

type Point = [number, number];

let winsetTarget = 'browseroutput';
let pendingWinset: { pos?: string; size?: string } = {};
let winsetRaf: number | undefined;

function flushWinset() {
  winsetRaf = undefined;
  if (pendingWinset.pos || pendingWinset.size) {
    Byond.winset(winsetTarget, pendingWinset);
    pendingWinset = {};
  }
}

function scheduleWinset() {
  if (winsetRaf === undefined) {
    winsetRaf = requestAnimationFrame(flushWinset);
  }
}

function sendBounds() {
  Byond.winget(winsetTarget, ['pos', 'size']).then((props) => {
    Byond.sendMessage('panel/bounds', {
      x: props.pos.x,
      y: props.pos.y,
      w: props.size.x,
      h: props.size.y,
    });
  });
}

function updateAnchors() {
  if (winsetTarget !== 'browseroutput') return;
  Promise.all([
    Byond.winget('browseroutput', ['pos', 'size']),
    Byond.winget('mapwindow', ['size']),
  ]).then(([browser, map]) => {
    const mapW = map.size.x;
    const mapH = map.size.y;
    if (!mapW || !mapH) return;
    const a1x = (browser.pos.x / mapW) * 100;
    const a1y = (browser.pos.y / mapH) * 100;
    const a2x = ((browser.pos.x + browser.size.x) / mapW) * 100;
    const a2y = ((browser.pos.y + browser.size.y) / mapH) * 100;
    Byond.winset('browseroutput', {
      anchor1: `${a1x.toFixed(2)},${a1y.toFixed(2)}`,
      anchor2: `${a2x.toFixed(2)},${a2y.toFixed(2)}`,
    });
  });
}

function startDrag(
  e: React.MouseEvent,
  onMove: (dx: number, dy: number, startPos: Point, startSize: Point) => void,
) {
  e.preventDefault();
  const startMouseX = e.screenX * pixelRatio;
  const startMouseY = e.screenY * pixelRatio;

  Byond.winget(winsetTarget, ['pos', 'size']).then(
    (props: {
      pos: { x: number; y: number };
      size: { x: number; y: number };
    }) => {
      const startPos: Point = [props.pos.x, props.pos.y];
      const startSize: Point = [props.size.x, props.size.y];

      const handleMove = (ev: MouseEvent) => {
        ev.preventDefault();
        const dx = ev.screenX * pixelRatio - startMouseX;
        const dy = ev.screenY * pixelRatio - startMouseY;
        onMove(dx, dy, startPos, startSize);
      };

      const handleUp = (ev: MouseEvent) => {
        handleMove(ev);
        if (winsetRaf !== undefined) {
          cancelAnimationFrame(winsetRaf);
          winsetRaf = undefined;
        }
        flushWinset();
        document.removeEventListener('mousemove', handleMove);
        document.removeEventListener('mouseup', handleUp);
        updateAnchors();
        saveChatRatio();
        sendBounds();
      };

      document.addEventListener('mousemove', handleMove);
      document.addEventListener('mouseup', handleUp);
    },
  );
}

function resizeLeft(
  dx: number,
  startPos: Point,
  startSize: Point,
): { pos: string; size: string } {
  const newW = Math.max(startSize[0] - dx, MIN_WIDTH);
  const actualDx = startSize[0] - newW;
  return {
    pos: `${startPos[0] + actualDx},${startPos[1]}`,
    size: `${newW}x${startSize[1]}`,
  };
}

function resizeRight(
  dx: number,
  startPos: Point,
  startSize: Point,
): { size: string } {
  const newW = Math.max(startSize[0] + dx, MIN_WIDTH);
  return { size: `${newW}x${startSize[1]}` };
}

function resizeTop(
  dy: number,
  startPos: Point,
  startSize: Point,
): { pos: string; size: string } {
  const newH = Math.max(startSize[1] - dy, MIN_HEIGHT);
  const actualDy = startSize[1] - newH;
  return {
    pos: `${startPos[0]},${startPos[1] + actualDy}`,
    size: `${startSize[0]}x${newH}`,
  };
}

function resizeBottom(
  dy: number,
  startPos: Point,
  startSize: Point,
): { size: string } {
  const newH = Math.max(startSize[1] + dy, MIN_HEIGHT);
  return { size: `${startSize[0]}x${newH}` };
}

type Props = {
  corner?: ChatCorner;
  target?: string;
  allEdges?: boolean;
};

function makeEdgeHandler(
  resizeFn: (d: number, startPos: Point, startSize: Point) => { pos?: string; size?: string; size_only?: string },
  axis: 'x' | 'y',
) {
  return (e: React.MouseEvent) =>
    startDrag(e, (dx, dy, startPos, startSize) => {
      const result = resizeFn(axis === 'x' ? dx : dy, startPos, startSize);
      Object.assign(pendingWinset, result);
      scheduleWinset();
    });
}

function makeCornerHandler(
  hFn: (d: number, sp: Point, ss: Point) => { pos?: string; size: string },
  vFn: (d: number, sp: Point, ss: Point) => { pos?: string; size: string },
) {
  return (e: React.MouseEvent) =>
    startDrag(e, (dx, dy, startPos, startSize) => {
      const hResult = hFn(dx, startPos, startSize);
      const vResult = vFn(dy, startPos, startSize);
      const newW = hResult.size.split('x')[0];
      const newH = vResult.size.split('x')[1];
      const newX = hResult.pos?.split(',')[0] ?? `${startPos[0]}`;
      const newY = vResult.pos?.split(',')[1] ?? `${startPos[1]}`;
      pendingWinset.pos = `${newX},${newY}`;
      pendingWinset.size = `${newW}x${newH}`;
      scheduleWinset();
    });
}

export function ResizeHandles({ corner, target = 'browseroutput', allEdges = false }: Props) {
  winsetTarget = target;

  if (allEdges) {
    return (
      <>
        <div className="ResizeHandle ResizeHandle--left" onMouseDown={makeEdgeHandler(resizeLeft, 'x')} />
        <div className="ResizeHandle ResizeHandle--right" onMouseDown={makeEdgeHandler(resizeRight, 'x')} />
        <div className="ResizeHandle ResizeHandle--top" onMouseDown={makeEdgeHandler(resizeTop, 'y')} />
        <div className="ResizeHandle ResizeHandle--bottom" onMouseDown={makeEdgeHandler(resizeBottom, 'y')} />
        <div className="ResizeHandle ResizeHandle--top-left" style={{ cursor: 'nwse-resize' }} onMouseDown={makeCornerHandler(resizeLeft, resizeTop)} />
        <div className="ResizeHandle ResizeHandle--top-right" style={{ cursor: 'nesw-resize' }} onMouseDown={makeCornerHandler(resizeRight, resizeTop)} />
        <div className="ResizeHandle ResizeHandle--bottom-left" style={{ cursor: 'nesw-resize' }} onMouseDown={makeCornerHandler(resizeLeft, resizeBottom)} />
        <div className="ResizeHandle ResizeHandle--bottom-right" style={{ cursor: 'nwse-resize' }} onMouseDown={makeCornerHandler(resizeRight, resizeBottom)} />
      </>
    );
  }

  const isLeft = corner?.includes('left') ?? false;
  const isTop = corner?.includes('top') ?? true;

  const onHorizontalResize = makeEdgeHandler(isLeft ? resizeRight : resizeLeft, 'x');
  const onVerticalResize = makeEdgeHandler(isTop ? resizeBottom : resizeTop, 'y');

  const onCornerResize = (e: React.MouseEvent) =>
    startDrag(e, (dx, dy, startPos, startSize) => {
      const newW = Math.max(isLeft ? startSize[0] + dx : startSize[0] - dx, MIN_WIDTH);
      const newH = Math.max(isTop ? startSize[1] + dy : startSize[1] - dy, MIN_HEIGHT);
      const newX = isLeft ? startPos[0] : startPos[0] + (startSize[0] - newW);
      const newY = isTop ? startPos[1] : startPos[1] + (startSize[1] - newH);
      pendingWinset.pos = `${newX},${newY}`;
      pendingWinset.size = `${newW}x${newH}`;
      scheduleWinset();
    });

  const hEdge = isLeft ? 'right' : 'left';
  const vEdge = isTop ? 'bottom' : 'top';
  const diag =
    (isTop && isLeft) || (!isTop && !isLeft) ? 'nwse-resize' : 'nesw-resize';

  return (
    <>
      <div className={`ResizeHandle ResizeHandle--${hEdge}`} onMouseDown={onHorizontalResize} />
      <div className={`ResizeHandle ResizeHandle--${vEdge}`} onMouseDown={onVerticalResize} />
      <div className={`ResizeHandle ResizeHandle--${vEdge}-${hEdge}`} style={{ cursor: diag }} onMouseDown={onCornerResize} />
    </>
  );
}
