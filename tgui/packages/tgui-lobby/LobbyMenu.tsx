import { type MouseEvent, type ReactNode, useEffect, useRef, useState } from 'react';
import { storage } from 'common/storage';
import { Box, Button, Modal, Section, Stack } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

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
  characterName: string | null;
  preferenceIssues: string[];
  backgroundUrl: string | null;
  videoUrl: string | null;
  previewUrls: Record<string, string> | null;
};

type LobbyTheme = 'blue' | 'green' | 'orange';

const FILTER_STORAGE_KEY = 'lobby-filter-disabled';
const THEME_STORAGE_KEY = 'lobby-theme';
const VIDEO_STORAGE_KEY = 'lobby-video-enabled';

const ANIMATION_DISABLE_MS = 10_000;
const LOAD_SOUND_DELAY_MS = 250;
const PREVIEW_DIRS = ['south', 'east', 'north', 'west'] as const;
const PREVIEW_IMG_RETRIES = 12;
const PREVIEW_IMG_RETRY_MS = 400;

const GAME_PHASE_TEXT: Record<ServerState['gamePhase'], string> = {
  startup: 'Starting up',
  pregame: 'Pre-game',
  setting_up: 'Setting up',
  playing: 'Round in progress',
  postgame: 'Round ended',
};

/** Starfield colors and backdrops per theme, ported from the Horizon site */
const STAR_COLORS: Record<LobbyTheme, [number, number, number]> = {
  green: [166, 255, 190],
  blue: [136, 190, 255],
  orange: [255, 207, 142],
};

const STAR_BACKGROUNDS: Record<LobbyTheme, string> = {
  green: '#040806',
  blue: '#030711',
  orange: '#090704',
};

const STAR_COUNT = 260;
const STAR_DEPTH = 1500;
const STAR_SPEED = 5.5;

function sendAction(action: string, payload?: Record<string, unknown>) {
  Byond.sendMessage('action', { action, ...payload });
}

/** Paints the page backdrop; the browser element behind it is made see-through by the server when needed */
function applyBackdrop(transparent: boolean) {
  const background = transparent ? 'transparent' : '#000';
  document.documentElement.style.setProperty('--lobby-bg', background);
  document.documentElement.style.backgroundColor = background;
  document.body.style.backgroundColor = background;
}

