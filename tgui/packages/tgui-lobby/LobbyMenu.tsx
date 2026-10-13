import { useEffect, useRef, useState } from 'react';
import { classes } from 'tgui-core/react';
import { storage } from 'common/storage';
import {
  Box,
  Button,
  Modal,
  Section,
  Stack,
} from 'tgui-core/components';
import {
  loadSoundsEnabled,
  playLoadSound,
  playSelectSound,
  setSoundsEnabled,
} from './audio';

export type ServerState = {
  gamePhase: 'startup' | 'pregame' | 'setting_up' | 'playing' | 'postgame';
  isReady: boolean;
  canReady: boolean;
  canJoin: boolean;
  canObserve: boolean;
  assetsReady: boolean;
  countdown: string;
  playerCount: number;
  readyCount: number;
  adminReadyCount: number;
  adminCount: number;
  mapName: string;
  shiftTime: string;
  isAdmin: boolean;
  isLocalhost: boolean;
  hasNewPoll: boolean;
  canPoll: boolean;
  transparent: boolean;
  // html-lobby-v2 additions
  characterName: string | null;
  preferenceIssues: string[];
  previewUrls: Record<string, string> | null;
  videoUrl: string | null;
  backgroundUrl: string | null;
  serverName: string | null;
};

function sendAction(action: string, payload?: Record<string, unknown>) {
  Byond.sendMessage('action', { action, ...payload });
}

/** Client-side setting persistence keys (kept from the original lobby) */
const FILTER_STORAGE_KEY = 'lobby-filter-disabled';
const THEME_STORAGE_KEY = 'lobby-theme-disabled';
const VIDEO_STORAGE_KEY = 'lobby-video-enabled';

/** After this long, entry animations stop replaying on re-renders */
const ANIMATION_DISABLE_MS = 10000;

/** Delay before the lobby load jingle, mirrors the original lobby */
const LOAD_SOUND_DELAY_MS = 250;

/** Duration of the fade-back-in animation when the lobby is re-shown */
const LOBBY_FADE_IN_MS = 400;

/** How long to wait before re-asking the server for the character preview */
const PREVIEW_REREQUEST_MS = [2500, 6000] as const;

/** Retries for a preview image whose asset is still in transit */
const PREVIEW_IMG_RETRIES = 12;

/** Delay between preview image retries */
const PREVIEW_IMG_RETRY_MS = 400;

const PREVIEW_DIRS = ['south', 'east', 'north', 'west'] as const;

