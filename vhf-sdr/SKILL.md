---
description: Marine VHF SDR capture + transcription pipeline on Distant Shores II — the rtl_sdr → multi-channel-demod → vox/dsc capture → wav → ship-to-home → faster-whisper chain. Use when "no morning net text", "transcripts are gibberish", "is the SDR working", retuning the SDR, changing which channel feeds VOX or DSC, debugging silent-wav captures, or anything touching `/opt/vhf-transcriber/` on centralsk or the home `vhf-worker`. **Channel labels in filenames lie** — what's really being demoded is determined by which TCP port the capture process connects to. Always verify the port→channel mapping before trusting a wav's filename.
---

# VHF SDR capture + transcription

The boat captures marine VHF audio with an RTL-SDR dongle, demodulates 2-3 channels in parallel, gates capture by vox or DSC, ships the wavs home via Syncthing, and the 4060 GPU at home transcribes them via faster-whisper. The whole chain works — when it's silent or producing gibberish the failure is almost always at the **front** (wrong channel, dead squelch, mis-wired port), not the model.

## TL;DR diagnostic chain

When the morning-net transcript is silent/gibberish:

1. `RMS check on a recent wav` — if RMS < 200, no audio. If RMS > 5000 and max=32768, strong signal but probably noise — **check channel next**.
2. `Find the rtl_sdr cmdline` to confirm center freq + bandwidth.
3. `Find the consumer (capture.py or dsc-monitor.py) and its sdrPort` — that's the **actual channel**, not the filename.
4. Verify the channel matches what the user wants captured (morning net = ch10 at 8am Sint Maarten local, calling/distress = ch16, DSC = ch70).
5. Only if 1-4 all check out: VAD threshold / no_speech_threshold tuning in the model.

The filename label is a **lie until proven otherwise.** Both `dsc-monitor.py` (suffix `-ch16.wav`) and any continuous-record path hardcode their suffixes. The wire is the truth.

## Architecture (top-down)

```
                 ┌─────────────────────────────────────────────┐
                 │  RTL-SDR dongle on centralsk                │
                 │  rtl_sdr -f 156650000 -s 2048000 -g 40 -    │
                 │  (center 156.650 MHz, 2 MHz bandwidth)      │
                 └────────────────────┬────────────────────────┘
                                      │ raw IQ on stdout
                                      ▼
              ┌──────────────────────────────────────────────────┐
              │  sdr-receiver.py (multi-channel demodulator)     │
              │  Decimates IQ, demods 3 channels in parallel:    │
              │   • ch10  156.500 MHz  FM  → TCP :7010 (PCM)     │
              │   • ch16  156.800 MHz  FM  → TCP :7016 (PCM)     │
              │   • ch70  156.525 MHz  pwr → TCP :7070 (JSON)    │
              │  Center 156.650 chosen so RTL-SDR DC-spike       │
              │  lands between ch70 and ch16, harmless.          │
              └────────────┬─────────────────────────────────────┘
                           │ TCP fan-out
        ┌──────────────────┼──────────────────────────────────┐
        ▼                  ▼                                  ▼
┌──────────────────┐ ┌────────────────────────┐ ┌─────────────────────────────┐
│ capture.py       │ │ dsc-monitor.py         │ │ (anything else can          │
│ VOX-gated        │ │ ch70 power → triggers  │ │  consume too, e.g. live     │
│ Reads sdrPort    │ │ continuous ch16 record │ │  audio browser tap)         │
│ from config.json │ │ to dsc-recordings/     │ │                             │
│ (default 7010    │ │ filename: `-ch16.wav`  │ │                             │
│ = ch10).         │ │ (label HARDCODED)      │ │                             │
└────────┬─────────┘ └──────────┬─────────────┘ └─────────────────────────────┘
         │                      │
         ▼                      ▼
    /opt/vhf-transcriber/transcripts/  AND  dsc-recordings/<date>/HHMMSS-ch16.wav
                      │
                      │ Syncthing
                      ▼
    docker-server:/home/doug/backups/vhf-recordings/<date>/...wav
                      │ (RO bind into cruising-app-home container)
                      ▼
    cruising-app-home scanner enqueues cruising.vhf_job for each new wav
                      │ HTTP claim/done
                      ▼
    vhf-worker on 55videoserver (Windows, RTX 4060) runs faster-whisper,
    posts segments back → cruising.vhf_segment.
```

