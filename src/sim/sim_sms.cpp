// sim_sms.cpp - harness of sms_machine (SMS / GG / SG-1000), the cartridge ROM and RAM in C++;
// built with -DSIM_SYS it drives sim_top.v instead: the file goes in as the bytes of the file loader
// of kg_mcu2 (one every 14 clocks = 258 ns, the fastest the mcu sends) through sms_loader and
// sms_sdram into the SDRAM model, and the machine reads its ROM from there.
//
// One clk_sys period = 2 steps; inputs change after the falling edge. The cartridge ROM answers the
// address of the previous clock (rom_do = rom[rom_a] one clock late: the SDRAM of the board gives
// the byte within the CPU cycle of 15 clocks). The cart RAM (nvram, 32 KB) the same way.
//
// usage: Vsms_machine --rom FILE [--frames N] [--ppm PREFIX] [--gg] [--pal] [--expect-ppm FILE]
//                     [--wav FILE]
//   --frames N        run N frames (vsync rising edges) after the reset (default 10)
//   --ppm PREFIX      write PREFIX.ppm of the last frame (256 x 192 active area, RGB)
//   --expect-ppm FILE the last frame must equal this PPM
//   --trace N         print the first N ROM reads (address changes while rom_rd)
//   --wav FILE        write the audio (left channel, 16 bit, 1 sample per 1024 clocks = 52.4 kHz)
// Prints one line per frame (checksum) and "PASS" / "FAIL: ..." at the end.

#ifdef SIM_SYS
#include "Vsim_top.h"
typedef Vsim_top Top;
#else
#include "Vsms_machine.h"
typedef Vsms_machine Top;
#endif
#include "verilated.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>

static Top *top;
static std::vector<uint8_t> rom, nvram(32 * 1024, 0xFF);
static uint64_t clocks;

static void edge_rise() { top->clk_sys = 1; top->eval(); }
static void edge_fall() { top->clk_sys = 0; top->eval(); clocks++; }

static const int W = 256, H = 192;
static uint8_t fb[W * H * 3];

static bool write_ppm(const std::string &f) {
	FILE *o = fopen(f.c_str(), "wb");
	if (!o) return false;
	fprintf(o, "P6\n%d %d\n255\n", W, H);
	fwrite(fb, 1, sizeof fb, o);
	fclose(o);
	return true;
}
static bool read_ppm(const std::string &f, std::vector<uint8_t> &d) {
	FILE *i = fopen(f.c_str(), "rb");
	if (!i) return false;
	int w, h, m;
	if (fscanf(i, "P6 %d %d %d", &w, &h, &m) != 3 || w != W || h != H) { fclose(i); return false; }
	fgetc(i);
	d.resize(W * H * 3);
	bool ok = fread(d.data(), 1, d.size(), i) == d.size();
	fclose(i);
	return ok;
}
static void put16(FILE *f, int v) { fputc(v & 255, f); fputc((v >> 8) & 255, f); }
static void put32(FILE *f, uint32_t v) { put16(f, v & 0xFFFF); put16(f, v >> 16); }

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	std::string romf, ppm, expect, wavf;
	int frames = 10, trace = 0;
	uint32_t last_ra = ~0u;
	bool gg = false, pal = false;
	for (int i = 1; i < argc; i++) {
		std::string a = argv[i];
		auto nx = [&]() { return std::string(i + 1 < argc ? argv[++i] : ""); };
		if (a == "--rom") romf = nx();
		else if (a == "--frames") frames = atoi(nx().c_str());
		else if (a == "--ppm") ppm = nx();
		else if (a == "--expect-ppm") expect = nx();
		else if (a == "--wav") wavf = nx();
		else if (a == "--trace") trace = atoi(nx().c_str());
		else if (a == "--gg") gg = true;
		else if (a == "--pal") pal = true;
	}
	FILE *rf = fopen(romf.c_str(), "rb");
	if (!rf) { printf("FAIL: no rom %s\n", romf.c_str()); return 1; }
	fseek(rf, 0, SEEK_END); rom.resize(ftell(rf)); fseek(rf, 0, SEEK_SET);
	if (fread(rom.data(), 1, rom.size(), rf) != rom.size()) { printf("FAIL: read\n"); return 1; }
	fclose(rf);

	top = new Top;
