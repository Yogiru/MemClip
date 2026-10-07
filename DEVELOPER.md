# MemClip — руководство разработчика

Утилита «3 в 1» для Windows: очистка оперативной памяти (на базе MemCleaner) +
история буфера обмена (идея CLCL) + захват текста с элементов интерфейса
(идея Textify). Однофайловый проект на Free Pascal, чистый WinAPI, без LCL.

## Сборка

- Компилятор: Free Pascal 3.2.2 (`C:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe`)
- Цель: Win32/i386, GUI-приложение (`-WG` в build.cmd — без консоли)
- Команда: `build.cmd` → `MemClip.exe` (~340 КБ)
- Ресурсы: `MemClip.rc` → `MemClip.res` через `fpcres` (иконка + манифест
  с `requireAdministrator` — программа всегда запускается от админа)

## Структура проекта

| Файл | Назначение |
|---|---|
| `MemClip.pas` | Весь код (~3280 строк) |
| `MemClip.rc` / `MemClip.res` | Ресурсы: иконка, манифест |
| `MemClip.manifest` | Манифест: `requireAdministrator`, темы |
| `build.cmd` | Сборка ресурса + компиляция |
| `MemClip.dat` | Сохранённая история буфера (создаётся рядом с exe) |
| `MemClip.ini` | Настройки горячих клавиш |

## Архитектура

Однопоточная модель с двумя фоновыми потоками:

```
Main thread  — главное невидимое окно 'MemClipMain': трей-иконка, хоткеи,
               все диалоги, захват текста, доступ к буферу обмена, COM
CleanupThread — поток автоочистки памяти (WaitForSingleObject на hEvent)
MouseHookThread — поток с WH_MOUSE_LL хуком (Ctrl+средний клик)
```

Потоки общаются с главным окном только через `PostMessage` —
никакой синхронизации с GUI нет.

### Классы окон

| Класс | Назначение |
|---|---|
| `MemClipMain` | Скрытое главное окно: WndProc на всё |
| `MemClipPopup` | Информационные тултипы (результат очистки, «скопировано») |
| `MemClipGrab` | Модальный диалог захваченного текста (Edit + кнопки) |
| `MemClipHotkey` | Модальный диалог захвата нового сочетания клавиш |
| `MemClipViewer` | Окно истории: поиск + owner-drawn listbox + кнопки |
| `MemClipSnip` | Полноэкранный layered-оверлей выделения области (скриншоты) |

Первые два класса — ANSI (`RegisterClass`), диалоги и viewer — Unicode
(`RegisterClassW`), чтобы заголовки/текст были всегда в Unicode.

### Пользовательские сообщения

| Сообщение | Источник → Назначение |
|---|---|
| `WM_CLEANUP_DONE` (WM_USER+2) | CleanupThread → главное окно (free before/after в wParam/lParam) |
| `WM_GRAB_CLICK` (WM_USER+3) | MouseHookThread → главное окно; wParam: 1=текст (Ctrl+MMB), 2=URL (Ctrl+Alt+MMB), 3=OCR (Alt+MMB) |
| `VIEW_REFRESH` (WM_APP+5) | главное окно → `MemClipViewer`: пересобрать список при изменении истории |
| `WM_OCRIDX_DONE` (WM_APP+6) | OcrIdxThread → главное окно; lParam = `POcrIdxJob` (текст OCR для записи истории) |
| `WM_UPDATE_DONE` (WM_APP+7) | UpdThread → главное окно; lParam = `PUpdJob` (результат проверки обновлений) |
| `TaskbarCreated` | Пересоздание трей-иконки после рестарта Explorer |

### Таймеры

| Таймер | Период | Назначение |
|---|---|---|
| `TIMER_CLIPCAPTURE` | 300 мс, one-shot | Отложенный захват буфера после `WM_CLIPBOARDUPDATE` — пока источник не закроет буфер |
| `TIMER_HISTSAVE` | 5 с, one-shot | Отложенная запись `MemClip.dat` после изменения истории |
| `TIMER_MEMSTAT` | 4 с | `MemStatTick`: тултип «занято % — свободно МБ» + автоочистка по порогу `mem_free_min_mb` (анти-дребезг: не чаще 60 с, `LastAutoClean`) |
| `TIMER_EXIT` | — | Отложенный `PostQuitMessage` (корректный выход из трея) |

