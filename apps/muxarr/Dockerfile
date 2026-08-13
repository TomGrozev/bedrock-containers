# syntax=docker/dockerfile:1
# Hardened, rootless re-layer of ghcr.io/kirovair/muxarr onto Wolfi.
# Designed to run under a read-only root filesystem with all capabilities dropped.
# Upstream source: https://github.com/KirovAir/muxarr (.NET 10 / ASP.NET Core Blazor,
# Debian 12 / glibc based upstream image).

# VERSION is provided as a build arg by docker-bake.hcl (its `variable "VERSION"`),
# so the bake file is the single source of truth.
ARG VERSION
FROM ghcr.io/kirovair/muxarr:${VERSION} AS upstream

# mkvtoolnix (mkvmerge, mkvpropedit) has NO Wolfi/Chainguard apk package (verified
# against wolfi-dev/os). Instead of building it from source, install mkvtoolnix into
# a dedicated Debian Trixie stage and lift the built binaries out, together with
# their COMPLETE glibc shared-library closure (via ldd) -- including libc/ld-linux
# themselves.
#
# Why a dedicated Debian Trixie stage (not the muxarr `upstream` image):
# The upstream image pins whatever Debian release the upstream maintainers happen to
# use (currently bookworm). Bookworm ships `mkvtoolnix 77.0` against `qtbase 6.4.2`,
# which has unfixed High/Critical CVEs (CVE-2023-51714, CVE-2024-36048, ...). Trixie
# ships `mkvtoolnix 92.0` against `qtbase 6.8.2`, which has all of those patches.
# Extracting from our own Debian Trixie stage -- rather than the muxarr upstream
# image -- decouples mkvtoolnix's CVE posture from upstream's Debian pin.
#
# The closure is kept in a private directory and the binaries are invoked via that
# private dynamic linker directly (`ld-linux... --library-path <private-dir>
# <binary>`), NOT via a global LD_LIBRARY_PATH or by relying on the binary's baked-in
# PT_INTERP path (which points at a Debian path Wolfi doesn't have). This fully
# isolates Debian's glibc from Wolfi's own -- it cannot interfere with the .NET
# runtime or anything else in the image.
FROM debian:trixie-slim AS mkvtoolnix-source
RUN apt-get update && apt-get install -y --no-install-recommends mkvtoolnix \
    && rm -rf /var/lib/apt/lists/*

FROM mkvtoolnix-source AS mkvtoolnix-extract
RUN set -eu; \
    mkdir -p /extract/libexec /extract/lib; \
    for bin in mkvmerge mkvpropedit; do \
      src="$(command -v "$bin")"; \
      cp "$src" "/extract/libexec/$bin.real"; \
    done; \
    for bin in mkvmerge mkvpropedit; do \
      src="$(command -v "$bin")"; \
      for lib in $(ldd "$src" | grep -oE '/[^ ]+\.so[0-9.]*'); do \
        cp -n "$lib" "/extract/lib/$(basename "$lib")" 2>/dev/null || true; \
      done; \
    done

FROM cgr.dev/chainguard/wolfi-base:latest AS final

# Runtime defaults mirror upstream (ASPNETCORE_HTTP_PORTS is the .NET 8+ shorthand for
# HTTP-only port binding, matching upstream's own Dockerfile). HOME points into the
# writable /tmp mount so ASP.NET Core's Data Protection key ring has somewhere to write
# (keys are ephemeral across restarts under a read-only root fs -- see README).
ENV ASPNETCORE_HTTP_PORTS=8183 \
    TZ=UTC \
    HOME=/tmp/bedrock/home
LABEL org.opencontainers.image.documentation="https://github.com/TomGrozev/bedrock-containers/blob/master/apps/muxarr/SECURITY.md"

# Runtime deps (glibc, matching upstream's Debian base):
#   aspnet-10-runtime - ASP.NET Core 10 runtime (Muxarr targets net10.0)
#   ffmpeg-8.1         - ffmpeg/ffprobe (Wolfi-native build; app resolves these as bare
#                        $PATH lookups, confirmed in Muxarr.Core/FFmpeg/FFmpeg.cs)
#   ca-certificates    - TLS trust
#   tini               - PID 1 init / signal forwarding
#   tzdata             - timezone database
RUN apk add --no-cache \
    aspnet-10-runtime \
    ffmpeg-8.1 \
    ca-certificates \
    tini \
    tzdata

# mkvtoolnix: install the isolated glibc closure extracted above, then generate thin
# wrapper scripts that invoke the private dynamic linker directly with --library-path
# pointed at the private lib dir. `mkvmerge`/`mkvpropedit` bare names must resolve on
# $PATH (confirmed in Muxarr.Core/MkvToolNix/*.cs) -- the wrappers provide that.
COPY --from=mkvtoolnix-extract /extract/libexec/ /usr/local/libexec/mkvtoolnix/
COPY --from=mkvtoolnix-extract /extract/lib/ /usr/local/lib/mkvtoolnix/
RUN set -eu; \
    mkdir -p /usr/local/bin; \
    chmod 0755 /usr/local/libexec/mkvtoolnix/*; \
    interp="$(find /usr/local/lib/mkvtoolnix -maxdepth 1 -name 'ld-linux-*.so*' | head -n1)"; \
    if [ -z "$interp" ]; then echo "mkvtoolnix-extract: no ld-linux interpreter found in closure" >&2; exit 1; fi; \
    for bin in mkvmerge mkvpropedit; do \
      printf '#!/usr/bin/env sh\nexec "%s" --library-path /usr/local/lib/mkvtoolnix "/usr/local/libexec/mkvtoolnix/%s.real" "$@"\n' "$interp" "$bin" > "/usr/local/bin/$bin"; \
      chmod 0755 "/usr/local/bin/$bin"; \
    done

# Bring the published .NET app, owned by the runtime user. Upstream's own entrypoint.sh
# only chowns /app for READ access (no runtime writes there) -- confirmed by reading it;
# the only writes are /data (SQLite db) and /media (in-place file mutation).
COPY --chown=65532:65532 --from=upstream /app /app
WORKDIR /app

# Persistent / stateful writable dirs need their own mounts (see README).
RUN mkdir -p /data /media \
    && chown -R 65532:65532 /data /media

COPY --chown=65532:65532 entrypoint.sh /app/entrypoint.sh
RUN chmod 0755 /app/entrypoint.sh

USER 65532:65532
ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
CMD ["dotnet", "Muxarr.Web.dll"]