#ifdef SIM_SYS
	top->pal = pal; top->border = 0; top->fm_on = 1;
	top->j1 = 0x7F; top->j2 = 0x7F; top->pause = 1;
	top->file_active = 0; top->file_wr = 0; top->file_addr = 0; top->file_data = 0;
	{   // the extension: .gg with --gg, else .sms
		const char *e = gg ? "gg" : "sms"; uint64_t x = 0;
		for (int k = 0; e[k]; k++) x |= (uint64_t)(uint8_t)e[k] << (8 * k);
		top->file_ext = x;
	}
	for (int i = 0; i < 2000; i++) { edge_rise(); edge_fall(); }   // the SDRAM init
	top->file_active = 1;
	for (int i = 0; i < 16; i++) { edge_rise(); edge_fall(); }
	for (size_t a = 0; a < rom.size(); a++) {
		top->file_addr = a; top->file_data = rom[a]; top->file_wr = 1;
		edge_rise(); edge_fall();
		top->file_wr = 0;
		for (int k = 0; k < 13; k++) { edge_rise(); edge_fall(); }
	}
	for (int i = 0; i < 64; i++) { edge_rise(); edge_fall(); }
	top->file_active = 0;
	printf("loaded %zu bytes at clock %llu\n", rom.size(), (unsigned long long)clocks);
#else
	top->reset_n = 0; top->gg = gg; top->pal = pal; top->region = 0; top->border = 0;
	top->sc3000_en = 0; top->sk1100_en = 0; top->mapper_lock = 0; top->cart_in = 1; top->fm_on = 1;
	top->j1 = 0x7F; top->j2 = 0x7F; top->pause = 1; top->sk1100_row_data = 0xFFF;
	top->rom_do = 0xFF; top->nvram_q = 0xFF;
	for (int i = 0; i < 256; i++) { edge_rise(); edge_fall(); }
	top->reset_n = 1;
#endif

	std::vector<int16_t> wav;
	int frame = 0, old_vs = top->vsync;
	uint64_t limit = (uint64_t)(frames + 2) * 1000000ull; // a frame is ~896k clocks
	memset(fb, 0, sizeof fb);
	uint32_t sum = 0;
	while (frame < frames && clocks < limit) {
		edge_rise();
#ifndef SIM_SYS
		// memories: answer the address of this clock on the next one
		uint32_t ra = top->rom_a;
		uint8_t rd = rom.empty() ? 0xFF : rom[ra % rom.size()];
		if (trace > 0 && top->rom_rd && ra != last_ra) { trace--; last_ra = ra; printf("rd %10llu %06x = %02x\n", (unsigned long long)clocks, ra, rd); }
		uint32_t na = top->nvram_a;
		if (top->nvram_we) nvram[na] = top->nvram_d;
		uint8_t nd = nvram[na];
#endif
		// video: the pixel of (x, y) on ce_pix
		if (top->ce_pix) { // the colour of the pixel x comes one pixel later: it goes to x - 1
			int x = top->x - 1, y = top->y;
			if (x >= 0 && x < W && y < H) {
				int c = top->color;
				uint8_t *p = fb + (y * W + x) * 3;
				p[0] = (c & 15) * 17; p[1] = ((c >> 4) & 15) * 17; p[2] = ((c >> 8) & 15) * 17;
			}
		}
		edge_fall();
#ifndef SIM_SYS
		top->rom_do = rd;
		top->nvram_q = nd;
#endif
		if (!wavf.empty() && (clocks & 1023) == 0) wav.push_back((int16_t)top->audioL);
		if (top->vsync && !old_vs) {
			frame++;
			sum = 0;
			for (size_t i = 0; i < sizeof fb; i++) sum = sum * 31 + fb[i];
			printf("frame %3d  clock %11llu  sum %08x\n", frame, (unsigned long long)clocks, sum);
		}
		old_vs = top->vsync;
	}
	if (frame < frames) { printf("FAIL: only %d frames in %llu clocks\n", frame, (unsigned long long)clocks); return 1; }
	if (!ppm.empty()) write_ppm(ppm + ".ppm");
	if (!wavf.empty()) {
		FILE *o = fopen(wavf.c_str(), "wb");
		uint32_t n = wav.size() * 2;
		fwrite("RIFF", 1, 4, o); put32(o, 36 + n); fwrite("WAVEfmt ", 1, 8, o);
		put32(o, 16); put16(o, 1); put16(o, 1); put32(o, 52435); put32(o, 52435 * 2); put16(o, 2); put16(o, 16);
		fwrite("data", 1, 4, o); put32(o, n); fwrite(wav.data(), 2, wav.size(), o); fclose(o);
	}
#ifdef SIM_SYS
	if (top->sdram_errors) { printf("FAIL: %u SDRAM protocol errors\n", top->sdram_errors); return 1; }
#endif
	if (!expect.empty()) {
		std::vector<uint8_t> ref;
		if (!read_ppm(expect, ref)) { printf("FAIL: no reference %s\n", expect.c_str()); return 1; }
		int diff = 0;
		for (int i = 0; i < W * H; i++) if (memcmp(&ref[i * 3], fb + i * 3, 3)) diff++;
		if (diff) { printf("FAIL: %d pixels differ from %s\n", diff, expect.c_str()); return 1; }
	}
	printf("PASS\n");
	delete top;
	return 0;
}