## Модуль очистки памяти

Перенесён из MemCleaner без изменений.

- `CleanupThread`: `WaitForSingleObject(hEvent, CurrentInterval)` — цикл;
  ручной запуск `SetEvent(hEvent)`, выход — `Exiting` + `SetEvent`.
- `DoClean`: `GlobalMemoryStatusEx` → `EmptyWorkingSet` по всем процессам
  (`EnumProcesses`, `OpenProcess`) → standby-списки и файловый кеш через
  `NtSetSystemInformation` (SystemMemoryListInformation / SystemFileCacheInformation).
- `PROCESSES_LOOP_DELAY` — пауза между батчами процессов.

### Очистка кэша иконок и миниатюр (`ClearShellCache`)

- `GetShellWindow` → PID Explorer'а → `OpenProcessToken` →
  `DuplicateTokenEx` (primary token) → `GetUserProfileDirectoryW` —
  профиль берётся у токена shell'а, а не из нашего окружения (иначе при
  элевации под другим админом чистился бы чужой профиль).
- `ClearShellCache` — один пункт меню чистит оба кэша: иконки
  (`iconcache*.db` + `IconCache.db`) и миниатюры (`thumbcache*.db`),
  `DeleteBoth` суммирует ошибки `DeleteShellCache`.
  `DeleteCacheGlob`/`DeleteShellCache` удаляют файлы по маске в
  `AppData\Local\Microsoft\Windows\Explorer`.
- Файлы залочены работающим Explorer'ом → `TerminateProcess` → удаление →
  `CreateProcessAsUserW` с токеном shell'а: новый Explorer стартует
  **неэлеваированным** под интерактивным пользователем.
- После рестарта Explorer шлёт broadcast `TaskbarCreated` — трей-иконка
  пересоздаётся автоматически (уже обрабатывается в `MainWndProc`).

## Модуль истории буфера

### Модель данных

```pascal
TClipFmt = record
  Fmt: UINT;        // id формата (стандартный или зарегистрированный)
  FmtName: string;  // имя для зарегистрированных форматов (id меняется между сессиями!)
  Data: TBytes;
end;
TClipEntry = record
  Kind: TClipKind;        // ckText | ckImage | ckFiles — только для подписи в меню
  Text: WideString;       // текст записи / подпись
  OcrText: WideString;    // OCR-индекс картинки (только в памяти — поиск в viewer'е)
  ImgW, ImgH: Integer;    // размеры картинки (парсятся из BITMAPINFOHEADER DIB)
  Pinned: Boolean;        // закреплённая запись — не вытесняется
  Time: QWord;            // GetTickCount64 захвата — для склейки копий
  StampUtc: TFileTime;    // UTC-время захвата — метаданные в viewer'е и MCL4
  Owner: WideString;      // exe-имя процесса-источника (ClipOwnerProcName)
  Fmts: array of TClipFmt;// ВСЕ полезные форматы записи одновременно
end;
```

Ключевая идея (как в CLCL): **запись = набор форматов**, а не один формат.
Если источник положил картинку + текст + HTML — сохраняется всё, при вставке
возвращается всё, целевая программа сама выбирает лучший формат.

### Закреплённые записи и склейка

`ClipHistory` разделён на две зоны: `[0 .. CountPinned-1]` — pinned
(инвариант: все pinned в голове массива), дальше — обычные.

- `ClipAdd` вставляет новые записи на позицию `p = CountPinned`;
  дубликат из pinned-зоны не двигается; вытеснение — только из хвоста,
  пока `Length - CountPinned > CLIP_HISTORY_MAX` (общий потолок
  `CLIP_HISTORY_TOTAL_MAX = 256` на случай большого числа pinned).
- `TogglePin` — закрепить (в конец pinned-зоны) / открепить
  (в голову обычной зоны); вызывается Shift+кликом в меню и кнопкой
  в окне истории.