export function LobbyMenu() {
  const [ss, setSs] = useState<ServerState | null>(null);
  const [fadingOut, setFadingOut] = useState(false);
  const [fadingIn, setFadingIn] = useState(false);
  const [hidden, setHidden] = useState(false);
  const [animationsDisabled, setAnimationsDisabled] = useState(false);
  const [filterDisabled, setFilterDisabled] = useState<boolean | undefined>();
  const [themeDisabled, setThemeDisabled] = useState<boolean | undefined>();
  const [videoEnabled, setVideoEnabled] = useState(true);
  const [soundsOn, setSoundsOn] = useState(true);
  const videoRef = useRef<HTMLVideoElement>(null);
  /** Set once the server has played a fade-out on us (leaving the lobby) */
  const hadFadeOut = useRef(false);
  /** Latest preview urls, read by the delayed re-request timers */
  const previewUrlsRef = useRef<Record<string, string> | null>(null);

  useEffect(() => {
    Byond.subscribeTo('init', (payload: ServerState) => {
      setSs(payload);
      // The lobby browser persists in the skin while the player is in the
      // game, unlike the old setup where it was torn down and recreated.
      // The server re-sends init whenever the lobby is shown again
      // (returning to the lobby, respawning), so undo the fade-out that
      // was applied on leaving - otherwise the finished fade-out animation
      // keeps the whole lobby at opacity 0 and the screen stays black.
      setFadingOut(false);
      setHidden(false);
      // Restore the page backdrop for the current mode - the previous
      // fade-out dropped it so the game could show through the cross-fade.
      const bg = payload.transparent ? 'transparent' : '#000';
      document.documentElement.style.setProperty('--lobby-bg', bg);
      document.documentElement.style.backgroundColor = bg;
      document.body.style.backgroundColor = bg;
      // Coming back from a fade-out (returning to the lobby, respawning) -
      // fade the menu back in instead of popping it into existence.
      if (hadFadeOut.current) {
        hadFadeOut.current = false;
        setFadingIn(true);
        setTimeout(() => setFadingIn(false), LOBBY_FADE_IN_MS + 100);
      }
      // The pane may have been hidden for a long time; nudge the
      // background video to make sure it is still playing.
      videoRef.current?.play()?.catch(() => {});
    });

    Byond.subscribeTo('state', (payload: Partial<ServerState>) => {
      setSs((prev) =>
        prev ? { ...prev, ...payload } : (payload as ServerState),
      );
    });

    // The server hides the browser shortly after this message. Dropping the
    // opaque backdrop at the same time lets the fading lobby cross-fade into
    // the live game view behind the (now see-through) browser element.
    Byond.subscribeTo('fadeOut', () => {
      setFadingOut(true);
      hadFadeOut.current = true;
      document.documentElement.style.setProperty('--lobby-bg', 'transparent');
      document.documentElement.style.backgroundColor = 'transparent';
      document.body.style.backgroundColor = 'transparent';
    });

    // The template-level "ready" fires before React has subscribed, so ask
    // for a fresh state once we are actually mounted. If the character
    // preview is still missing later, ask again - its render may have
    // finished after our first init, or the update got lost in transit
    // (which used to leave the preview blank until a manual reload).
    const reRequestState = () => Byond.sendMessage('ready');
    reRequestState();
    const timers = PREVIEW_REREQUEST_MS.map((delay) =>
      setTimeout(() => {
        if (!previewUrlsRef.current) {
          reRequestState();
        }
      }, delay),
    );

    return () => timers.forEach((timer) => clearTimeout(timer));
  }, []);

  useEffect(() => {
    storage
      .get(FILTER_STORAGE_KEY)
      .then((val) => setFilterDisabled(!!val));

    storage.get(THEME_STORAGE_KEY).then((val) => setThemeDisabled(!!val));

    storage.get(VIDEO_STORAGE_KEY).then((val) => {
      setVideoEnabled(val === undefined || val === null ? true : !!val);
    });

    loadSoundsEnabled().then((enabled) => {
      setSoundsOn(enabled);
      if (enabled) {
        setTimeout(() => playLoadSound(), LOAD_SOUND_DELAY_MS);
      }
    });

    const timer = setTimeout(
      () => setAnimationsDisabled(true),
      ANIMATION_DISABLE_MS,
    );
    return () => clearTimeout(timer);
  }, []);

  useEffect(() => {
    const bg = ss?.transparent ? 'transparent' : '#000';
    document.documentElement.style.setProperty('--lobby-bg', bg);
    document.documentElement.style.backgroundColor = bg;
    document.body.style.backgroundColor = bg;
  }, [ss?.transparent]);

  // Track the latest preview urls for the delayed re-request timers above
  useEffect(() => {
    previewUrlsRef.current = ss?.previewUrls ?? null;
  }, [ss?.previewUrls]);

  // (Re)start playback whenever the video element (re)mounts or its
  // source changes - autoplay attributes alone are not reliable for that.
  useEffect(() => {
    videoRef.current?.play()?.catch(() => {});
  }, [ss?.videoUrl, videoEnabled, ss?.transparent]);

  if (!ss || themeDisabled === undefined || filterDisabled === undefined) {
    return null;
  }

  const crtTheme = !themeDisabled;
  const crtFilter = crtTheme && !filterDisabled;
  const pregame = ss.gamePhase === 'pregame' || ss.gamePhase === 'startup';
  const typingDelay = (index: number) =>
    animationsDisabled ? '0s' : `${1.5 + index * 0.2}s`;

  return (
    <div
      className={classes([
        'LobbyScreen',
        crtTheme ? 'LobbyScreen--crt' : 'LobbyScreen--plain',
        crtTheme && 'crtTheme',
        crtFilter && 'filterEnabled',
        animationsDisabled && 'noAnimation',
        fadingOut && 'lobbyFadeOut',
        fadingIn && 'lobbyFadeIn',
        ss.transparent && 'LobbyScreen--transparent',
      ])}
    >
      {!ss.transparent && ss.backgroundUrl && (
        <div
          className="bgBackground bgLoad"
          style={{ backgroundImage: `url(${ss.backgroundUrl})` }}
        />
      )}

      {!ss.transparent && videoEnabled && ss.videoUrl && (
        <video
          ref={videoRef}
          className="bgVideo"
          src={ss.videoUrl}
          autoPlay
          loop
          muted
          playsInline
        />
      )}

      {crtFilter && !ss.transparent && <div className="crt" />}

      {hidden && (
        <Box position="absolute" top="10px" left="10px" className="floating">
          <Button icon="check" onClick={() => setHidden(false)} />
        </Box>
      )}

      <Stack vertical height="100%" justify="space-around" align="center">
        <Stack.Item>
          <Section
            p={3}
            className="sectionLoad"
            style={{ opacity: hidden ? '0' : '1' }}
          >
            <Stack vertical>
              <Stack.Item>
                <Stack vertical align="center" className="welcomeHolder">
                  <Stack.Item>
                    <Box className="typeEffect styledText">Welcome,</Box>
                  </Stack.Item>
                  <Stack.Item>
                    <Box
                      className="typeEffect styledText"
                      style={{ animationDelay: '1.4s' }}
                    >
                      {ss.characterName || 'Guest'}
                    </Box>
                  </Stack.Item>
                </Stack>
              </Stack.Item>

              <Stack.Item>
                <div className="dividerEffect" />
              </Stack.Item>

              <LobbyButton
                delay={typingDelay(1)}
                icon="file-lines"
                disabled={!ss.assetsReady}
                onClick={() => sendAction('character_setup')}
              >
                Setup Character
              </LobbyButton>

              <LobbyButton
                delay={typingDelay(2)}
                icon="gear"
                disabled={!ss.assetsReady}
                onClick={() => sendAction('settings')}
              >
                Game Preferences
              </LobbyButton>

              <LobbyButton
                delay={typingDelay(3)}
                icon="check-to-slot"
                onClick={() => sendAction('crew_manifest')}
              >
                Crew Manifest
              </LobbyButton>

              <LobbyButton
                delay={typingDelay(4)}
                icon="list-ul"
                onClick={() => sendAction('changelog')}
              >
                Changelog
              </LobbyButton>

              <Stack.Item>
                <div className="dividerEffect" />
              </Stack.Item>

              <LobbyButton
                delay={typingDelay(5)}
                icon="eye"
                disabled={!ss.canObserve}
                onClick={() => sendAction('observe')}
              >
                Observe
              </LobbyButton>

              {ss.canReady && (
                <LobbyButton
                  delay={typingDelay(6)}
                  icon={ss.isReady ? 'check' : 'xmark'}
                  selected={ss.isReady}
                  onClick={() => sendAction('ready_toggle')}
                >
                  {ss.isReady ? 'Unready' : 'Ready'}
                </LobbyButton>
              )}

              {!ss.canReady && ss.canJoin && (
                <LobbyButton
                  delay={typingDelay(6)}
                  icon="users"
                  onClick={() => sendAction('join')}
                >
                  Join Game
                </LobbyButton>
              )}

              {!!ss.canPoll && (
                <LobbyButton
                  delay={typingDelay(7)}
                  icon="clipboard-list"
                  badge={ss.hasNewPoll ? 'New poll!' : null}
                  onClick={() => sendAction('poll')}
                >
                  Polls
                </LobbyButton>
              )}

              {!!ss.isLocalhost && (
                <LobbyButton
                  delay={typingDelay(8)}
                  icon="forward"
                  onClick={() => sendAction('start_now')}
                >
                  Start Now
                </LobbyButton>
              )}

              <Stack.Item>
                <Button
                  fluid
                  className="hideButton"
                  icon="eye-slash"
                  onClick={() => setHidden(true)}
                >
                  <span className="styledText">Hide Menu</span>
                </Button>
              </Stack.Item>
            </Stack>
          </Section>
        </Stack.Item>
      </Stack>

      <CharacterPreview ss={ss} />

      <StatsPanel ss={ss} pregame={pregame} />

      <PreferenceIssues issues={ss.preferenceIssues} />

      <LobbySettings
        ss={ss}
        filterDisabled={filterDisabled}
        setFilterDisabled={setFilterDisabled}
        themeDisabled={themeDisabled}
        setThemeDisabled={setThemeDisabled}
        videoEnabled={videoEnabled}
        setVideoEnabled={setVideoEnabled}
        soundsOn={soundsOn}
        setSoundsOn={setSoundsOn}
      />
    </div>
  );
}