## Channel → port map (**the load-bearing fact**)

| Channel | Frequency | Use | Demod port | Common consumer |
|---|---|---|---|---|
| ch10 | 156.500 MHz | cruisers hailing / **morning net 8am local** | TCP :7010 (PCM 16 kHz s16 mono) | `ch10-recorder.service` (continuous 10-min wavs, added 2026-06-23) — also `capture.py` if run |
| ch13 | 156.650 MHz | (center freq, not a useful demod — DC spike is here) | n/a — used as LO reference | — |
| ch16 | 156.800 MHz | international distress / calling | TCP :7016 (PCM 16 kHz s16 mono) | `dsc-monitor.py` post-DSC voice recorder |
| ch70 | 156.525 MHz | DSC (digital selective calling) | TCP :7070 (JSON lines: `{power_dbfs, timestamp}`) | `dsc-monitor.py` trigger |

**If you need to capture a channel that isn't already wired, you EXTEND `sdr-receiver.py` to demod it onto a new port — you don't retune the SDR.** Retuning would break the other three consumers.

## Files (boat)

All on centralsk (192.168.22.15), all under `/opt/vhf-transcriber/`. Run as user-mode systemd under `doug`.

| File | Role |
|---|---|
| `sdr-receiver.py` | RTL-SDR multi-channel demodulator. `CENTER_HZ=156_650_000`, `CH10_HZ`, `CH16_HZ`, `CH70_HZ` constants near top. `--center` and `--gain` flags. Reads raw IQ from `rtl_sdr` subprocess, fans out to TCP ports. |
| `capture.py` | VOX-gated audio capture. Reads `sdrPort` from `config.json` (default 7010 = ch10). Triggers when RMS crosses `vox.voxThreshold` (default 0.003). Writes vox clips AND can write continuous wavs (called from main.py). |
| `dsc-monitor.py` | Watches port 7070 for DSC power activity. On detect, records ch16 voice (port 7016) to `/opt/vhf-transcriber/dsc-recordings/<date>/HHMMSS-ch16.wav`. **The `-ch16.wav` suffix is hardcoded; it's correct here.** |
| `ch10-recorder.py` | Continuous ch10 (port 7010) → `dsc-recordings/<date>/HHMMSS-ch10.wav`, 10-min rotation. Added 2026-06-23 because the morning net is on ch10 and dsc-monitor was the only consumer of the SDR fan-out — meaning **nothing was capturing ch10** until this. Runs as `ch10-recorder.service`. |
| `main.py` | Service orchestrator. Spawns sdr-receiver, capture, dsc-monitor as needed. Note: as of 2026-06-23 the running setup is NOT main.py — sdr-receiver, dsc-monitor, and ch10-recorder are all individual system services. |
| `config.json` | Active config. **`audio.sdrPort` selects which channel capture.py listens to.** `vox.voxThreshold` gates capture sensitivity. `whisper.model` was the boat-CPU fallback (now stopped in stored mode). |