- Склейка (`ClipMergeEnabled`, `CLIP_MERGE_MS = 15 с`): если верхняя
  обычная запись — текст и копия свежая, текст дописывается через
  `#13#10`, `EntrySetTextFmt` пересобирает `CF_UNICODETEXT`.

### Захватываемые форматы

- Стандартные: `CF_UNICODETEXT`, `CF_DIB`, `CF_DIBV5`, `CF_ENHMETAFILE`, `CF_HDROP`
- Зарегистрированные (`REGFMT_NAMES`): `PNG`, `JFIF`, `GIF`, `image/png`,
  `HTML Format`, `Rich Text Format`
- Лимиты: `CLIP_HISTORY_MAX = 30` обычных записей (pinned не считаются),
  `CLIP_MAX_BYTES = 8 МБ` на формат
- Фильтры CLCL: игнорируются форматы `ExcludeClipboardContentFromMonitorProcessing`,
  `Clipboard Viewer Ignore`, `CanIncludeInClipboardHistory=0` — пароли из
  менеджеров паролей не попадают в историю
- Исключения по процессам: `ClipOwnerProcExcluded` — `GetClipboardOwner`
  (или foreground-окно) → `QueryFullProcessImageNameW` → имя exe сравнивается
  со списком `[clipboard] exclude` из `MemClip.ini` (`;`-разделённый,
  lowercase)

### Конвейер

```
WM_CLIPBOARDUPDATE → TIMER_CLIPCAPTURE (300 мс) → CaptureClipboard
  → ClipOwnerProcExcluded (exe в [clipboard] exclude → пропуск)
  → OpenClipRetry (5 попыток × 40 мс — источник может ещё держать буфер)
  → EnumClipboardFormats → AddClipboardFmt для каждого нужного формата
  → дедуп (SameClipEntry → подъём наверх) → ClipAdd → TIMER_HISTSAVE (5 с)
```

### Миниатюры в меню истории

- `BuildClipMenu(menu, thumbs)` — общий построитель меню для левого клика
  (`ShowClipHistoryMenu`) и подменю в настройках (`ShowTrayMenu`);
  убирает дублирование и вешает `MIIM_BITMAP`/`hbmpItem` на записи-картинки.
- `EntryThumbHbm`: PNG/JFIF/GIF/image/png → напрямую в GDI+;
  `CF_DIB`/`CF_DIBV5` → `DibToBmpFile` → GDI+ → `GdipCreateHBITMAPFromBitmap`
  → `ScaleToThumb` (StretchBlt, aspect-fit в `THUMB_SIZE=32`).
- Созданные HBITMAP'ы живут в `TList` до закрытия меню — `FreeThumbs`
  удаляет их после `TrackPopupMenu`/`DestroyMenu`.

### Восстановление (`RestoreClipEntry`)

- Текст: `CF_UNICODETEXT` через `GlobalAlloc`+`SetClipboardData`
- DIB/DIBV5: как есть
- `CF_ENHMETAFILE`: `SetEnhMetaFileBits`
- `CF_HDROP`: собирается структура `DROPFILES` (учесть: имена файлов хранятся
  в `Text` записи, разделённые `|` → при восстановлении собирается заново)
- Если картинка есть без PNG → синтез PNG через GDI+:
  `DIB → BITMAP → GdipCreateHBITMAPFromBitmap → GdipSaveImageToStream`
  (нужен для браузеров/мессенджеров, которые не берут DIB)
- Запись-«файл» с одним изображением → дополнительно `CF_BITMAP` + PNG
  (файл-картинка из Проводника вставляется в Paint как изображение)

### Персистентность — `MemClip.dat`

```
'MCL4' | DWORD version=4 | DWORD count
  per entry: Byte Kind | Byte flags (bit0 = Pinned)
             FILETIME StampUtc (8 байт, UTC) | DWORD len + UTF8 Owner
             DWORD len + UTF8 Text
             DWORD fmtCount
               per fmt: DWORD Fmt | DWORD len + UTF8 FmtName | DWORD len + Data
```

Загрузчик принимает `MCL2` (без flags/метаданных) и `MCL3` (с flags,
без метаданных) — для них `StampUtc=0`, `Owner=''`. Размер истории —
`ClipHistoryMax` (`[clipboard] max=`, 5–256, дефолт 30), закреплённые
записи не в счёт. Имена форматов сохраняются и перерегистрируются при
загрузке — id зарегистрированных форматов нестабильны между сессиями.

