/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { useAtom, useAtomValue } from 'jotai';
import { useCallback, useEffect } from 'react';
import { Pane } from 'tgui/layouts';
import { Button, Section, Stack } from 'tgui-core/components';
import { visibleAtom } from './audio/atoms';
import { NowPlayingWidget } from './audio/NowPlayingWidget';
import { ChatPanel } from './chat/ChatPanel';
import { ChatTabs } from './chat/ChatTabs';
import { ResizeHandles } from './chat/ResizeHandles';
import { chatRenderer } from './chat/renderer';
import { useChatPersistence } from './chat/use-chat-persistence';
import { useChatPlacement } from './chat/use-chat-placement';
import { gameAtom } from './game/atoms';
import { useKeepAlive } from './game/use-keep-alive';
import { Notifications } from './Notifications';
import { PingIndicator } from './ping/PingIndicator';
import { ReconnectButton } from './reconnect';
import { settingsVisibleAtom } from './settings/atoms';
import { SettingsPanel } from './settings/SettingsPanel';
import { useSettings } from './settings/use-settings';
import { CommandBar } from './verbs/CommandBar';

export function Panel(props) {
  const [audioVisible, setAudioVisible] = useAtom(visibleAtom);
  const game = useAtomValue(gameAtom);
  const { settings, updateSettings } = useSettings();
  const [settingsVisible, setSettingsVisible] = useAtom(settingsVisibleAtom);
  useChatPersistence();
  const { isOnMap, isPopup, chatCorner } = useChatPlacement();
  const frameless = isOnMap && settings.chatFrameless;
  useKeepAlive();

  const chatTop = frameless && chatCorner.startsWith('top');
  const messageBg = frameless && settings.chatMessageBg;

  useEffect(() => {
    const body = document.body;
    if (!frameless) {
      body.classList.remove(
        'frameless',
        'frameless-visible',
        'chat-message-bg',
        'chat-top',
      );
      chatRenderer.setFrameless(false);
      return;
    }

    body.classList.add('frameless');
    body.classList.toggle('chat-message-bg', !!messageBg);
    body.classList.toggle('chat-top', chatTop);
    chatRenderer.setFrameless(true);

    const show = () => {
      body.classList.add('frameless-visible');
      chatRenderer.scrollToBottom();
    };
    const hide = () => {
      if (!settingsVisible) {
        body.classList.remove('frameless-visible');
      }
    };

    body.addEventListener('mouseenter', show);
    body.addEventListener('mouseleave', hide);

    if (settingsVisible) {
      body.classList.add('frameless-visible');
    } else {
      body.classList.remove('frameless-visible');
    }

    return () => {
      body.removeEventListener('mouseenter', show);
      body.removeEventListener('mouseleave', hide);
      body.classList.remove(
        'frameless',
        'frameless-visible',
        'chat-message-bg',
        'chat-top',
      );
      chatRenderer.setFrameless(false);
    };
  }, [frameless, messageBg, chatTop, settingsVisible]);

  const onPopupDrag = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    const pixelRatio = window.devicePixelRatio ?? 1;
    const startMouseX = e.screenX * pixelRatio;
    const startMouseY = e.screenY * pixelRatio;

    Byond.winget('tgui_panel_popup', ['pos']).then((props) => {
      const startX = props.pos.x;
      const startY = props.pos.y;

      const onMove = (ev: MouseEvent) => {
        ev.preventDefault();
        const dx = ev.screenX * pixelRatio - startMouseX;
        const dy = ev.screenY * pixelRatio - startMouseY;
        Byond.winset('tgui_panel_popup', {
          pos: `${startX + dx},${startY + dy}`,
        });
      };

      const onUp = () => {
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
      };

      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    });
  }, []);

  return (
    <Pane theme={settings.theme} canSuspend={false}>
      {isOnMap && <ResizeHandles corner={chatCorner} />}
      {isPopup && (
        <>
          <ResizeHandles allEdges target="tgui_panel_popup" />
          <div className="PanelDragBar" onMouseDown={onPopupDrag} />
        </>
      )}
      <Stack fill vertical className="Panel__stack">
        <Stack.Item>
          <Section fitted className="Panel__header">
            <Stack mr={1} align="center">
              <Stack.Item grow>
                <ChatTabs />
              </Stack.Item>
              <Stack.Item>
                <PingIndicator />
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="transparent"
                  icon={isOnMap ? 'columns' : 'window-maximize'}
                  tooltip={isOnMap ? 'Switch to panel' : 'Switch to overlay'}
                  tooltipPosition="bottom-start"
                  onClick={() => {
                    console.log(
                      'panel/toggle_layout: sending, isOnMap =',
                      isOnMap,
                    );
                    Byond.sendMessage('panel/toggle_layout');
                  }}
                />
              </Stack.Item>
              {isOnMap && (
                <Stack.Item>
                  <Button
                    color="transparent"
                    icon={settings.chatFrameless ? 'eye-slash' : 'eye'}
                    tooltip={
                      settings.chatFrameless
                        ? 'Show chat frame'
                        : 'Hide chat frame (frameless)'
                    }
                    tooltipPosition="bottom-start"
                    onClick={() =>
                      updateSettings({
                        chatFrameless: !settings.chatFrameless,
                      })
                    }
                  />
                </Stack.Item>
              )}
              <Stack.Item>
                <Button
                  color="grey"
                  selected={audioVisible}
                  icon="music"
                  tooltip="Music player"
                  tooltipPosition="bottom-start"
                  onClick={() => setAudioVisible((v) => !v)}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon={settingsVisible ? 'times' : 'cog'}
                  selected={settingsVisible}
                  tooltip={settingsVisible ? 'Close settings' : 'Open settings'}
                  tooltipPosition="bottom-start"
                  onClick={() => setSettingsVisible((v) => !v)}
                />
              </Stack.Item>
            </Stack>
          </Section>
        </Stack.Item>
        {audioVisible && (
          <Stack.Item>
            <Section>
              <NowPlayingWidget />
            </Section>
          </Stack.Item>
        )}
        {settingsVisible && (
          <Stack.Item>
            <SettingsPanel isOnMap={isOnMap} />
          </Stack.Item>
        )}
        <Stack.Item grow>
          <Section fill fitted position="relative">
            <Pane.Content scrollable id="chat-pane">
              <ChatPanel lineHeight={settings.lineHeight} />
            </Pane.Content>
            <Notifications>
              {game.connectionLostAt && (
                <Notifications.Item rightSlot={<ReconnectButton />}>
                  You are either AFK, experiencing lag or the connection has
                  closed.
                </Notifications.Item>
              )}
              {game.roundRestartedAt && (
                <Notifications.Item>
                  The connection has been closed because the server is
                  restarting. Please wait while you automatically reconnect.
                </Notifications.Item>
              )}
            </Notifications>
          </Section>
        </Stack.Item>
        <Stack.Item>
          <CommandBar />
        </Stack.Item>
      </Stack>
    </Pane>
  );
}