systemd: `systemctl --user status vhf-transcriber.service` (it's a [[stored-boat]] CREWED-ONLY service — stopped while the boat is stored; home GPU takes over).

## Files (home)

Pipeline at home is documented in the `vhf-pipeline-home` memory — this skill stops at the wav. Briefly:
- Wavs land at `docker-server:/home/doug/backups/vhf-recordings/` via Syncthing (folder `vhf-recordings`).
- `cruising-app-home` container (port 3211) scans + enqueues + serves wavs to the worker.
- `vhf-worker` on 55videoserver runs faster-whisper on the 4060.

## Diagnostic commands

### Is the SDR even running?

```bash
ssh doug@192.168.22.15 'ps -ef | grep -E "rtl_sdr|sdr-receiver|capture\.py|dsc-monitor" | grep -v grep'
# Expect: rtl_sdr -f 156650000 ..., sdr-receiver.py, dsc-monitor.py (and capture.py when crewed)
```

### What frequency is rtl_sdr actually tuned to?

```bash
ssh doug@192.168.22.15 'ps -ef | grep rtl_sdr | grep -v grep'
# -f 156650000 = center 156.650 MHz (correct default)
```

### Which channel is capture.py listening to?

```bash
ssh doug@192.168.22.15 'grep sdrPort /opt/vhf-transcriber/config.json'
# 7010 = ch10, 7016 = ch16. Filename labels mean nothing here.
```

### Is the wav real speech, or constant noise? (the RMS-variance test)

The single-RMS check tells you "audio present or absent." It does NOT tell you "speech or noise" — radio noise can be just as loud as speech. To distinguish, look at RMS over short windows. **Speech swings dramatically** (RMS ~200 in silence gaps → ~6000+ during transmission). **Constant noise is flat** (RMS within ~5% across all windows). If RMS is uniform AND `max=32768` every window, you're seeing a saturated/clipped front-end — antenna disconnected, gain too high, or upstream RF chain broken.

```bash
F="/home/doug/backups/vhf-recordings/<date>/<file>.wav"
ssh doug@192.168.20.19 "python3 -c \"
import wave, audioop
w = wave.open('$F','rb'); sr=w.getframerate(); sw=w.getsampwidth()
data=w.readframes(w.getnframes())
chunk=sr*3*sw
for i in range(0, len(data), chunk):
    c=data[i:i+chunk]
    if len(c)<chunk: break
    print(f't={i//(sr*sw):>2}-{(i//(sr*sw))+3:>2}s rms={audioop.rms(c,sw):>6} max={audioop.max(c,sw):>5}')
\""
```

Worked example, 2026-06-23 ch10 wav (front-end was broken):
```
t= 0- 3s rms= 10194 max=32768
t= 3- 6s rms= 10068 max=32768
t= 6- 9s rms= 10088 max=32768
...
```
Uniform RMS within 3% across the whole clip + every window clipping = **RF chain issue**, not a software/channel/VAD problem. Software pipeline is fine; antenna or gain is broken.

### Is a wav silent, noisy, or real speech?

```bash
ssh doug@192.168.20.19 'python3 -c "
import wave, audioop
w = wave.open(\"/home/doug/backups/vhf-recordings/<date>/<file>.wav\", \"rb\")
d = w.readframes(w.getnframes())
print(\"rms=\", audioop.rms(d, w.getsampwidth()), \"max=\", audioop.max(d, w.getsampwidth()))
"'
```

Interpretation:
- `rms < 200` → silence. SDR off, port not connected, or wrong channel with no carrier.
- `rms > 5000`, `max = 32768` → strong signal but **clipping**. Either real speech with AGC fight, or RF noise / squelch failure. Listen to the clip.
- `200 < rms < 5000`, `max ≪ 32768` → moderate signal, plausibly real speech. Most likely the model is the issue (VAD too aggressive, no_speech_threshold too high).

### Confirm where the wavs are coming from

```bash
# Are they vox-triggered (capture.py) or continuous-recorded (capture.py main.py) or dsc-triggered (dsc-monitor)?
ssh doug@192.168.22.15 'ls -la /opt/vhf-transcriber/dsc-recordings/$(date +%Y-%m-%d)/ | head'
ssh doug@192.168.22.15 'ls -la /opt/vhf-transcriber/transcripts/ | head'
# Compare sizes:
#   - 10-min file (~19.2 MB) → continuous-recorded by main.py or dsc-monitor
#   - tens-of-seconds → vox-triggered clip
```

### What's in the home queue?

```bash
ssh doug@192.168.20.19 'docker exec dk400-postgres psql -U homelab_admin -d dk400 -c "
SELECT state, count(*) FROM cruising.vhf_job GROUP BY state ORDER BY state"'
```

### Sample text from a recent transcript

```bash
ssh doug@192.168.20.19 'docker exec dk400-postgres psql -U homelab_admin -d dk400 -c "
SELECT seq, LEFT(text, 100) FROM cruising.vhf_segment
WHERE session_id = (SELECT id FROM cruising.vhf_session
                    WHERE source_wav_relpath LIKE '\''$(date +%Y-%m-%d)/%'\''
                    ORDER BY started_at DESC LIMIT 1)
ORDER BY seq LIMIT 15"'
```

## Common failure modes (in observed order of likelihood)

### "Transcripts are gibberish, all the same phrase"

**Cause:** wav is silent or pure noise; Whisper hallucinates either canned training phrases ("Thanks for watching!", "Subscribe!") or echoes the `initial_prompt` ("Vessel names, channel numbers..."). VAD is off so Whisper has no way to refuse.

**Diagnosis order:**
1. RMS check on the wav (above).
2. If RMS is high but it sounds like noise — **wrong channel**. Check the consumer's port.
3. If channel is right and RMS is reasonable — turn VAD back on with `VHF_VAD=1 VHF_VAD_THRESHOLD=0.2` on the worker.

### "Strong signal but no morning net text"

**Cause we hit 2026-06-20:** the dsc-monitor pipeline records ch16 (port 7016) — **the morning net is on ch10**. dsc-monitor never sees ch10.

**Fix:** capture.py with vox listening on port 7010 captures ch10. Make sure capture.py is running and `config.json` has `audio.sdrPort: 7010`.

### "rtl_sdr won't start / dies repeatedly"

Usually USB/dongle issue. Reseat. Check `dmesg`. RTL-SDRs sometimes get into a stuck state — `usb-reset` or replug.

### "sdr-receiver running but a consumer can't connect to its port"

```bash
ssh doug@192.168.22.15 'sudo ss -tlnp | grep -E "7010|7016|7070"'
# All three should be listening.
```

If one is missing, sdr-receiver didn't enable that demod (check its `--enable-chXX` flag or constants). It only fans out the channels its constants enable.

### "Wav files exist but home isn't getting them"

Syncthing. Check `boat→home` Syncthing folder `vhf-recordings` is unpaused, no errors. The `homelab-architecture` skill has the Syncthing query.

## Retune procedure (rare)

Don't retune unless you really need to. The center 156.650 MHz was deliberately chosen so the RTL-SDR's persistent DC-offset spike lands between ch70 and ch16 (at ~156.6625 MHz) in dead spectrum. Move the center and you risk putting the DC spike on top of a useful channel.

If you do need to retune (e.g. to add a regional channel):
1. Pick a new center such that all desired channels are within ±1 MHz AND the DC spike (= the new center) is in dead spectrum.
2. Edit `CENTER_HZ` and add `CHxx_HZ` constants in `sdr-receiver.py`.
3. Implement the new channel's offset-down + decimate + demod stage.
4. Add a new TCP port for the new channel; update the channel→port table in this skill.
5. Restart sdr-receiver. Verify all old ports still serve sane data.

## Recovery checklist

When the morning-net pipeline goes silent:

- [ ] RTL-SDR alive: `ps | grep rtl_sdr` (and check cmdline freq)
- [ ] sdr-receiver alive: `ps | grep sdr-receiver` (and check listening on 7010/7016/7070)
- [ ] capture.py alive and reading the right port (ch10 for morning net): `grep sdrPort /opt/vhf-transcriber/config.json`
- [ ] Recent wavs on disk: `ls /opt/vhf-transcriber/dsc-recordings/$(date +%Y-%m-%d)/`
- [ ] RMS on a recent wav is plausible (300-8000) — not silent, not clipped
- [ ] Syncthing pushed them home: `ls /home/doug/backups/vhf-recordings/$(date +%Y-%m-%d)/` on docker-server
- [ ] cruising-app-home scanner enqueued: `SELECT count(*) FROM cruising.vhf_job WHERE state='queued'`
- [ ] vhf-worker daemon running on 55videoserver: `schtasks /query /tn VhfDaemon`
- [ ] Recent done jobs with non-zero segments: `SELECT count(*) FROM cruising.vhf_segment WHERE created_at > NOW() - INTERVAL '1 hour'`

## Related

- `[[vhf-pipeline-home]]` — the home-side architecture: cruising-app-home + vhf-worker + the three bugs found 2026-06-19 (CUDA DLLs, VAD threshold, words_jsonb stringify).
- `homelab-centralsk` skill — the boat host this runs on, user-mode systemd quirks, golden snapshots.
- `homelab-architecture` skill — the Syncthing transport boat→home.
- `stored-boat` skill — why `vhf-transcriber.service` is stopped while stored (home GPU takes over).
- `central-signalk` skill — different N2K pipeline, unrelated but sometimes confused.