### Окно истории (`ShowClipViewer`, класс `MemClipViewer`)

- Открывается `Ctrl+Alt+V` (`HOTKEY_CLIPMENU`) и пунктом «Окно истории»
  из меню истории; левый клик по трею по-прежнему даёт компактное меню.
- Edit (`IDC_VIEW_EDIT`, cue banner `EM_SETCUEBANNER`) + owner-drawn
  `LISTBOX` (`LBS_OWNERDRAWFIXED | LBS_NODATA`, `itemHeight = 40`) +
  кнопки: Вставить (default push — Enter), Как текст, Закрепить,
  Удалить, Отмена. В подписи записи `EntryMetaSuffix` добавляет
  `ЧЧ:ММ · owner.exe` (из `StampUtc`/`Owner`).
- Удаление: клавиша Delete (`WM_VKEYTOITEM` → `Result := -2`, чтобы
  не бипало), кнопка «Удалить» и ПКМ-контекстное меню
  (`WM_CONTEXTMENU` → `TrackPopupMenuCmd` — собственный импорт с
  возвратом UINT, т.к. RTL-обёртка возвращает BOOL) → `RemoveClipEntry`;
  pinned-записи удаляются только явной командой. В меню также
  «Сохранить как…» → `EntrySaveAs`: PNG через `EntryPngBytes`
  (готовый PNG-формат или `PngFromDib`), текст/файлы — UTF-8+BOM;
  диалог `GetSaveFileNameW` (объявлен вручную — его нет в RTL),
  запись через `CreateFileW`+`THandleStream` (Unicode-пути).
- `ViewIdx[]` — отображение строки списка → индекс в `ClipHistory`
  (фильтрация по `Text`/подписи, case-insensitive);
  `ViewThumbs[]` — ленивый кэш миниатюр по индексу записи
  (`EntryThumbHbm`, освобождается в `WM_DESTROY`).
- `ClipAdd`/`TogglePin`/`IDM_CLIPCLEAR` шлют `VIEW_REFRESH` — список
  обновляется при живых изменениях истории.
- Модальный цикл `GetMessage` + `IsDialogMessageW` — как в диалоге
  захвата; `LastForeWnd` захватывается до показа окна для автовставки.

## Модуль захвата текста (Textify)

Триггеры: `Ctrl+Alt+T` (настраивается) и `Ctrl+Средний клик` (фиксированный,
через `WH_MOUSE_LL` в отдельном потоке → `WM_GRAB_CLICK`).

### Цепочка захвата — три слоя

```
GrabTextUIA → GrabTextMSAA → GrabTextFallback
```

Каждый слой вызывается только если предыдущий вернул пустую строку.

**1. UIA (`GrabTextUIA`)** — современный слой, покрывает Chrome/Edge/Office/
Electron/WPF:

- `CoCreateInstance(CLSID_CUIAutomation)` → `ElementFromPoint`
- Двойной запрос с `Sleep(60)` — Chromium строит AX-дерево лениво
- Свойства через `GetCurrentPropertyValue`: `Name` (30005), `Value.Value`
  (30045), фолбэк `LegacyIAccessible.Name` (30092) / `.Value` (30093)
- Подъём по родителям через `RawViewWalker.GetParentElement` (до 8 уровней),
  с контролем `ProcessId` (30002) — не выходим за пределы процесса
- Объявления `IUIAutomation`/`IUIAutomationElement`/`IUIAutomationTreeWalker` —
  частичные, только префикс vtable в точном порядке из `uiautomationclient.idl`.
  Порядок методов взят из mingw-w64 IDL — НЕ совпадает с .NET-перечислением!

**2. MSAA (`GrabTextMSAA`)** — оригинальный механизм Textify:

- `AccessibleObjectFromPoint` (oleacc.dll), двойной вызов для Chromium
- `accName` + `accValue` + `accDescription` (кроме `ROLE_SYSTEM_TITLEBAR`)
- Подъём по `accParent` до 8 уровней в пределах одного pid

