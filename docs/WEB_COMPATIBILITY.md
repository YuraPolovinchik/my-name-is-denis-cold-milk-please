# Web compatibility audit

Target: Godot 4.4.1, Web platform, GL Compatibility renderer, single-threaded build.

## Findings

- Official 4.4.1 export templates were absent locally. The exact matching official no-thread templates were installed before export.
- The desktop football video is about 211 MB and an unused MP4 source is about 217 MB. The Web build uses a separately compressed Theora copy and excludes both desktop/source copies without changing the Windows build.
- The project had no Web export preset or browser shell. A single-threaded preset, custom loading/start shell and GitHub Pages artifact workflow were added.
- Browser focus loss previously allowed the simulation to continue. The Web build now releases the pointer and pauses until focus returns.
- Firefox rejected Godot's delayed pointer-lock request after loading. The Web start button now locks the canvas during the original user gesture.
- The browser fallback font lacked the ruble sign. The HUD now embeds Noto Sans so currency and Cyrillic text render consistently without operating-system fonts.
- Persistent data already used `user://`. A browser-facing reset now removes only this game's save, tutorial, leaderboard and achievement files.
- No native Windows API calls, external process execution, GDExtension, compute shader, worker thread, or filesystem access outside `user://` was found in runtime scripts.

## Compatibility fallbacks

- Renderer: GL Compatibility for desktop and Web.
- Web threads and GDExtension support: disabled.
- Water, milk, spills and the flood use standard meshes/materials rather than compute shaders.
- Mobile devices receive a warning before the heavy scene starts; desktop keyboard and mouse remain the supported input.


## Проверка Web после обновления окружения — 14.09.2026

Основной целевой режим — WebGL 2.0 / Compatibility на статичном GitHub Pages. Forward+ — дополнительный локальный режим; SSAO/SSIL не являются частью браузерного результата. Новые 11 моделей, материалы, шторы, полы и архитектурная отделка включены в Web-экспорт.

Экспорт Web выполнен Godot 4.4.1. Проверен запуск готового dist/web через простой HTTP-сервер в Chromium: GRAPHICS_ENHANCED_OK, FURNITURE_ENHANCED_OK, TRIM_ENHANCED_OK. В обычном запуске консоль без ошибок и предупреждений. Дополнительно снята гостиная с --capture-living; WEB_ROOM_CAPTURE_READY подтверждён. В QA-запуске браузер выдал сообщение об отклонённом pointer lock, визуальный кадр доступен. Полное прохождение и Firefox в этом проходе не проверялись.

index.pck: 84501776 байт (80.59 МиБ), до оптимизации 123001664 байта. Normal-карты, встроенные в новые модели, уменьшены до 512×512; геометрия сохранена. Из экспорта исключены служебные каталоги и снимки комнат. BUILD_WEB.bat и workflow Pages проверяют размер PCK перед публикацией. Workflow продолжает публиковать готовый dist/web; при изменении исходников нужно заново выполнить экспорт.

Изменения и готовая сборка находятся локально. Git push и развёртывание GitHub Pages в этом проходе не выполнялись.
