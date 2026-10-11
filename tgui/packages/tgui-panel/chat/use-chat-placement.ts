import { useAtomValue } from 'jotai';
import { useEffect, useState } from 'react';
import { settingsAtom } from '../settings/atoms';
import type { ChatCorner } from '../settings/constants';
import { loadChatRatio, saveChatRatio } from './chat-ratio';

const DEFAULT_W_RATIO = 1 / 3;
const DEFAULT_H_RATIO = 1 / 3;

function defaultPosition(
  corner: ChatCorner,
  screenX: number,
  screenY: number,
  browserW: number,
  browserH: number,
  padding: number,
): { x: number; y: number } {
  switch (corner) {
    case 'top-left':
      return { x: padding, y: padding };
    case 'bottom-left':
      return { x: padding, y: screenY - (browserH + padding) };
    case 'bottom-right':
      return {
        x: screenX - (browserW + padding),
        y: screenY - (browserH + padding),
      };
    case 'top-right':
    default:
      return {
        x: screenX - (browserW + padding),
        y: padding,
      };
  }
}

function setAnchors(
  browserX: number,
  browserY: number,
  browserW: number,
  browserH: number,
  mapW: number,
  mapH: number,
) {
  const a1x = (browserX / mapW) * 100;
  const a1y = (browserY / mapH) * 100;
  const a2x = ((browserX + browserW) / mapW) * 100;
  const a2y = ((browserY + browserH) / mapH) * 100;
  Byond.winset('browseroutput', {
    anchor1: `${a1x.toFixed(2)},${a1y.toFixed(2)}`,
    anchor2: `${a2x.toFixed(2)},${a2y.toFixed(2)}`,
  });
}

let initialCorner: ChatCorner | null = null;
let initialPadding: number | null = null;

export function useChatPlacement() {
  const [isOnMap, setIsOnMap] = useState(false);
  const [isPopup, setIsPopup] = useState(false);
  const settings = useAtomValue(settingsAtom);
  const chatCorner = (settings.chatCorner || 'top-right') as ChatCorner;
  const chatOpacity = settings.chatOpacity ?? 0.45;
  const chatPadding = settings.chatPadding ?? 10;

  useEffect(() => {
    document.body.style.setProperty('--chat-opacity', `${chatOpacity}`);
  }, [chatOpacity]);

  useEffect(() => {
    const settingChanged =
      (initialCorner !== null && initialCorner !== chatCorner) ||
      (initialPadding !== null && initialPadding !== chatPadding);
    console.log('useChatPlacement: effect run, settingChanged =', settingChanged, 'initialCorner =', initialCorner, 'chatCorner =', chatCorner);
    initialCorner = chatCorner;
    initialPadding = chatPadding;

    const place = (mapSize: { x: number; y: number }) => {
      const screenX = mapSize.x;
      const screenY = mapSize.y;

      if (settingChanged) {
        console.log('useChatPlacement: settingChanged, repositioning');
        Byond.winget('browseroutput', ['size']).then((props) => {
          const browserW = props.size.x;
          const browserH = props.size.y;
          const pos = defaultPosition(chatCorner, screenX, screenY, browserW, browserH, chatPadding);
          console.log('useChatPlacement: repositioned to', pos);
          Byond.winset('browseroutput', {
            pos: `${pos.x},${pos.y}`,
          });
          setAnchors(pos.x, pos.y, browserW, browserH, screenX, screenY);
          saveChatRatio();
          console.log('panel/bounds (setting change):', { x: pos.x, y: pos.y, w: browserW, h: browserH });
          Byond.sendMessage('panel/bounds', { x: pos.x, y: pos.y, w: browserW, h: browserH });
          document.body.classList.add('onmap');
          document.body.style.backgroundColor = 'transparent';
          setIsOnMap(true);
        });
        return;
      }

      loadChatRatio().then((saved) => {
        let browserW: number;
        let browserH: number;
        let browserX: number;
        let browserY: number;

        if (saved) {
          browserW = Math.round(screenX * saved.w);
          browserH = Math.round(screenY * saved.h);
          browserX = Math.round(screenX * saved.x);
          browserY = Math.round(screenY * saved.y);
        } else {
          browserW = Math.round(screenX * DEFAULT_W_RATIO);
          browserH = Math.round(screenY * DEFAULT_H_RATIO);
          const pos = defaultPosition(chatCorner, screenX, screenY, browserW, browserH, chatPadding);
          browserX = pos.x;
          browserY = pos.y;
        }

        Byond.winset('browseroutput', {
          size: `${browserW}x${browserH}`,
          pos: `${browserX},${browserY}`,
        });
        setAnchors(browserX, browserY, browserW, browserH, screenX, screenY);
        console.log('panel/bounds (initial):', { x: browserX, y: browserY, w: browserW, h: browserH });
        Byond.sendMessage('panel/bounds', { x: browserX, y: browserY, w: browserW, h: browserH });

        document.body.classList.add('onmap');
        document.body.style.backgroundColor = 'transparent';
        setIsOnMap(true);
      });
    };

    document.body.classList.remove('onmap');
    setIsOnMap(false);
    setIsPopup(false);

    Byond.winget('browseroutput', 'parent').then((browserParent) => {
      console.log('useChatPlacement: parent =', browserParent);
      if (browserParent === 'mapwindow') {
        Byond.winget('mapwindow', ['size']).then((mapProperties) => {
          place(mapProperties.size);
        });
      } else if (browserParent === 'output_browser') {
        Byond.winget('output_browser', ['size']).then(
          (outputBrowserWindowProperties) => {
            Byond.winset('browseroutput', {
              size: `${outputBrowserWindowProperties.size.x}x${outputBrowserWindowProperties.size.y}`,
            });
          },
        );
      } else if (browserParent === 'tgui_panel_popup') {
        console.log('useChatPlacement: popup mode');
        setIsPopup(true);
      }
    });
  }, [chatCorner, chatPadding]);

  return { isOnMap, isPopup, chatCorner };
}