**3. Fallback (`GrabTextFallback`)** — `WindowFromPoint` → `WM_GETTEXT`
(timeout 300 мс) → `GetWindowTextW` → корневое окно. Отдаёт заголовок окна.

`IAccessible` объявлен вручную — в FPC RTL его нет.

### URL под курсором (`ExtractUrl`)

`Ctrl+Alt+MMB` (`WM_GRAB_CLICK`, wParam=2): обычная цепочка захвата, затем
поиск первого вхождения `https://`/`http://`/`ftp://`/`www.` — URL копируется
в буфер напрямую, без диалога. Хвостовая пунктуация (`,.;:!?)]}`) срезается.

### OCR (`GrabTextOcr`, Windows.Media.Ocr)

`Alt+MMB` (wParam=3) или `Ctrl+Alt+O` (`HOTKEY_OCR`):

1. `UiaElementRect` — BoundingRectangle элемента (свойство 30001,
   variant-массив 4 double), фолбэк — `GetWindowRect(WindowFromPoint)`.
2. `BitBlt` области экрана в 32-битный top-down `CreateDIBSection` (BGRA).
3. `OcrPixelsToText`: пиксели → `TNativeBuffer` (собственный COM-класс
   `IBuffer` + `IBufferByteAccess` — `MemoryBuffer` не отдаёт `IBuffer`
   через QI, проверено: `E_NOINTERFACE`) → `ISoftwareBitmapStatics.
   CreateCopyFromBuffer` (BGRA8=87) → `IOcrEngine.RecognizeAsync` →
   поллинг `IAsyncInfo.get_Status` (Sleep 50 мс, максимум ~10 с) →
   `GetResults` → `IOcrResult.get_Text` → HSTRING.
4. Движок кешируется в `gOcrEngine` (`TryCreateFromUserProfileLanguages`);
   если OCR-пакетов нет — `QueueInfo(txtOcrNoPack)`.

WinRT-интерфейсы объявлены вручную по SDK IDL (`windows.media.ocr.idl`,
`windows.foundation.idl`, `windows.graphics.imaging.idl`) — порядок
vtable точный. `IInspectable` добавляет `GetIids`/`GetRuntimeClassName`/
`GetTrustLevel` после трёх методов `IUnknown`. Фабрики:
`RoGetActivationFactory` из combase.dll (`RoInitialize(0)` при старте).
Консольный тест: `test\ocrtest.pas` (FPC). На системах без языковых
пакетов (`AvailableRecognizerLanguages` = 0) движок не создаётся —
проверяется один раз и кешируется в `OcrChecked`.

**OCR-индекс истории**: при добавлении картинки в историю (`ClipAdd`)
`QueueOcrIndex` запускает `OcrIdxThread` (не более 3 одновременно —
счётчик `OcrIdxPending`). Поток декодирует PNG→BGRA (`PngToBgra`,
GDI+→`GetDIBits` top-down) и прогоняет `OcrPixelsToText`; общий движок
`gOcrEngine` защищён `OcrCs` (WinRT-объекты agile, но CS страхует от
параллельного вызова из grab-пути). Результат приходит в главное окно
`WM_OCRIDX_DONE` (ключ = `Time`+`StampUtc` записи) и пишется в
`OcrText` — участвует в фильтре `ViewRebuildFilter`. В `MCL4` не
сериализуется: индекс живёт только в памяти сессии.

**Проверка обновлений**: `IDM_UPDATE` → `CheckUpdates` → `UpdThread`
(WinInet `InternetOpenW`/`InternetOpenUrlW`/`InternetReadFile`, TLS на
стороне ОС) → GitHub API `releases/latest` → `WM_UPDATE_DONE` →
сравнение `tag_name` с `APP_VERSION` (`VersionNewer`, числовое по
компонентам) → `MessageBox` + `ShellExecuteW` на `html_url` релиза.
Ничего не скачивается и не ставится автоматически.

### Фоновый звук (MFPlay / Media Foundation)

