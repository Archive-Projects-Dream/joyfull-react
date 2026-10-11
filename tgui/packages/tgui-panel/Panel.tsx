/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { useAtom, useAtomValue } from 'jotai';
import { useEffect } from 'react';
import { useCallback } from 'react';
import { Pane } from 'tgui/layouts';
import { Button, Icon, Section, Stack } from 'tgui-core/components';
import { visibleAtom } from './audio/atoms';
import { NowPlayingWidget } from './audio/NowPlayingWidget';
import { ChatPanel } from './chat/ChatPanel';
import { ChatTabs } from './chat/ChatTabs';
import {
  cancelChatStripCollapse,
  expandChatFromStrip,
  isChatStripCollapsed,
  scheduleChatStripCollapse,
  setChatStripEdge,
  setChatStripMode,
} from './chat/chat-hover-strip';
import { useChatPersistence } from './chat/use-chat-persistence';
import { useChatPlacement } from './chat/use-chat-placement';
import { chatRenderer } from './chat/renderer';
import { gameAtom } from './game/atoms';
import { useKeepAlive } from './game/use-keep-alive';
import { Notifications } from './Notifications';
import { PingIndicator } from './ping/PingIndicator';
import { ReconnectButton } from './reconnect';
import { settingsVisibleAtom } from './settings/atoms';
import { SettingsPanel } from './settings/SettingsPanel';
import { useSettings } from './settings/use-settings';
import {
  ResizeHandles,
  startChatMove,
  startPopupMove,
} from './chat/ResizeHandles';
import { CommandBar } from './verbs/CommandBar';

export function Panel(props) {
  const [audioVisible, setAudioVisible] = useAtom(visibleAtom);
  const game = useAtomValue(gameAtom);
  const { settings, updateSettings } = useSettings();
  const [settingsVisible, setSettingsVisible] = useAtom(settingsVisibleAtom);
  useChatPersistence();
  const { isOnMap, isPopup, chatCorner } = useChatPlacement();
  useKeepAlive();

  const frameless = isOnMap && settings.chatFrameless;
  const chatTop = frameless && chatCorner.startsWith('top');
  const messageBg = frameless && settings.chatMessageBg;
  // Click-through mode: the collapsed chat is a bottom strip, the rest
  // of its rect is free map
  const hoverStrip = frameless && settings.chatHoverStrip;

  // Frameless chat is invisible until the mouse is over it, so the body carries the state.
  // Top-corner chats additionally render the log reversed, so the strip
  // and the expanded chat show the newest message at the corner either way.
  useEffect(() => {
    const body = document.body;
    const clearClasses = () =>
      body.classList.remove(
        'frameless',
        'frameless-visible',
        'chat-message-bg',
        'chat-top',
      );

    setChatStripEdge(chatTop);
    chatRenderer.setReversed(frameless && chatTop);

    if (!frameless) {
      clearClasses();
      chatRenderer.setFrameless(false);
      setChatStripMode(false);
      return;
    }

    body.classList.add('frameless');
    body.classList.toggle('chat-message-bg', !!messageBg);
    body.classList.toggle('chat-top', chatTop);
    chatRenderer.setFrameless(true);
    // Closing a panel or turning frameless on with the mouse over the chat hid it,
    // and no mouseenter comes to show it again. The strip starts collapsed -
    // unless the settings are open inside the chat, which needs to stay
    // visible and clickable until they are closed.
    body.classList.toggle(
      'frameless-visible',
      hoverStrip ? settingsVisible : body.matches(':hover') || settingsVisible,
    );

    const show = () => {
      const wasCollapsed = isChatStripCollapsed();
      if (hoverStrip) {
        cancelChatStripCollapse();
        expandChatFromStrip();
      }
      body.classList.add('frameless-visible');
      // Coming out of the strip means re-sticking to the newest message;
      // a chat that was merely faded (strip mode off) keeps wherever the
      // reader had scrolled to instead of yanking them back down
      if (wasCollapsed) {
        chatRenderer.scrollToBottom();
      }
    };
    const hide = () => {
      if (!settingsVisible) {
        body.classList.remove('frameless-visible');
      }
      if (hoverStrip) {
        scheduleChatStripCollapse();
      }
    };

    body.addEventListener('mouseenter', show);
    body.addEventListener('mouseleave', hide);
    setChatStripMode(hoverStrip);

    return () => {
      body.removeEventListener('mouseenter', show);
      body.removeEventListener('mouseleave', hide);
      setChatStripMode(false);
      clearClasses();
      chatRenderer.setFrameless(false);
      chatRenderer.setReversed(false);
    };
  }, [frameless, messageBg, chatTop, settingsVisible, hoverStrip]);

  // The on-map chat has no titlebar, so its header doubles as one.
  // tgui's Button and Tabs render as divs, so match their classes rather
  // than <button> - anything interactive in the header stays clickable.
  const onHeaderDrag = useCallback((e: React.PointerEvent) => {
    if (
      (e.target as HTMLElement).closest(
        'button, a, input, [role="button"], .Button, .Tab, .Dropdown',
      )
    ) {
      return;
    }
    startChatMove(e);
  }, []);

  return (
    <>
      {isOnMap && (hoverStrip || chatTop) && (
        <div
          className={`ChatHoverStrip${chatTop ? ' ChatHoverStrip--top' : ''}`}
          onMouseEnter={() => {
            cancelChatStripCollapse();
            expandChatFromStrip();
          }}
          onClick={() => {
            cancelChatStripCollapse();
            expandChatFromStrip();
          }}
          onPointerDown={startChatMove}
        >
          <Icon name={chatTop ? 'chevron-down' : 'chevron-up'} />
          <span className="ChatHoverStrip__label">Chat</span>
          <span
            className="ChatHoverStrip__cog"
            onPointerDown={(e) => e.stopPropagation()}
            onClick={(e) => {
              e.stopPropagation();
              cancelChatStripCollapse();
              expandChatFromStrip();
              setSettingsVisible((v) => !v);
            }}
          >
            <Icon name="cog" />
          </span>
          <span className="ChatHoverStrip__ping" />
        </div>
      )}
      <Pane theme={settings.theme} canSuspend={false}>
        {isOnMap && <ResizeHandles corner={chatCorner} />}
        {isPopup && (
          <>
            <ResizeHandles allEdges target="tgui_panel_popup" />
            <div className="PanelDragBar" onPointerDown={startPopupMove} />
          </>
        )}
        <Stack fill vertical className="Panel__stack">
          <Stack.Item>
            <Section fitted className="Panel__header">
              {/* Plain div: Stack only forwards a fixed allowlist of
                  handlers, and onPointerDown is not among them */}
              <div
                onPointerDown={isOnMap ? onHeaderDrag : undefined}
                style={isOnMap ? { cursor: 'grab' } : undefined}
              >
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
                          : 'Hide chat frame'
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
              </div>
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
              <SettingsPanel />
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
    </>
  );
}
