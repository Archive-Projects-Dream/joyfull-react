// Lobby menu localization (html-lobby-v2)
// Server-side language preference is delivered in the init payload ("language").
// English is the fallback for any missing key.

export type LobbyLanguage = 'english' | 'russian';

const en = {
  welcome: 'Welcome,',
  guest: 'Guest',

  // Menu buttons
  setupCharacter: 'Setup Character',
  gamePreferences: 'Game Preferences',
  crewManifest: 'Crew Manifest',
  changelog: 'Changelog',
  observe: 'Observe',
  ready: 'Ready',
  unready: 'Unready',
  joinGame: 'Join Game',
  polls: 'Polls',
  newPoll: 'New poll!',
  startNow: 'Start Now',
  hideMenu: 'Hide Menu',

  // Stats panel
  statsTitle: 'Server',
  statsServer: 'Server',
  statsMap: 'Map',
  statsStatus: 'Status',
  statsTimeLeft: 'Time left',
  statsShiftTime: 'Shift time',
  statsPlayers: 'Players',
  statsReady: 'Ready',
  statsAdmins: 'Admins',
  statusStartup: 'Starting up',
  statusPregame: 'Pre-game',
  statusSettingUp: 'Setting up',
  statusPlaying: 'Round in progress',
  statusPostgame: 'Round ended',
  delayed: 'DELAYED',
  soon: 'SOON',

  // Character preview
  previewTitle: 'Character',
  rotate: 'Rotate',
  refresh: 'Refresh',

  // Settings popup
  settingsTitle: 'Lobby Settings',
  languageLabel: 'Language',
  crtLabel: 'CRT filter',
  themeLabel: 'CRT theme',
  soundsLabel: 'Interface sounds',
  videoLabel: 'Video background',
  closeLabel: 'Close',
  on: 'On',
  off: 'Off',
} as const;

export type TranslationKey = keyof typeof en;

const ru: Record<TranslationKey, string> = {
  welcome: 'Добро пожаловать,',
  guest: 'Гость',

  setupCharacter: 'Настройка персонажа',
  gamePreferences: 'Игровые настройки',
  crewManifest: 'Манифест экипажа',
  changelog: 'Список изменений',
  observe: 'Наблюдать',
  ready: 'Готов играть',
  unready: 'Отменить готовность',
  joinGame: 'Войти в игру',
  polls: 'Опросы',
  newPoll: 'Новый опрос!',
  startNow: 'Начать сейчас',
  hideMenu: 'Скрыть меню',

  statsTitle: 'Сервер',
  statsServer: 'Сервер',
  statsMap: 'Карта',
  statsStatus: 'Статус',
  statsTimeLeft: 'До старта',
  statsShiftTime: 'Время смены',
  statsPlayers: 'Игроки',
  statsReady: 'Готовы',
  statsAdmins: 'Админы',
  statusStartup: 'Запуск',
  statusPregame: 'До игры',
  statusSettingUp: 'Подготовка',
  statusPlaying: 'Идёт раунд',
  statusPostgame: 'Раунд завершён',
  delayed: 'ЗАДЕРЖКА',
  soon: 'СКОРО',

  previewTitle: 'Персонаж',
  rotate: 'Повернуть',
  refresh: 'Обновить',

  settingsTitle: 'Настройки лобби',
  languageLabel: 'Язык',
  crtLabel: 'CRT-фильтр',
  themeLabel: 'CRT-тема',
  soundsLabel: 'Звуки интерфейса',
  videoLabel: 'Видео-фон',
  closeLabel: 'Закрыть',
  on: 'Вкл',
  off: 'Выкл',
};

const dictionaries: Record<LobbyLanguage, Record<TranslationKey, string>> = {
  english: en,
  russian: ru,
};

export function makeT(language: LobbyLanguage) {
  const dict = dictionaries[language] ?? en;
  return (key: TranslationKey): string => dict[key] ?? en[key];
}

/** "1 player" / "5 players" / "1 игрок" / "5 игроков" */
export function playerCountLabel(
  language: LobbyLanguage,
  count: number,
): string {
  if (language === 'russian') {
    const mod10 = count % 10;
    const mod100 = count % 100;
    let form = 'игроков';
    if (mod10 === 1 && mod100 !== 11) {
      form = 'игрок';
    } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      form = 'игрока';
    }
    return `${count} ${form}`;
  }
  return `${count} player${count !== 1 ? 's' : ''}`;
}