- Подменю `Фоновый звук` (станции `IDM_RADIO_BASE+i`, `Стоп`,
  `Тише`/`Громче`, чекбокс `IDM_RADIO_EN`). **Выключено по умолчанию**
  (`[radio] enabled=0`): список станций читается только при включении,
  а `mfplay.dll` подгружается лениво `LoadLibraryW`+`GetProcAddress`
  при первом `RadioPlay` — нулевая цена при старте.
  Воспроизведение через `MFPCreateMediaPlayer`: возвращается
  мгновенно, подключение к потоку идёт асинхронно — UI не блокируется.
  `IMFPMediaPlayer` объявлен вручную по vtable mfplay.h (IUnknown-based,
  все 33 метода в точном порядке — только `Play`/`Stop`/`SetVolume`/
  `Shutdown` реально вызываются). fStartPlayback=TRUE — поток играет
  как только буферизуется.
- Громкость — `SetVolume` в диапазоне 0.0–1.0 (`RadioVolume/100`).
- Станции: `RADIO_DEF_*` (4 встроенные) + `[radio] stationN=Name|URL`
  из INI — объединяются в `RadioNames`/`RadioUrls` при загрузке.
- `RadioStop` вызывается из `WM_DESTROY` — `Stop`+`Shutdown`,
  интерфейс обнуляется (Release при присваивании nil).
- NB: `IMediaControl`/`IBasicAudio` (DirectShow) не использовать —
  их база `IDispatch`, и легаси URL-источник блокирует вызов
  `RenderFile` на время подключения.

### Диалог захвата (`ShowGrabDialog`, класс `MemClipGrab`)

- Окно 480×200 у курсора, светло-оранжевый фон `RGB(255,206,163)`,
  кремовое поле ввода `RGB(255,247,234)`
- `EM_SETMARGINS` — отступ ~1 символ по краям, пустая строка сверху
  (в буфер копируется исходный текст без неё)
- Весь текст выделен; Enter/«Копировать» — копия в буфер, Esc — отмена
- `GrabEditProc` — сабклассинг Edit'а (Enter/Esc/Ctrl+C)
- Копированный текст автоматически попадает в историю буфера

## Скриншоты области (`ShowSnip`, класс `MemClipSnip`)

- Оверлей `WS_POPUP|WS_EX_TOPMOST|WS_EX_LAYERED` на весь виртуальный
  экран (`SM_XVIRTUALSCREEN`/`SM_YVIRTUALSCREEN`/`SM_CXVIRTUALSCREEN`/
  `SM_CYVIRTUALSCREEN`), `SetLayeredWindowAttributes` α=150 — затемнение.
- При drag'е `SetWindowRgn` вырезает «дырку» под выделением
  (`CreateRectRgn` + `CombineRgn(RGN_DIFF)`, внутренняя рамка 2px) —
  область видна яркой; в `WM_PAINT` рисуется белое кольцо и размер WxH.
- `WM_LBUTTONUP` переводит оверлей в режим подгонки (`SnipAdjusting`):
  рамка хранится в `SnipSel`, drag внутри — перемещение (`SnipMoving`),
  за края ±6 px — resize по маске `SnipEdge` (1/2/4/8 = L/T/R/B),
  стрелки — nudge 1 px (Shift — 10). Клик вне рамки начинает новое
  выделение. `Enter` коммитит с модификаторами (`SnipModeFromKeys`),
  `DestroyWindow` → `Sleep(120)` → `SnipFinish`:
  `CreateDIBSection`(32bpp top-down) + `BitBlt` со screen DC.
- Режимы по модификаторам при Enter: обычный → `ShowSnipEditor`
  (разметка); Alt → сразу `CF_BITMAP` + `PNG` (GDI+ `GdipSaveImageToStream`)
  в буфер; Ctrl → `OcrPixelsToText` → `ShowGrabDialog`; Shift →
  `GdipSaveImageToFile` в `screenshots\clip_yyyymmdd_hhnnss.png` +
  копия в буфер. Общий хвост «PNG + буфер/файл» вынесен
  в `SnipCommitBitmap(bmp, w, h, doSave)`.