function LobbyButton(props: {
  delay: string;
  icon?: string;
  selected?: boolean;
  disabled?: boolean;
  badge?: string | null;
  onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
  children: React.ReactNode;
}) {
  const { delay, icon, selected, disabled, badge, onClick, children } = props;
  return (
    <Stack.Item className="buttonEffect" style={{ animationDelay: delay }}>
      <Button
        fluid
        className="distinctButton"
        icon={icon}
        selected={selected}
        disabled={disabled}
        onClick={(e) => {
          if (disabled) return;
          playSelectSound();
          onClick?.(e);
        }}
      >
        <span className="styledText">{children}</span>
        {!!badge && <span className="badgeNotification">{badge}</span>}
      </Button>
    </Stack.Item>
  );
}

/** Character preview with client-side direction cycling */
function CharacterPreview({ ss }: { ss: ServerState }) {
  const [dirIndex, setDirIndex] = useState(0);
  const [imgRetry, setImgRetry] = useState(0);

  const urls = ss.previewUrls;
  const dir = PREVIEW_DIRS[dirIndex];
  const url = urls ? (urls[dir] ?? Object.values(urls)[0]) : null;

  // A new set of urls resets the retry counter
  useEffect(() => {
    setImgRetry(0);
  }, [url]);

  if (!urls) {
    return null;
  }

  return (
    <div className="lobby__preview">
      <div className="lobby__panel-title">Character</div>
      <div className="lobby__preview-body">
        {url && (
          <img
            key={`${url}-${imgRetry}`}
            className="lobby__preview-img"
            src={url}
            alt=""
            onError={() => {
              // The asset can still be in transit right after login; a
              // failed load never retries on its own, so remount the img
              // until the file arrives in the client cache.
              if (imgRetry < PREVIEW_IMG_RETRIES) {
                setTimeout(
                  () => setImgRetry((n) => n + 1),
                  PREVIEW_IMG_RETRY_MS,
                );
              }
            }}
          />
        )}
      </div>
      <Stack className="lobby__preview-buttons">
        <Stack.Item grow>
          <Button
            fluid
            compact
            icon="rotate"
            onClick={() => {
              playSelectSound();
              setDirIndex((dirIndex + 1) % PREVIEW_DIRS.length);
            }}
          >
            Rotate
          </Button>
        </Stack.Item>
        <Stack.Item grow>
          <Button
            fluid
            compact
            icon="arrows-rotate"
            onClick={() => {
              playSelectSound();
              sendAction('refresh_preview');
            }}
          >
            Refresh
          </Button>
        </Stack.Item>
      </Stack>
    </div>
  );
}

