# Ядро Sega Master System / Game Gear / SG-1000 для Karabas Go / Mini / Mini G

[English version](README.md)

Sega Master System, Game Gear, SG-1000 и SC-3000 для плат семейства Karabas Go (Xilinx Spartan-6 XC6SLX25). Порт [ядра SMS для MiSTer](https://github.com/MiSTer-devel/SMS_MiSTer) (оно само — порт ядра Ben'а для Papilio), с обвязкой платы из [karabas-go-modules](https://github.com/andykarpov/karabas-go-modules).

| Плата | Файл ядра | Видео | Звук |
|---|---|---|---|
| Karabas Go | `sms.kg` | VGA | I2S ЦАП (PCM5102) |
| Karabas Mini | `sms.kg` | HDMI | HDMI, аналоговый выход (сигма-дельта), линейный вход |
| Karabas Mini G | `sms.kg` | HDMI | HDMI, I2S ЦАП, линейный вход |

Файл ядра лежит в `src/`. Нужна прошивка **v26112702** или новее (файловый загрузчик передаёт расширение файла, по нему выбирается система). BIOS Sega и образов игр в комплекте нет: ядро запускает картридж напрямую. Положите свои `.sms` / `.gg` / `.sg` / `.sc` на SD-карту в `/sms`. Свободные homebrew для проверки: игры [haroldo-ok](https://github.com/haroldo-ok) для Master System (MIT: [Juno First](https://github.com/haroldo-ok/juno-first-sms), [Star Frag 3D](https://github.com/haroldo-ok/star-frag-3d-sms), [Scorched](https://github.com/haroldo-ok/scorched-sms), [Sub Rescue](https://github.com/haroldo-ok/sub-rescue)) и игры SG-1000 от [Mojon Twins](https://github.com/mojontwins/loves_the_sg1000) (LGPL-3.0).

Состояние: проверено на Mini G. Сборки для Go и Mini на платах ещё не запускались.

## Возможности

- **Системы — по расширению файла:** `.sms` (и любое другое) — Master System, `.gg` — Game Gear (его экран 160 × 144 и палитра на 4096 цветов), `.sg` — SG-1000 (палитра TMS9918), `.sc` — SC-3000 (+ клавиатура SK-1100 на USB-клавиатуре).
- **Картриджи:** ПЗУ до 4 МБ в SDRAM, мапперы ядра MiSTer с его автоопределением (Sega, Codemasters, корейские, в стиле MSX и другие), заголовок копировщика 512 байт пропускается.
- **Звук:** PSG (SN76489) и FM-блок (YM2413, пункт OSD); стерео по HDMI и на ЦАП / аналоговом выходе. Линейный вход платы (и её MIDI-синтезатор) подмешивается (Mini G, Mini).
- **Видео:** картинка увеличена в целое число раз по обеим осям в 1024 × 768 при 60 Гц: 256 × 192 ×4 — весь экран, 224 / 240 строк ×3, Game Gear ×5. Буфер кадра в SRAM показывает последний полный кадр (машина идёт на своих 59,9 / 50 Гц), кадры не рвутся.
- **Сохранения:** ОЗУ картриджа (и EEPROM картриджей Game Gear, где он есть) хранится в `/sms/saves/<игра>.sav` на SD-карте (32 КБ для каждой игры, как в MiSTer) и записывается через секунду после того, как игра его изменила.

Не сделано: BIOS Sega, System E, флеш Master System Evolution, световой пистолет / паддл / мультитап, пады Mega Drive, Gear-to-Gear, снапшоты, читы.

## Начало работы

1. Скопируйте `sms.kg` (один файл для Go, Mini и Mini G) в корень SD-карты.
2. Положите игры в `/sms` на SD-карте.
3. Выберите Master System в меню ядер, игру — в браузере файлов (**Menu+Esc** открывает его снова). В следующий раз ядро само запустит последнюю игру.

«Menu» — клавиша Windows на клавиатуре.

## Меню OSD

| Пункт | Значения | Клавиша |
|---|---|---|
| Region | Export / Japan (регион консоли) | |
| Video | NTSC / PAL | |
| FM sound | On / Off | |
| Border | Off / On (рамка VDP вокруг картинки) | |
| Swap joys | Off / On | |
| Left column | BG / Black (левая колонка, которую прячет игра: цвет фона или чёрная) | |
| Sprites | Standard / All (All: больше 4 спрайтов на строку в режимах SG-1000, меньше мерцания; как в MiSTer) | |
| Reset | сброс машины | F12 |

## Управление

| Master System | Клавиатура (пад 1) | Клавиатура (пад 2) | USB-пад |
|---|---|---|---|
| Крестовина | стрелки | I J K L | крестовина |
| Кнопка 1 | Z | U | A |
| Кнопка 2 | X или C | O или P | B или C |
| Pause (Game Gear: Start) | Enter | M | Start |

На SC-3000 клавиатура вместо этого — клавиатура SK-1100 (стрелки, Enter и буквы как на ней; Alt = GRAPH, Caps Lock = ENG DIER'S, F1 = FUNC, Esc = BREAK, Home = CLR HOME, Insert / Delete = INS DEL).

## Сборка

Клонируйте с `--recursive` (сабмодуль `modules`), исходники upstream — `tools/fetch_upstream.sh` (нужны только для сравнения; импортированный RTL лежит в `src/rtl/sms`). ISE 14.7: `cd src && make` для всех плат или `make minig` для одной. Верхи Mini и Go (и временную часть их ucf) делает из верха Mini G `src/tools/mktops.py`, списки исходников — `src/tools/mkprj.sh`.

Проверки: `src/sim/run.sh` (несколько минут): буфер кадра (`tb_fb`, iverilog, три размера попиксельно), затем машина в Verilator (VHDL через `ghdl --synth`) на своих тестовых ROM из `src/sim/tests` (`vdptest` для Master System и Game Gear, `sgtest` для SG-1000, `savetest` для ОЗУ картриджа), в том числе через путь платы (загрузчик, контроллер SDRAM, модель SDRAM). План и заметки по устройству — [docs/PLAN.md](docs/PLAN.md).

## Лицензия

GPL-3.0 (см. [LICENSE](LICENSE)). Ядро SMS для MiSTer — GPL (файла лицензии нет; его форки — GPL-3.0).

Sega, Master System, Game Gear и SG-1000 — товарные знаки Sega. Проект не связан с Sega.
