#!/usr/bin/env python3
"""Оригинальная процедурная музыка и звуки Pawtown (v0.2).

Адаптировано из /workspace/roblox-game/tools/music/synth.py (те же осцилляторы, ADSR, бесшовный цикл и эхо);
мелодии, гармония и звуки — новые, целиком синтезированы этим скриптом (без сэмплов и чужих мелодий).
  * maple_street    — дневная тема пригорода «классика + 8-бит», соль мажор, 88 BPM, 24 такта;
  * evening_lullaby — ночная «музыкальная шкатулка», фа мажор, 3/4, 66 BPM, 16 тактов;
  * голоса питомцев: bark (собака; корги и лиса — тот же звук с PlaybackSpeed), meow (кошка; барс — ниже),
    squeak (кролик, хрустальный кролик, енот), chirp (попугай), hoot (сова);
  * pickup (подобрал предмет / осколок), quest_done (шаг главы или ежедневное задание выполнено).

    python3 tools/music/synth.py [OUT_DIR [NAME...]]   -> OUT_DIR/<name>.{wav,ogg}
"""
import os
import subprocess
import sys

import numpy as np

SR = 44100
rng = np.random.default_rng(57)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def n(name):
    """'F#4' -> midi."""
    base = NOTE[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        base += 1 if name[i] == "#" else -1
        i += 1
    return base + 12 * (int(name[i:]) + 1)


# ---------------------------------------------------------------- осцилляторы
def osc(kind, f, t, duty=0.5):
    ph = (f * t) % 1.0
    if kind == "square":
        return np.where(ph < duty, 1.0, -1.0) * 0.8
    if kind == "tri":
        return 4 * np.abs(ph - 0.5) - 1
    if kind == "saw":
        return 2 * ph - 1
    if kind == "sine":
        return np.sin(2 * np.pi * ph)
    raise ValueError(kind)


def env(nsamp, a, d, s, r, dur_s):
    """ADSR (секунды); нота звучит dur_s, затем релиз r."""
    t = np.arange(nsamp) / SR
    e = np.zeros(nsamp)
    a = max(a, 1e-3)
    e = np.where(t < a, t / a, 1.0)
    dec = (t >= a) & (t < a + d)
    e = np.where(dec, 1 - (1 - s) * (t - a) / max(d, 1e-3), e)
    e = np.where((t >= a + d), s, e)
    rel = t >= dur_s
    e = np.where(rel, e * np.clip(1 - (t - dur_s) / max(r, 1e-3), 0, 1), e)
    return e


def lowpass(x, alpha):
    """Мягкий ФНЧ (alpha 0..1, меньше — темнее): свёртка с треугольным окном ~2/alpha отсчётов."""
    w = max(1, int(1 / alpha))
    k = np.convolve(np.ones(w), np.ones(w))
    return np.convolve(x, k / k.sum(), mode="same")


def mix(a, b, gb=1.0):
    """Сумма двух сигналов разной длины."""
    out = np.zeros(max(len(a), len(b)))
    out[: len(a)] += a
    out[: len(b)] += b * gb
    return out


class Track:
    def __init__(self, seconds):
        self.n = int(round(seconds * SR))
        self.buf = np.zeros((self.n, 2))

    def add(self, start_s, sig, pan=0.0, gain=1.0):
        """Кладёт сигнал с заворотом в начало (бесшовный цикл)."""
        s = int(round(start_s * SR)) % self.n
        L = np.cos((pan + 1) * np.pi / 4) * gain
        R = np.sin((pan + 1) * np.pi / 4) * gain
        idx = (np.arange(len(sig)) + s) % self.n
        np.add.at(self.buf[:, 0], idx, sig * L)
        np.add.at(self.buf[:, 1], idx, sig * R)

    def echo(self, delay_s, fb, mix):
        d = int(delay_s * SR)
        wet = np.zeros_like(self.buf)
        tap = self.buf.copy()
        for k in range(1, 5):
            tap = np.roll(tap, d, axis=0) * fb
            # пинг-понг
            wet += tap[:, ::-1] if k % 2 else tap
        self.buf = self.buf + wet * mix

    def finish(self, peak_db):
        x = self.buf
        x = np.tanh(x * 1.2) / np.tanh(1.2)
        x *= 10 ** (peak_db / 20) / (np.max(np.abs(x)) + 1e-9)
        return x


def note_sig(kind, midi, dur_s, adsr, duty=0.5, vib=0.0, vib_rate=5.5, detune=0.0):
    a, d, s, r = adsr
    total = dur_s + r
    t = np.arange(int(total * SR)) / SR
    f = midi_hz(midi) * (1 + detune)
    if vib:
        # вибрато вступает плавно, как у живого исполнителя
        depth = vib * np.clip(t / 0.25, 0, 1)
        phase = np.cumsum(f * (1 + depth * np.sin(2 * np.pi * vib_rate * t))) / SR
        sig = osc(kind, 1.0, phase, duty) if kind != "sine" else np.sin(2 * np.pi * phase)
    else:
        sig = osc(kind, f, t, duty)
    return sig * env(len(t), a, d, s, r, dur_s)




# ---------------------------------------------------------------- дневная тема: «Кленовая улица»
def maple_street():
    """Спокойная тема пригорода: соль мажор, 88 BPM, 24 такта (~65 с). Альбертиев бас (классика), мягкий пульс-лид
    (8-бит), бас половинками, «пиццикато» на слабых долях во 2-й части и тихий пэд в B-части."""
    r = np.random.default_rng(57)
    bpm = 88
    beat = 60 / bpm
    bars = 24
    tr = Track(bars * 4 * beat)
    A = ["G", "Em", "C", "D", "G", "Em", "Am", "D"]
    A2 = ["G", "Em", "C", "D", "Em", "C", "D", "G"]
    B = ["C", "D", "Bm", "Em", "C", "Am", "D", "D"]
    prog = (A + A2 + B)[:bars]
    chords = {"G": ["G2", "B2", "D3"], "Em": ["E2", "G2", "B2"], "C": ["C3", "E3", "G3"], "D": ["D3", "F#3", "A3"],
              "Am": ["A2", "C3", "E3"], "Bm": ["B2", "D3", "F#3"]}
    chord_pc = {k: [n(x) % 12 for x in v] for k, v in chords.items()}
    scale = [n(x) for x in ["G4", "A4", "B4", "C5", "D5", "E5", "F#5", "G5", "A5", "B5", "C6"]]
    for bar, ch in enumerate(prog):
        t0 = bar * 4 * beat
        lo, mid, hi = (n(x) for x in chords[ch])
        for i, m in enumerate([lo + 12, hi + 12, mid + 12, hi + 12] * 2):
            sig = mix(note_sig("tri", m, beat * 0.45, (0.004, 0.08, 0.5, 0.12)),
                      note_sig("square", m, beat * 0.4, (0.004, 0.05, 0.3, 0.1), duty=0.125), 0.2)
            tr.add(t0 + i * beat / 2, sig, pan=-0.25, gain=0.15)
        for h in range(2):
            m = lo - 12 if h == 0 else hi - 24
            tr.add(t0 + h * 2 * beat, note_sig("tri", m, 2 * beat * 0.9, (0.01, 0.2, 0.7, 0.2)), gain=0.30)
        if bar >= 8:  # «пиццикато»: короткие синусы звуков аккорда на слабых долях
            for k in (1, 3):
                m = [lo, mid, hi][(bar + k) % 3] + 24
                tr.add(t0 + k * beat, note_sig("sine", m, 0.05, (0.002, 0.18, 0.0, 0.15)), pan=0.35, gain=0.08)
        if bar >= 16:
            pad = np.zeros(int((4 * beat + 0.6) * SR))
            for m in (lo + 12, mid + 12, hi + 12):
                for dt in (-0.004, 0.004):
                    s = note_sig("saw", m, 4 * beat, (0.6, 0.5, 0.8, 0.6), detune=dt)
                    pad[: len(s)] += s
            tr.add(t0, lowpass(pad, 0.035), pan=0.3, gain=0.06)
    rhythms = [[1, 0.5, 0.5, 1, 1], [1.5, 0.5, 1, 1], [0.5, 0.5, 0.5, 0.5, 2], [1, 1, 2],
               [0.5, 0.5, 1, 0.5, 0.5, 1], [2, 1, 1], [1, 0.5, 0.5, 2], [3, 1]]
    bank = {}
    idx = 4
    for bar, ch in enumerate(prog):
        section = bar // 8
        key = (bar % 8, ch)
        if section == 1 and key in bank and bar % 8 < 4:
            notes = bank[key]
        else:
            rh = rhythms[(bar * 3 + section) % len(rhythms)] if bar % 2 == 0 else rhythms[(bar * 5 + 1) % len(rhythms)]
            if bar % 8 == 7:
                rh = [2, 2] if bar != bars - 1 else [1, 1, 2]
            notes = []
            pos = 0.0
            for d in rh:
                cands = [i for i in range(len(scale)) if abs(i - idx) <= 3]
                if pos in (0.0, 2.0):
                    cands = [i for i in cands if scale[i] % 12 in chord_pc[ch]] or cands
                else:
                    cands = [i for i in cands if abs(i - idx) <= 2] or cands
                w = np.array([1.0 / (1 + abs(i - 4) * 0.35) * (1.6 if abs(i - idx) == 1 else 1.0) for i in cands])
                idx = int(r.choice(cands, p=w / w.sum()))
                notes.append((pos, d, scale[idx]))
                pos += d
            if bar == bars - 1:
                notes[-1] = (notes[-1][0], notes[-1][1], n("G5") if notes[-1][2] > n("B4") else n("G4"))
            bank[key] = notes
        t0 = bar * 4 * beat
        for pos, d, m in notes:
            s = lowpass(note_sig("square", m, d * beat * 0.9, (0.012, 0.15, 0.55, 0.18), duty=0.25, vib=0.004), 0.25)
            tr.add(t0 + pos * beat, s, pan=0.1, gain=0.12)
            if bar >= 16:
                tr.add(t0 + pos * beat, note_sig("sine", m + 12, d * beat * 0.9, (0.03, 0.1, 0.7, 0.2), vib=0.005),
                       pan=-0.3, gain=0.045)
    tr.echo(beat * 0.75, 0.33, 0.3)
    return tr.finish(-4.0)


# ---------------------------------------------------------------- ночная тема: «Колыбельная фонарей»
def evening_lullaby():
    """Тихая ночная тема: фа мажор, 66 BPM, 16 тактов (~58 с) в размере 3/4 — «музыкальная шкатулка» (колокольчики),
    треугольный бас на первую долю и мягкий пэд."""
    r = np.random.default_rng(58)
    bpm = 66
    beat = 60 / bpm
    bars = 16
    meter = 3
    tr = Track(bars * meter * beat)
    prog = ["F", "Dm", "Bb", "C", "F", "Am", "Bb", "C", "Dm", "Bb", "F", "C", "Bb", "C", "F", "F"]
    chords = {"F": ["F2", "A2", "C3"], "Dm": ["D2", "F2", "A2"], "Bb": ["Bb2", "D3", "F3"], "C": ["C3", "E3", "G3"],
              "Am": ["A2", "C3", "E3"]}
    chord_pc = {k: [n(x) % 12 for x in v] for k, v in chords.items()}
    scale = [n(x) for x in ["F5", "G5", "A5", "Bb5", "C6", "D6", "E6", "F6"]]

    def bell(m, g):
        return mix(note_sig("sine", m, 0.04, (0.002, 1.1, 0.0, 1.1)), note_sig("sine", m + 24, 0.03, (0.002, 0.4, 0, 0.4)),
                   0.18) * g

    idx = 2
    for bar, ch in enumerate(prog):
        t0 = bar * meter * beat
        lo, mid, hi = (n(x) for x in chords[ch])
        tr.add(t0, note_sig("tri", lo - 12, meter * beat * 0.85, (0.02, 0.3, 0.6, 0.4)), gain=0.26)
        for k, m in enumerate([mid + 12, hi + 12]):
            tr.add(t0 + (k + 1) * beat, note_sig("tri", m, beat * 0.6, (0.01, 0.2, 0.4, 0.3)), pan=-0.3, gain=0.08)
        pad = np.zeros(int((meter * beat + 0.8) * SR))
        for m in (lo + 12, mid + 12, hi + 12):
            s = note_sig("saw", m, meter * beat, (0.8, 0.5, 0.8, 0.8), detune=0.003)
            pad[: len(s)] += s
        tr.add(t0, lowpass(pad, 0.03), pan=0.25, gain=0.04)
        rh = [[1, 1, 1], [2, 1], [1, 0.5, 0.5, 1], [3]][bar % 4] if bar != bars - 1 else [3]
        pos = 0.0
        for d in rh:
            cands = [i for i in range(len(scale)) if abs(i - idx) <= 2]
            if pos == 0.0:
                cands = [i for i in cands if scale[i] % 12 in chord_pc[ch]] or cands
            w = np.array([1.0 / (1 + abs(i - 3) * 0.4) for i in cands])
            idx = int(r.choice(cands, p=w / w.sum()))
            m = scale[idx] if bar != bars - 1 else n("F5")
            tr.add(t0 + pos * beat, bell(m, 0.16), pan=0.15)
            pos += d
    tr.echo(beat, 0.35, 0.35)
    return tr.finish(-6.0)


# ---------------------------------------------------------------- голоса питомцев (аддитивный синтез с формантами)
def voice(f0, formants, dur, noise=0.0, breath=0.0):
    """f0(t) — основной тон (массив), formants — список (центр(t), ширина, вес); сумма гармоник с весами формант."""
    t = np.arange(int(dur * SR)) / SR
    phase = np.cumsum(f0) / SR
    out = np.zeros(len(t))
    for k in range(1, 40):
        fk = f0 * k
        if np.min(fk) > SR / 2 - 500:
            break
        amp = np.zeros(len(t))
        for c, bw, g in formants:
            amp += g * np.exp(-((fk - c) / bw) ** 2)
        out += amp * np.sin(2 * np.pi * k * phase) / k ** 0.3
    out /= np.sqrt(np.mean(out ** 2)) + 1e-9  # шум ниже считается относительно громкости голоса
    if noise:  # шумовая атака (только первые ~40 мс)
        out += lowpass(rng.standard_normal(len(t)), 0.3) * noise * np.exp(-t * 60)
    if breath:
        out += lowpass(rng.standard_normal(len(t)), 0.5) * breath
    return out


def shape(n_, a, r):
    t = np.arange(n_) / SR
    dur = n_ / SR
    return np.clip(t / max(a, 1e-3), 0, 1) * np.clip((dur - t) / max(r, 1e-3), 0, 1)


def one_shot(sig, peak_db=-3.0):
    tr = Track(len(sig) / SR + 0.05)
    tr.add(0, sig)
    tr.buf[-int(0.03 * SR):] *= np.linspace(1, 0, int(0.03 * SR))[:, None]
    return tr.finish(peak_db)


def bark():
    """«Гав»: короткий звонкий слог с падающим тоном и шумовой атакой (0.32 с). Корги/лиса — тот же звук выше."""
    d = 0.3
    t = np.arange(int(d * SR)) / SR
    f0 = 330 + 180 * np.exp(-t * 18) - 60 * t
    f1 = 900 - 500 * t
    sig = voice(f0, [(f1, 260, 1.0), (1800, 400, 0.5), (2900, 500, 0.2)], d, noise=1.2)
    return one_shot(sig * shape(len(t), 0.008, 0.16))


def meow():
    """«Мяу»: тон поднимается и опускается, форманта «и-а-у» (0.7 с). Снежный барс — тот же звук ниже."""
    d = 0.7
    t = np.arange(int(d * SR)) / SR
    u = t / d
    f0 = 520 + 300 * np.sin(np.pi * np.clip(u * 1.1, 0, 1)) - 120 * u
    f1 = np.interp(u, [0, 0.25, 0.6, 1], [450, 1000, 900, 400])
    f2 = np.interp(u, [0, 0.25, 0.6, 1], [2300, 1700, 1300, 800])
    sig = voice(f0 * (1 + 0.01 * np.sin(2 * np.pi * 6 * t)), [(f1, 220, 1.0), (f2, 350, 0.5)], d, breath=0.02)
    return one_shot(sig * shape(len(t), 0.04, 0.2))


def squeak():
    """Писк кролика/енота: два коротких высоких «пи» с вибрато (0.45 с)."""
    out = np.zeros(int(0.45 * SR))
    for i, (st, base) in enumerate(((0.0, 1700), (0.22, 1950))):
        d = 0.16
        t = np.arange(int(d * SR)) / SR
        f = base + 500 * t / d + 60 * np.sin(2 * np.pi * 28 * t)
        s = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.25 * np.sin(4 * np.pi * np.cumsum(f) / SR)
        s *= shape(len(t), 0.01, 0.06)
        k = int(st * SR)
        out[k: k + len(s)] += s
    return one_shot(out, -5.0)


def chirp():
    """Чириканье попугая: три быстрых свиста вверх (0.5 с)."""
    out = np.zeros(int(0.5 * SR))
    for i in range(3):
        d = 0.09
        t = np.arange(int(d * SR)) / SR
        f = 2200 + 1800 * (t / d) ** 1.5 + 150 * i
        s = np.sin(2 * np.pi * np.cumsum(f) / SR) * shape(len(t), 0.005, 0.04)
        k = int(i * 0.14 * SR)
        out[k: k + len(s)] += s
    return one_shot(out, -5.0)


def hoot():
    """«Ух-ху» совы: два мягких низких тона (0.9 с)."""
    out = np.zeros(int(0.9 * SR))
    for st, f, d in ((0.0, 420, 0.22), (0.35, 380, 0.45)):
        t = np.arange(int(d * SR)) / SR
        ff = f * (1 + 0.04 * np.sin(np.pi * t / d))
        s = voice(ff, [(ff, 200, 1.0), (ff * 2, 300, 0.2)], d, breath=0.012) * shape(len(t), 0.05, 0.15)
        k = int(st * SR)
        out[k: k + len(s)] += s
    return one_shot(out, -4.0)


def pickup():
    """Подобрал предмет: два звонких 8-битных тона вверх (0.35 с)."""
    tr = Track(0.4)
    for i, m in enumerate([n("E6"), n("B6")]):
        tr.add(i * 0.07, note_sig("square", m, 0.06, (0.001, 0.12, 0.2, 0.12), duty=0.25), gain=0.4)
        tr.add(i * 0.07, note_sig("sine", m + 12, 0.04, (0.001, 0.2, 0, 0.2)), gain=0.15)
    tr.buf[-int(0.03 * SR):] *= np.linspace(1, 0, int(0.03 * SR))[:, None]
    return tr.finish(-5.0)


def quest_done():
    """Задание выполнено: арпеджио до мажора и колокольчик (1.4 с)."""
    tr = Track(1.4)
    for i, m in enumerate([n("C5"), n("E5"), n("G5"), n("C6")]):
        tr.add(i * 0.09, lowpass(note_sig("square", m, 0.12 if i < 3 else 0.5, (0.003, 0.1, 0.6, 0.3), duty=0.25), 0.3),
               gain=0.3, pan=(i - 1.5) * 0.2)
    tr.add(0.36, mix(note_sig("sine", n("C7"), 0.05, (0.002, 0.9, 0.0, 0.9)), note_sig("sine", n("G7"), 0.04,
                                                                                         (0.002, 0.5, 0, 0.5)), 0.3), gain=0.2)
    tr.buf[-int(0.15 * SR):] *= np.linspace(1, 0, int(0.15 * SR))[:, None]
    return tr.finish(-4.0)


def write(path_noext, x):
    import wave

    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path_noext + ".wav", "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path_noext + ".wav", "-c:a", "libvorbis", "-q:a", "4",
                    path_noext + ".ogg"], check=True)
    return len(x) / SR



TRACKS = (("maple_street", maple_street), ("evening_lullaby", evening_lullaby), ("bark", bark), ("meow", meow),
          ("squeak", squeak), ("chirp", chirp), ("hoot", hoot), ("pickup", pickup), ("quest_done", quest_done))

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
    os.makedirs(out, exist_ok=True)
    only = sys.argv[2:]
    for name, fn in TRACKS:
        if only and name not in only:
            continue
        secs = write(os.path.join(out, name), fn())
        print("%s: %.1f s" % (name, secs))
