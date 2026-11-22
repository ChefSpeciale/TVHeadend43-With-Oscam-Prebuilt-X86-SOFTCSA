# Tvheadend 4.3 with OSCam – prebuilt for x86-64

A single Docker image that bundles **Tvheadend 4.3** (the [thealhu](https://hub.docker.com/r/thealhu/tvheadend) build with ICAM support) and **OSCam 2.26.11-11991**, preconfigured so that ICAM (CSA-ALT-3) channels can be descrambled by Tvheadend.

Both services run inside one container (managed by s6-overlay). Tvheadend talks to OSCam over the DVB API on `127.0.0.1:9001`.

## Why this exists

Getting ICAM working with Tvheadend + OSCam needs several settings that are easy to miss. When any of them is wrong, OSCam reports `found` for every ECM, but Tvheadend produces no picture, often without logging an error. This image has them all set:

| Component | Setting | Why |
|---|---|---|
| Tvheadend | thealhu build + patched `libdvbcsa` (`dvbcsa_bs_key_set_ecm`) | Applies the ICAM key schedule in software |
| Tvheadend | CA client `capmt`, mode *OSCam net protocol (rev >= 10389)*, CW mode *Extended (OE 2.2), mode follows key* | Accepts the CSA-ALT algorithm sent by OSCam |
| OSCam | built with `WITH_EXTENDED_CW` | Required for the extended CW API |
| OSCam | `[dvbapi] extended_cw_api = 1` | Sends `CA_SET_DESCR_MODE` with algo CSA-ALT to Tvheadend |
| OSCam | `disablecrccws_only_for = 098C:000000;09C4:000000;098D:000000` (global **and** per reader) | **Most important one.** By default OSCam "fixes" CW checksum bytes 3 and 7. With ICAM those bytes are part of the real key, so the fix corrupts every CW |

## Requirements

- x86-64 (amd64) Linux host with Docker and Docker Compose. No AVX/AVX2 required, so older CPUs work too.
- DVB tuner(s) with working drivers on the **host** (`/dev/dvb` must exist).
- Not supported: ARM (Raspberry Pi, Apple Silicon), 32-bit x86, or Docker Desktop on Windows/macOS (you can't pass DVB devices through to the container there).

## Quick start

### Option A: use the prebuilt image (`.tar` from Releases)

```bash
docker load -i tvheadend-oscam-icam.tar
git clone https://github.com/ChefSpeciale/TVHeadend43-With-Oscam-Prebuild-X86.git
cd TVHeadend43-With-Oscam-Prebuild-X86
docker compose up -d
```

### Option B: build it yourself

```bash
git clone https://github.com/ChefSpeciale/TVHeadend43-With-Oscam-Prebuild-X86.git
cd TVHeadend43-With-Oscam-Prebuild-X86
docker compose up -d --build
```

Stop any other Tvheadend or OSCam instance on the host first; otherwise the ports and tuners will clash.

## After the first start

| Service | URL |
|---|---|
| Tvheadend web UI | `http://<host>:9981` |
| HTSP (Kodi etc.) | `<host>:9982` |
| OSCam web UI | `http://<host>:8888` |

1. **Configure the reader.** Open the OSCam web UI → *Readers* → `ADDREADERHERE`. Fill in `device`, `user`, `password` and (for newcamd) `key`, then rename it if you like. The ICAM settings (`disablecrccws_only_for`, CAID `098D`) are already in place. If you add another reader for ICAM, add the same `disablecrccws_only_for` line to it.
2. **Check the tuners in Tvheadend.** The included tuner configuration was made for 16 tuners on **Unicable II (EN50607)**. On other hardware or a different dish setup, go to *Configuration → DVB Inputs → TV adapters* and set up your own tuners/LNB, then assign them to the existing networks. Networks, muxes and channels are kept.

## Configuration and persistence

All configuration lives in the named volume `tvheadend-config`, mounted at `/config`:

```
/config          Tvheadend configuration
/config/oscam    OSCam configuration (oscam.conf, oscam.server, oscam.user, oscam.dvbapi, ...)
```

On first start Docker fills the volume with the defaults from the image. Changes you make after that are kept across restarts and image updates.

> **Tip:** when OSCam rewrites its config through the web UI, it may drop settings it considers defaults. If ICAM stops working after editing settings, check that `extended_cw_api = 1` and `disablecrccws_only_for` are still in `/config/oscam/oscam.conf` and `oscam.server`.

## ⚠️ Security

This image is meant for use **inside a trusted home network**:

- Tvheadend has **no login**. Everyone who can reach port 9981 has full admin rights.
- The OSCam web UI accepts connections from **any IP** and has **no password**. Anyone who can reach port 8888 can view and change your reader credentials.

Never forward these ports to the internet. To lock things down, add a user in Tvheadend (*Configuration → Users*) and set `httpuser`/`httppwd` and a narrower `httpallowed` in `/config/oscam/oscam.conf`.

## Troubleshooting

- **OSCam shows `found`, but there's no picture.** Check `disablecrccws_only_for` (see above). This is the most common cause.
- **`descrambler: cannot decode packets`.** Make sure OSCam announces `e1mk` in the Tvheadend log (`Connected to server 'OSCam ...; e1mk'`). If it shows nothing or `e2`, check `extended_cw_api = 1`.
- **OSCam log:** `docker exec tvheadend tail -f /var/log/oscam.log`

## Repository layout

```
Dockerfile            Multi-stage build: OSCam (Alpine/musl) + thealhu/tvheadend
docker-compose.yml    Example deployment
oscam-src/            OSCam source (2.26.11-11991, commit efe064ec) incl. config.h build options
config/               Default Tvheadend configuration
config/oscam/         Default OSCam configuration
rootfs/               s6-overlay service definition for OSCam
```

## Licenses

- OSCam is licensed under the GPL-3.0 (see `oscam-src/COPYING`).
- Tvheadend is licensed under the GPL-3.0; the base image is [thealhu/tvheadend](https://hub.docker.com/r/thealhu/tvheadend).

This project only packages and configures these components. Make sure you're entitled to receive the channels you descramble.