function StatsRow({ label, value }: { label: string; value: string | null }) {
  return (
    <div className="lobby__stats-row">
      <span className="lobby__stats-label">{label}</span>
      <span className="lobby__stats-value">{value || '—'}</span>
    </div>
  );
}

/** Round/server statistics panel on the right edge */
function StatsPanel({
  ss,
  pregame,
}: {
  ss: ServerState;
  pregame: boolean;
}) {
  const statusText = {
    startup: 'Starting up',
    pregame: 'Pre-game',
    setting_up: 'Setting up',
    playing: 'Round in progress',
    postgame: 'Round ended',
  }[ss.gamePhase];
  return (
    <div className="lobby__stats">
      <div className="lobby__panel-title">Server</div>
      <StatsRow label="Server" value={ss.serverName} />
      <StatsRow label="Map" value={ss.mapName} />
      <StatsRow label="Status" value={statusText} />
      {pregame ? (
        <StatsRow label="Time left" value={ss.countdown} />
      ) : (
        <StatsRow label="Shift time" value={ss.shiftTime} />
      )}
      <StatsRow
        label="Players"
        value={`${ss.playerCount} player${ss.playerCount !== 1 ? 's' : ''}`}
      />
      <StatsRow label="Ready" value={String(ss.readyCount)} />
      <StatsRow
        label="Admins"
        value={`${ss.adminReadyCount} / ${ss.adminCount}`}
      />
    </div>
  );
}