- `SnipWindow`/`SnipAll` (`HOTKEY_SNIPWND`/`HOTKEY_SNIPALL`) — снимок
  `GetWindowRect(GetForegroundWindow)` / виртуального экрана напрямую
  через `SnipFinish` без оверлея; mode 3 (редактор) по умолчанию,
  mode 0 при зажатом Shift. `HOTKEY_SNIPLAST` повторяет `SnipLastScr`
  (последняя область, запоминается в `SnipFinish`) режимом 0.
- Пока `hSnipWnd <> 0` или `hEditWnd <> 0`, `MouseHookProc` пропускает
  жесты MMB.
- Модальный цикл `GetMessage/DispatchMessage` как у viewer'а —
  таймеры и `WM_CLIPBOARDUPDATE` продолжают работать.

### Редактор разметки (`ShowSnipEditor`, класс `MemClipEdit`)

- Окно в духе Lightshot: сверху панель инструментов (`EDIT_TB_H`) —
  push-like кнопки `BS_PUSHLIKE|BS_AUTOCHECKBOX` (карандаш/линия/
  стрелка/рамка/текст/размытие, `IDC_ED_TOOLS+i`, взаимоисключение
  через `BM_SETCHECK`) + 6 owner-drawn кнопок цвета (`IDC_ED_COLS+i`,
  рисуются в `WM_DRAWITEM`, активный цвет — чёрная рамка).
- Шейпы — `EditShapes: array of TEditShape` (инструмент, цвет, якоря
  A/B в координатах исходника, `Pts` для карандаша, `Text` для текста);
  отрисовка — `EditShapeDraw(dc, shape, scale, offY)` одна и для
  превью (масштаб `EditScale`) и для коммита (scale=1).
- Текст: клик создаёт сабклассированный `EDIT` (`EditInputProc` —
  Enter фиксирует, Esc отменяет, `EN_KILLFOCUS` фиксирует).
- Размытие — `EditApplyBlur`: пикселизация блоками `EDIT_BLUR_SZ=8`px
  прямо в `EditBmp` через `GetDIBits`/`SetDIBits` (деструктивно,
  как в Lightshot); перед применением снимается снапшот
  `EditCopyBmp` в `EditUndoLog`.
- Undo — `EditUndoLog: array of TEditUndo` (shape-pop или
  bitmap-restore); Ctrl+Z и кнопка «Назад».
- «Сбросить» — восстанавливает `EditBmp` из `EditOrig` (снимок при
  открытии) и чистит шейпы/лог.
- Коммит (`EditCommit`): `CreateCompatibleBitmap` + `EditRender`
  (BitBlt + все шейпы) → `SnipCommitBitmap`. `EditBmp`/`EditOrig`/
  снапшоты undo удаляются в `WM_DESTROY`.

## Горячие клавиши

- `RegisterHotKey` + `MOD_NOREPEAT`; id: `HOTKEY_CLIPMENU`=1 (окно истории),
  `HOTKEY_GRAB`=2 (захват текста), `HOTKEY_PLAIN`=3 (вставка без
  форматирования → `PastePlainFromClipboard`: текущий буфер → только
  `CF_UNICODETEXT` → `Ctrl+V`), `HOTKEY_OCR`=4 (OCR под курсором),
  `HOTKEY_SNIP`=5 (оверлей снятия области экрана), `HOTKEY_SNIPWND`=6
  (активное окно), `HOTKEY_SNIPALL`=7 (весь экран)
- Диалог `MemClipHotkey`: перехват `WM_KEYDOWN/WM_SYSKEYDOWN`, требуется
  хотя бы один модификатор (Ctrl/Alt/Shift/Win), Esc — отмена
- Мышиные жесты — фиксированные (живут в MouseHookThread):
  Ctrl+MMB — текст, Ctrl+Alt+MMB — URL, Alt+MMB — OCR
- Хранение в `MemClip.ini`:

