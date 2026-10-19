# HANDOFF — joyfull-react / html-lobby (для будущих агентов)

Дистилляция ~30 задач по HTML-лобби tgstation-форка. Детали по каждой
задаче — в `worklog.md` песочницы агентов (читать его ПЕРЕД работой —
протокол обязателен). Эта репо-копия (ветка `docs/handoff`) без секрета:
PAT для пуша выдаёт владелец / полный вариант файла — в песочнице агентов.
Здесь — только то, что не очевидно из кода.

## 1. Репо и доступ

- Репо: `Archive-Projects-Dream/joyfull-react`, рабочая ветка `html-lobby`
  (111+ коммитов поверх master; master уже содержит раннюю версию лобби).
- PAT (push): `https://<PAT-не-коммитим-в-историю>@github.com/Archive-Projects-Dream/joyfull-react.git`
- **Пушу ВСЕГДА предшествует `git fetch origin` + `ls-remote`**: ремоут мог
  переписать бот синхронизации или владелец сжал коммиты (ловушка task31 —
  history rewrite; ловушка task33 — коммиты task31+task32 оказались сжаты
  владельцем в e5797583 «tweak: Видео без фоновой картинки» поверх
  920434de67). При расхождении свои коммиты переносить заново поверх
  нового tip.
- Локальный клон агентов: `/home/z/my-project/repo-joyfull` (клон может
  пропадать при сбросе песочницы — переклонировать по PAT, свежесть
  проверять fetch'ем).

## 2. Сборка

- tgui: `cd tgui && bun install --frozen-lockfile && bun run tgui:tsc
  && bun run tgui:build` (rspack; tgui-lobby ≈ 317 KiB js + 30.1 KiB css).
- **Бандлы в gitignore** (`tgui/.gitignore: /public/**`) — коммитится только
  исходник. DM читает `tgui/public/tgui-lobby.bundle.{css,js}` через
  `inline_css/inline_js` в `create_window()` — файлы должны существовать
  на диске сервера (собираются при деплое, Dockerfile/BUILD.cmd).
- DM-компилятор (DreamMaker 516.1687) в песочнице НЕ персистентен —
  `which dm` пуст после сброса. Прошлые логи: `scripts/dm_compile*.log`
  (tgstation.dme, ~4 мин, «0 errors»). Стандартный путь — `BUILD.cmd`.
- Песочница сбрасывается между сообщениями: bun пропадает, node_modules
  иногда пропадает → переустановить `--frozen-lockfile`. Выживают:
  `repo-joyfull/`, `scripts/`, `download/`, `worklog.md`.

## 3. Карта кода

- `tgui/packages/tgui-lobby/LobbyMenu.tsx` (~1045 строк) — всё лобби:
  стейт, шина Byond, настройки, BgImage/BgVideo.
- `tgui/packages/tgui-lobby/styles/main.scss` — темы
  `.LobbyScreen--{blue,green,orange}` (по 22 CSS-константы), анимации
  `bgLoad` (5с delay + 10с fade), `bgSwap` (0.8s), `--return` (0.8с + 4с);
  масштабирование `zoom: var(--lobby-scale)` — медиа-блок **в конце файла**.
- `tgui/packages/tgui-lobby/scaling.ts` — `--lobby-scale`
  (REFERENCE 880x640, уменьшение только если не помещается).
- `code/modules/lobby_menu/lobby_menu.dm` (602 строки) — DM-сторона:
  `send_init()` (полный payload в ответ на client 'ready'), `send_update()`
  (частичные тики), `get_lobby_{background,video}_url()` (flist из
  `config/lobby_art/`: png/jpg/jpeg → картинка, webm/mp4 → видео),
  `create_window()` (browser element, inline bundles).
- Протокол: `init` / `state` (Partial) / `fadeOut` / `ready` (client→DM).

## 4. Ловушки (проверено кровью)

1. **DM-булевы приходят как 0/1** → `{value && ...}` рендерит «0».
   Гейт всегда `!!value`.
2. **Каскад**: блок равной специфичности побеждает только стоящий В КОНЦЕ
   main.scss (ловушка `max-width:30vw` vs медиа-переопределение).
3. **`zoom`, не `transform`**: transform создаёт stacking-контекст и
   containing-block для fixed — фоны/видео/CRT уезжают. zoom инертен
   для full-bleed слоёв.
4. **Класс анимации — снимок на монтирование** (`useState(reveal)` в
   BgImage/BgVideo): менять класс смонтированного элемента нельзя —
   state-тики ререндерят каждую секунду и перезапускают анимацию.
   Новая инстанция берёт свежий reveal.
5. **`bgSwap` — только осознанные переключения** (task32, флаг
   `userSwapped` поднимают хендлеры тумблеров, returning сбрасывает).
   Никогда не выводить «загрузка vs свап» из порядка сообщений:
   персистед-настройки в проде резолвятся ПОСЛЕ init (common/storage
   включает byondstorage через winset + ждёт `byondstorageupdated`).
   Любое первое появление фона = `bgLoad`.
6. **Видео и картинка взаимоисключающие** (task31):
   `bgVideoUrl = videoOn && ss.videoUrl; bgImageUrl = ... && !bgVideoUrl`.
7. **Порядок хуков** одинаков до/после null-гейта рендера; масштабирование
   через `useLayoutEffect` (до первой отрисовки — окно не вспыхивает).
8. `previewUrls` — Record по 4 направлениям; ретраисы PREVIEW_IMG_RETRIES.

## 5. Тестирование (headless-стенд)

Паттерн: `scripts/taskNN/harness.html` — реплика шины Byond из
tgui-setup/helpers.js (обрезанная) + `window.hubStorage` (без него storage
виснет вечно, react-root пуст!) + `__emit/__initPayload/__sent/__log`.
Бандлы рядом + `python3 -m http.server 8380` (проверить порт: `ss -tlnp`,
убить чужой процесс — корень мог быть другой!).

- task32-харнесс умеет: `?delay=N` (асинхронный hubStorage — продовый
  порядок init→storage), `?seedVideo/?seedBg` (сидинг до загрузки бандла),
  `?ai=N&bg=1&vid=1&ret=1` (авто-init), `?t=N` (cache-bust).
- **Кэш**: http.server без cache-control → `?v=` на бандлах + `?t=` на
  странице, иначе браузер таскает старый бандл (ложные фейлы).
- **localStorage общий на origin** — стейл-сид прошлого теста ломает
  следующий; сидить явно каждый сценарий.
- agent-browser: `set viewport` → `open` → `wait` → `eval` → `screenshot`.
  **tgui Button = `div.Button`, не `button`!** Тумблеры: найти
  `.settingsLabel` с текстом → `parentElement.querySelector('.Button')`.
  Шестерёнка: `.settingsHolder i.fa-cog` → `.closest('.Button')`.
- После `reload` init слать заново.
- **Шина искажает eval-вывод** («800» вместо 788, «const idden») —
  критичные числа перепроверять повторными замерами.
- **CLI-оверхед сдвигает метки времени** — верить числам анимации
  (opacity = f(время от монтирования)), не своим wait'ам.
- A/B картинок: PIL `ImageStat` по яркости скринов (74.6 vs 15.2 —
  железное доказательство). VLM слеп на тёмных мелких панелях — кропы
  углов ×3 или числа rect.

## 6. Открытые хвосты

- **Рантаймы при плохом интернете** (не начато): preferences.dm:238
  `null.assigned_map`, :176 `null.display to()`, tgui_window.dm:114
  `bad client`, tgui.dm:270 `null.prefs`, client_procs.dm:624
  `Del()'d без persistent_client`; кейс игрока Tetoholic (реконнект-шторм).
- **Открытие PR** — описание готово: `download/task29/pr_description.md`
  (дополнено пунктом о взаимоисключении в task31). Открывает пользователь.
- Коммит-стиль: `FEAT:/FIX:` + русское тело с мотивацией «почему».

## 7. Протокол worklog

Каждая задача: читать `worklog.md` → работать → дописать секцию
(`---` + `Task ID: N` + Agent + Task + Work Log + Stage Summary).
Артефакты: `scripts/taskNN/` (стенд), `download/taskNN/` (пользовательское).