/** CM13-style warnings about the player's current preferences */
function PreferenceIssues({ issues }: { issues: string[] }) {
  if (!issues || issues.length === 0) {
    return null;
  }
  return (
    <div className="messageHolder">
      <Stack vertical justify="flex-end" fill>
        {issues.map((issue, index) => (
          <Section key={index} className="sectionLoad issueSection">
            <Box className="issueText">{issue}</Box>
          </Section>
        ))}
      </Stack>
    </div>
  );
}

/** Settings button (bottom right) and its popup */
function LobbySettings({
  ss,
  filterDisabled,
  setFilterDisabled,
  themeDisabled,
  setThemeDisabled,
  videoEnabled,
  setVideoEnabled,
  soundsOn,
  setSoundsOn,
}: {
  ss: ServerState;
  filterDisabled: boolean;
  setFilterDisabled: (value: boolean) => void;
  themeDisabled: boolean;
  setThemeDisabled: (value: boolean) => void;
  videoEnabled: boolean;
  setVideoEnabled: (value: boolean) => void;
  soundsOn: boolean;
  setSoundsOn: (value: boolean) => void;
}) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <Box
        position="absolute"
        bottom="10px"
        right="10px"
        className="settingsHolder"
      >
        <Button
          icon="cog"
          onClick={() => {
            playSelectSound();
            setOpen(true);
          }}
        />
      </Box>

      {open && (
        <Modal>
          <Section
            p={3}
            className="settingsModal"
            title="Lobby Settings"
            buttons={
              <Button
                icon="xmark"
                onClick={() => {
                  playSelectSound();
                  setOpen(false);
                }}
              />
            }
          >
            <Stack vertical>
              <SettingsRow label="CRT filter">
                <Button
                  selected={!filterDisabled}
                  onClick={() => {
                    playSelectSound();
                    const next = !filterDisabled;
                    setFilterDisabled(next);
                    storage.set(FILTER_STORAGE_KEY, next);
                  }}
                >
                  {filterDisabled ? 'Off' : 'On'}
                </Button>
              </SettingsRow>

              <SettingsRow label="CRT theme">
                <Button
                  selected={!themeDisabled}
                  onClick={() => {
                    playSelectSound();
                    const next = !themeDisabled;
                    setThemeDisabled(next);
                    storage.set(THEME_STORAGE_KEY, next);
                  }}
                >
                  {themeDisabled ? 'Off' : 'On'}
                </Button>
              </SettingsRow>

              <SettingsRow label="Interface sounds">
                <Button
                  selected={soundsOn}
                  onClick={() => {
                    const next = !soundsOn;
                    setSoundsEnabled(next);
                    setSoundsOn(next);
                    if (next) {
                      playSelectSound();
                    }
                  }}
                >
                  {soundsOn ? 'On' : 'Off'}
                </Button>
              </SettingsRow>

              {!!ss.videoUrl && (
                <SettingsRow label="Video background">
                  <Button
                    selected={videoEnabled}
                    onClick={() => {
                      playSelectSound();
                      const next = !videoEnabled;
                      setVideoEnabled(next);
                      storage.set(VIDEO_STORAGE_KEY, next);
                    }}
                  >
                    {videoEnabled ? 'On' : 'Off'}
                  </Button>
                </SettingsRow>
              )}

              <Stack.Item>
                <Button
                  fluid
                  onClick={() => {
                    playSelectSound();
                    setOpen(false);
                  }}
                >
                  Close
                </Button>
              </Stack.Item>
            </Stack>
          </Section>
        </Modal>
      )}
    </>
  );
}

function SettingsRow({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <Stack.Item>
      <Stack justify="space-between" align="center">
        <Stack.Item className="settingsLabel">{label}</Stack.Item>
        <Stack.Item>
          <Stack>{children}</Stack>
        </Stack.Item>
      </Stack>
    </Stack.Item>
  );
}
