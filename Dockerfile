# Tvheadend (thealhu build with ICAM support) + OSCam 2.26.11-11991 in a single image

# --- Build OSCam for Alpine/musl (same base as the Tvheadend image) ---
FROM alpine:3.21 AS oscam-build
RUN apk add --no-cache build-base linux-headers
WORKDIR /src
COPY oscam-src/ ./
# config.h holds the build options (incl. WITH_EXTENDED_CW, required for ICAM)
RUN make -j"$(nproc)" \
 && install -m755 "$(ls Distribution/oscam-* | grep -v '\.debug$')" /oscam \
 && /oscam -V | grep -E 'Version|extended CW'

# --- Final image ---
FROM thealhu/tvheadend@sha256:9e8681011607af71fa5935b2ed1f69ac217a4236a1cea53c4fdedeeb8be82f11
COPY --from=oscam-build /oscam /usr/local/bin/oscam
# s6 service svc-oscam (runs next to svc-tvheadend, which waits for it)
COPY rootfs/ /
# Default configuration: Tvheadend in /config, OSCam in /config/oscam
# (reader credentials are empty; fill them in via the OSCam web UI on port 8888)
COPY config/ /config/
EXPOSE 8888