```ini
[hotkeys]
clip_mods=3     ; MOD_ALT|MOD_CONTROL = 1|2
clip_vk=86      ; 'V'
grab_mods=3
grab_vk=84      ; 'T'
plain_mods=3
plain_vk=66     ; 'B'
ocr_mods=3
ocr_vk=79       ; 'O'
snip_mods=3
snip_vk=83      ; 'S'
snipwnd_mods=3
snipwnd_vk=65   ; 'A'
snipall_mods=3
snipall_vk=70   ; 'F'
sniplast_mods=7 ; Ctrl+Alt+Shift
sniplast_vk=83  ; 'S'

[clipboard]
merge=0                           ; склейка последовательных текстовых копий
exclude=keepass.exe;bitwarden.exe ; процессы, чей буфер не записывается
max=30                            ; размер истории без pinned (5–256)
keep_days=0                       ; автоудаление записей старше N дней (0 — выкл)

[main]
interval_min=5      ; 0 = «Вручную» (очистка приостановлена)
watch_clipboard=1   ; слежение за буфером
auto_paste=1        ; автовставка Ctrl+V после выбора из истории
grab_enabled=1      ; хоткеи/жесты захвата текста
mem_free_min_mb=0   ; автоочистка, когда свободно < N МБ (0 = выкл)
lang=auto           ; auto | ru | uk | be | en
theme=day           ; day | dusk | night — палитра окон (см. TPalette,
                    ; ApplyThemeSetting): перекрашивает кисти и фоны
                    ; viewer/popup/grab/редактора, INI-ключ theme
```

Секция `[main]` пишется при каждом изменении (интервал, ручной режим,
слежение за буфером, автовставка, захват, выбор языка) — состояние
восстанавливается после перезапуска. Параметр командной строки `-a N` имеет приоритет
над `interval_min`.

## Трей

- Левый клик → `ShowClipHistoryMenu` (меню истории у курсора)
- Правый клик → `ShowTrayMenu` (все настройки)
- Двойной клик → немедленная очистка памяти
- Выбор записи истории (`IDM_CLIPBASE + i`, база 1000) → восстановление
  всех форматов + автовставка `Ctrl+V` через `SendInput` (отключается
  галочкой «Вставлять сразу»); модификаторы при клике: Shift —
  `TogglePin`, Ctrl — `RestoreAndMaybePastePlain` (только текст)
- `LastForeWnd` запоминается до показа меню — фокус возвращается
  исходному окну перед вставкой

## Параметры командной строки

| Параметр | Действие |
|---|---|
| `/clean` | Разовая очистка и выход |
| `/install` | Задача «MemClip» в Планировщике (`onlogon`, highest) |
| `/uninstall` | Удаление задачи |
| `/elev` | Внутренний флаг перезапуска с элевацией |
| `/aN` | Автозагрузка с интервалом N мин (1..120, обрезка → `CfgIntervalCapped`) |

Автозагрузка — через `schtasks.exe` (`/create /tn "MemClip" /sc onlogon
/rl highest`), не реестр: программе нужны права админа при каждом старте.

## Локализация

Массив `Texts[TLang, TTextId]` — RU/UK/BY/EN, язык определяется по
`GetUserDefaultUILanguage` (`DetectLanguage`). Любой новый `TTextId`
требует строки во всех четырёх кортежах — компилятор проверит размер.

## Типичные ошибки при сборке

- `Error: Can't create object file: MemClip.exe (error code: 5)` —
  запущенный экземпляр держит exe. Собирайте в другое имя
  (`-oMemClip_new.exe`): при запуске новая копия корректно завершит старую
  (`ReplacePrevious` через mutex `memclip_pas` + поиск окна `MemClipMain`).
- Параметр `wParam`/`lParam` затеняет тип `WPARAM`/`LPARAM` —
  приводите через `DWORD(...)`/`LPARAM(...)` явно.
- `TrackPopupMenu` в FPC возвращает `WINBOOL` — id пунктов ≥1000 через
  `TPM_RETURNCMD` обрежутся; меню работают через `WM_COMMAND`.

## Расширение: куда смотреть

- Новый формат буфера → `REGFMT_NAMES` + `REGFMT_COUNT` (+ ветки в
  `RestoreClipEntry`, `ClipMenuLabel`, сохранение имени — автоматически)
- Новый пункт трея → константа `IDM_*` + `ShowTrayMenu` + `case` в
  `WM_COMMAND` `MainWndProc`
- Новый слой захвата → `DoGrabAtCursor`, вставить в цепочку
- UIA-паттерны (TextPattern для полных документов) → расширять
  vtable-объявления строго по `uiautomationclient.idl`