export function LobbyMenu() {
  const [ss, setSs] = useState<ServerState | null>(null);
  const [fadingOut, setFadingOut] = useState(false);
  const [animationsDisabled, setAnimationsDisabled] = useState(false);
  const [theme, setTheme] = useState<LobbyTheme | undefined>();
  const [filterDisabled, setFilterDisabled] = useState<boolean | undefined>();
  const [videoEnabled, setVideoEnabled] = useState(true);
  const [soundsOn, setSoundsOn] = useState(true);
  const [hidden, setHidden] = useState(false);
  const [themeFlash, setThemeFlash] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    Byond.subscribeTo('init', (payload: ServerState) => {
      setSs(payload);
      setFadingOut(false);
      applyBackdrop(!!payload.transparent);
      videoRef.current?.play()?.catch(() => {});
    });

    Byond.subscribeTo('state', (payload: Partial<ServerState>) => {
      setSs((prev) =>
        prev ? { ...prev, ...payload } : (payload as ServerState),
      );
    });

    // The server makes the browser element see-through right after this, so
    // dropping the page backdrop at the same time cross-fades into the game
    Byond.subscribeTo('fadeOut', () => {
      setFadingOut(true);
      applyBackdrop(true);
    });

    Byond.sendMessage('ready');
  }, []);

  useEffect(() => {
    storage.get(FILTER_STORAGE_KEY).then((val) => setFilterDisabled(!!val));
    storage.get(THEME_STORAGE_KEY).then((val) =>
      setTheme(
        val === 'blue' || val === 'green' || val === 'orange'
          ? val
          : 'green',
      ),
    );
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
    videoRef.current?.play()?.catch(() => {});
  }, [ss?.videoUrl, videoEnabled, ss?.transparent]);

  if (!ss || theme === undefined || filterDisabled === undefined) {
    return null;
  }

  // Repaints the theme and blinks the screen the same way the Horizon-Dream
  // site does when swapping phosphor modes
  const pickTheme = (next: LobbyTheme) => {
    playSelectSound();
    setTheme(next);
    storage.set(THEME_STORAGE_KEY, next);
    if (next !== theme) {
      setThemeFlash(true);
      window.setTimeout(() => setThemeFlash(false), 160);
    }
  };

  const crtFilter = !filterDisabled;
  const pregame = ss.gamePhase === 'pregame' || ss.gamePhase === 'startup';
  const typingDelay = (index: number) =>
    animationsDisabled ? '0s' : `${1.5 + index * 0.2}s`;

  return (
    <div
      className={classes([
        'LobbyScreen',
        `LobbyScreen--${theme}`,
        crtFilter && 'filterEnabled',
        animationsDisabled && 'noAnimation',
        fadingOut && 'lobbyFadeOut',
        themeFlash && 'LobbyScreen--themeSwap',
        ss.transparent && 'LobbyScreen--transparent',
      ])}
    >
      {crtFilter &&
        !ss.transparent &&
        !ss.backgroundUrl &&
        !(videoEnabled && ss.videoUrl) && <Starfield theme={theme} />}

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

      {crtFilter && !ss.transparent && (
        <>
          <div className="crt" />
          <div className="crtNoise" />
          <div className="crtVignette" />
        </>
      )}

      <Stack vertical height="100%" justify="space-around" align="center">
        <Stack.Item>
          <div className="brandLockup">
            <svg
              className="brandLockup__logo"
              viewBox="0 0 350 350"
              focusable="false"
            >
              <path d="M230.9 257.5h26.7v20.7h-68.7V71.8h68.7v20.7h-26.7c-7.1 0-12.8 5.7-12.8 12.8v139.5c0 7.1 5.7 12.8 12.8 12.8ZM92.4 71.8v20.7h26.7c7.1 0 12.8 5.7 12.8 12.8v139.5c0 7.1-5.7 12.8-12.8 12.8h-26.7v20.7h68.7V71.8H92.4ZM92.4 188.7v27.6H0v-27.6h92.4ZM257.6 188.7v27.6h92.4v-27.6h-92.4ZM0 133.4v27.9h92.4v-27.9H0ZM257.6 133.4v27.9h92.4v-27.9h-92.4Z" />
            </svg>
            <div className="brandLockup__name">Horizon-Dream</div>
            <div className="brandLockup__sub">// Beyond the station</div>
          </div>
          <Section
            p={3}
            className={classes([
              'sectionLoad',
              'menuCollapsible',
              hidden && 'menuHidden',
            ])}
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

              {!!ss.canReady && (
                <LobbyButton
                  delay={typingDelay(6)}
                  icon={ss.isReady ? 'check' : 'xmark'}
                  selected={ss.isReady}
                  onClick={() => sendAction('ready_toggle')}
                >
                  {ss.isReady ? 'Unready' : 'Ready'}
                </LobbyButton>
              )}

              {!ss.canReady && !!ss.canJoin && (
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
                  onClick={() => {
                    playSelectSound();
                    setHidden(true);
                  }}
                >
                  <span className="styledText">Hide Menu</span>
                </Button>
              </Stack.Item>
            </Stack>
          </Section>
        </Stack.Item>
      </Stack>

      {hidden && (
        <Box
          position="absolute"
          top="10px"
          left="10px"
          className="floating floatingAppear"
        >
          <Button
            icon="check"
            onClick={() => {
              playSelectSound();
              setHidden(false);
            }}
          />
        </Box>
      )}

      <CharacterPreview ss={ss} />

      <StatsPanel ss={ss} pregame={pregame} />

      <PreferenceIssues issues={ss.preferenceIssues} />

      <LobbySettings
        ss={ss}
        filterDisabled={filterDisabled}
        setFilterDisabled={setFilterDisabled}
        theme={theme}
        pickTheme={pickTheme}
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
  onClick?: (e: MouseEvent<HTMLButtonElement>) => void;
  children: ReactNode;
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
          if (disabled) {
            return;
          }
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
  const dir = PREVIEW_DIRS[dirIndex % PREVIEW_DIRS.length];
  const url = urls ? (urls[dir] ?? Object.values(urls)[0]) : null;

  useEffect(() => {
    setImgRetry(0);
  }, [url]);

  if (!urls || !url) {
    return null;
  }

  return (
    <div className="lobby__preview">
      <div className="lobby__panel-title">Character</div>
      <div className="lobby__preview-body">
        <img
          key={`${url}-${imgRetry}`}
          className="lobby__preview-img"
          src={url}
          alt=""
          onError={() => {
            // The asset may still be in transit right after login; remount
            // the img until the file arrives in the client cache
            if (imgRetry < PREVIEW_IMG_RETRIES) {
              setTimeout(
                () => setImgRetry((n) => n + 1),
                PREVIEW_IMG_RETRY_MS,
              );
            }
          }}
        />
      </div>
      <Stack className="lobby__preview-buttons">
        <Stack.Item grow>
          <Button
            fluid
            compact
            icon="rotate"
            onClick={() => {
              playSelectSound();
              setDirIndex((index) => (index + 1) % PREVIEW_DIRS.length);
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
function StatsPanel({ ss, pregame }: { ss: ServerState; pregame: boolean }) {
  return (
    <div className="lobby__stats-holder">
      <div className="lobby__stats">
        <div className="lobby__panel-title">Server</div>
        <StatsRow label="Map" value={ss.mapName} />
        <StatsRow label="Status" value={GAME_PHASE_TEXT[ss.gamePhase]} />
        {pregame ? (
          <StatsRow label="Time left" value={ss.countdown} />
        ) : (
          <StatsRow label="Shift time" value={ss.shiftTime} />
        )}
        <StatsRow label="Players" value={String(ss.playerCount)} />
        <StatsRow label="Ready" value={String(ss.readyCount)} />
        <StatsRow
          label="Admins"
          value={`${ss.adminReadyCount} / ${ss.adminCount}`}
        />
      </div>
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
  theme,
  pickTheme,
  videoEnabled,
  setVideoEnabled,
  soundsOn,
  setSoundsOn,
}: {
  ss: ServerState;
  filterDisabled: boolean;
  setFilterDisabled: (value: boolean) => void;
  theme: LobbyTheme;
  pickTheme: (value: LobbyTheme) => void;
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
              <SettingsRow label="Theme">
                <Button
                  selected={theme === 'blue'}
                  onClick={() => pickTheme('blue')}
                >
                  Blue
                </Button>
                <Button
                  selected={theme === 'green'}
                  onClick={() => pickTheme('green')}
                >
                  Green
                </Button>
                <Button
                  selected={theme === 'orange'}
                  onClick={() => pickTheme('orange')}
                >
                  Orange
                </Button>
              </SettingsRow>

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
  children: ReactNode;
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

/** Warp starfield canvas, ported from the Horizon-Dream site */
function Starfield({ theme }: { theme: LobbyTheme }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) {
      return;
    }
    const ctx = canvas.getContext('2d', { alpha: false });
    if (!ctx) {
      return;
    }

    const [starR, starG, starB] = STAR_COLORS[theme];
    const background = STAR_BACKGROUNDS[theme];
    const reducedMotion = window.matchMedia(
      '(prefers-reduced-motion: reduce)',
    ).matches;

    let width = 0;
    let height = 0;
    let centerX = 0;
    let centerY = 0;
    let raf = 0;

    type Star = { x: number; y: number; z: number; pz: number };
    const stars: Star[] = [];

    const resetStar = (star: Star, initial: boolean) => {
      star.x = (Math.random() - 0.5) * width * 3.5;
      star.y = (Math.random() - 0.5) * height * 3.5;
      star.z = initial ? Math.random() * STAR_DEPTH : STAR_DEPTH;
      star.pz = star.z;
    };

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      width = window.innerWidth;
      height = window.innerHeight;
      canvas.width = Math.round(width * dpr);
      canvas.height = Math.round(height * dpr);
      canvas.style.width = `${width}px`;
      canvas.style.height = `${height}px`;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      centerX = width / 2;
      centerY = height / 2;
    };

    const drawFrame = () => {
      ctx.fillStyle = background;
      ctx.fillRect(0, 0, width, height);
      for (const star of stars) {
        star.pz = star.z;
        star.z -= STAR_SPEED;
        if (star.z < 2) {
          resetStar(star, false);
        }
        const sx = (star.x / star.z) * centerX + centerX;
        const sy = (star.y / star.z) * centerY + centerY;
        const px = (star.x / star.pz) * centerX + centerX;
        const py = (star.y / star.pz) * centerY + centerY;
        const shade = 1 - star.z / STAR_DEPTH;
        ctx.beginPath();
        ctx.moveTo(px, py);
        ctx.lineTo(sx, sy);
        ctx.strokeStyle = `rgba(${starR},${starG},${starB},${shade * 0.8})`;
        ctx.lineWidth = Math.max(0.4, shade * 2);
        ctx.stroke();
      }
      if (!reducedMotion) {
        raf = requestAnimationFrame(drawFrame);
      }
    };

    resize();
    stars.length = 0;
    for (let i = 0; i < STAR_COUNT; i++) {
      const star: Star = { x: 0, y: 0, z: 0, pz: 0 };
      resetStar(star, true);
      stars.push(star);
    }
    drawFrame();

    window.addEventListener('resize', resize);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', resize);
    };
  }, [theme]);

  return <canvas className="crtStars" ref={canvasRef} />;
}
