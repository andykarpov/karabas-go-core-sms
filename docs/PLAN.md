# План ядра Sega Master System / Game Gear / SG-1000 для Karabas Go / Mini / Mini G

Цель: ядро Sega Master System, Game Gear, SG-1000 и SC-3000 для плат Karabas (XC6SLX25, ISE 14.7). Картридж — файлом `.sms` / `.gg` / `.sg` / `.sc` с SD через прошивку (OSD `F`, burst), сейвы картриджа на SD. Загрузчика и soft-CPU в ядре нет. Открытые вопросы: `docs/BACKLOG.md`.

## Что изучено (2026-11-27)

| Проект | Что есть | Лицензия | Роль |
|---|---|---|---|
| [MiSTer-devel/SMS_MiSTer](https://github.com/MiSTer-devel/SMS_MiSTer) (bb77fbd, 2026-11-18) | SMS / GG / SG-1000 / SC-3000 (+ клавиатура SK-1100), System E, Evolution; FM VM2413, PSG jt89, T80; мапперы Sega / Codemasters / Korean / MSX, автоопределение; EEPROM 93C46; NTSC / PAL; лайтган, паддл, мультитап, MD-пады; читы, savestates. RTL почти весь VHDL-93 (порт ядра Ben'а для Papilio — Xilinx). Есть `mist/` — верх MiST на **EP3C25** с SDRAM | файла лицензии нет; GPL по экосистеме (форки — GPL-3) | **основа** `rtl/`, `mist/` — образец |
| [nand2mario/smstang](https://github.com/nand2mario/smstang) (3d36b96, 2025-04) | то же ядро на Verilog для Tang Console 60K / 138K, HDMI, SDRAM | — | донор |
| [Schmiddty/SMSTangNano20k](https://github.com/Schmiddty/SMSTangNano20k) (5684d30, v1.1 2026-11-23) | smstang на Tang Nano 20K (GW2AR-18), `opll.v` — VM2413 в Verilog | GPL-3.0 | донор |
| наши `karabas-go-core-sega`, `-gameboy`, `-wonderswan` | gen_ctrl / клавиатура как пады, картридж в SDRAM, буфер кадра в SRAM, сейвы `kg_bk_ram`, vhdl93.py, sv2v, mktops.py, симуляция | наш | **обвязка платы** |

## Решения (пользователь, 2026-11-27)

1. **Основа — SMS_MiSTer master** (VHDL как есть + `mist/` как образец верха), Verilog-форки Tang — только доноры.
2. **Системы в первом релизе:** SMS, Game Gear, SG-1000 / SC-3000 (клавиатура SK-1100 с USB-клавиатуры), FM (YM2413) — если влезет по Ф0.
3. **Имя `sms`**, репо `karabas-go-core-sms`, **публичный сразу**. Файл `sms.kg`, каталог SD `/sms`.

Предложено (поменять — сказать):

4. **Видео: буфер кадра в SRAM**, вывод **1024 × 768 @ 60 Гц** (как Sega): SMS / SG 256 × 192 ×4 = 1024 × 768 ровно, 224 / 240 строк ×3, GG 160 × 144 ×4 = 640 × 576 по центру. Кадр 59,92 / 49,7 Гц — тройной буфер (как `ws_fb`).
5. **Картридж в SDRAM** (до 4 МБ; Evolution 16 МБ — позже), ОЗУ машины / VRAM — BRAM как у MiST. Сейвы — ОЗУ картриджа (и EEPROM 93C46) через `kg_bk_ram` в `<игра>.sav`, формат MiSTer.
6. **BIOS Sega не кладём**, ядро стартует картридж напрямую (как MiSTer без BIOS); загрузка своего BIOS-файла — в беклог.
7. Не берём в первый релиз: System E, Evolution, читы, savestates, лайтган, мультитап, Gear-to-Gear — в беклог.

## Архитектура (черновик, уточняется в Ф0)

```
 system (MiSTer) ── T80 + vdp + jt89 (+ vm2413) + io + мапперы + EEPROM
                 ── BRAM: VRAM 16 К, WRAM 8 К (SC-3000 / Korean 32 К), CRAM, BIOS-заглушка
 sms_sdram ─────── ПЗУ картриджа (+ ОЗУ картриджа), канал загрузки от kg_mcu
 kg_mcu2 ───────── F (.sms/.gg/.sg/.sc → SDRAM), HID (пады / клавиатура), OSD, kg_bk_ram (сейвы)
 sms_fb ────────── 256 × 192..240 RGB → SRAM (3 буфера) → 1024 × 768
 верх платы ────── клоки, kg_osd_overlay, HDMI + звук, ЦАП
```

## Фазы

Одна ветка на фазу, один PR в конце.

### Ф0. Импорт, симуляция, оценка размера
- `src/rtl/sms/` из SMS_MiSTer `rtl/` (без savestates / cheats / System E / Evolution где это вынимается), `vhdl93.py` при необходимости, `sv2v` для `.sv`.
- `make sms-xst`: LUT / FF / RAMB16 / Fmax машины с FM и без; решение по FM и клоку (MiSTer clk_sys 53,69 МГц).
- Verilator + ghdl: свободные тестовые ROM (homebrew, тест VDP) рисуют кадр → PNG.

### Ф1. SMS на Mini G
- Верх Mini G (от Sega / Game Boy), клоки, `sms_sdram` + загрузка `F`, `sms_fb` 1024 × 768, OSD, пады / клавиатура → джойстики SMS, кнопка Pause, звук HDMI + ЦАП.
- Проверка на плате (после «да» на захват).

### Ф2. Game Gear, SG-1000 / SC-3000, сейвы
- Режим по расширению файла, GG-палитра и окно 160 × 144, SG / SC режимы VDP, клавиатура SK-1100.
- ОЗУ картриджа и EEPROM → `kg_bk_ram` (`.sav`).

### Ф3. Опции, Go / Mini, релиз
- OSD: регион (NTSC / PAL, Japan / Export), маппер (Auto / принудительно), FM, рамка, левая колонка, лишние спрайты.
- Верхи Go / Mini (`mktops.py`), три платы, `sms.kg`, README.md + README.ru.md, `cores.json` karabas-go.

## Риски

| Риск | Что делаем |
|---|---|
| FM VM2413 не влезает (~2–3 тыс. LUT) | OSD-опция сборки / без FM, решение по Ф0 |
| VHDL-2008 / SV в rtl | vhdl93.py, sv2v; savestates.sv не берём |
| Частота кадра 59,92 / 49,7 Гц ≠ 60 | тройной буфер в SRAM, повтор кадра |
| Права на игры и BIOS | в репо и `.kg` ни BIOS, ни игр; тесты — свободные ROM |
