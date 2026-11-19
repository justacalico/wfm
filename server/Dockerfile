FROM ghcr.io/cirruslabs/flutter:stable AS web
WORKDIR /app
COPY pubspec.yaml pubspec.lock l10n.yaml ./
COPY lib/ ./lib/
COPY assets/ ./assets/
COPY web/ ./web/
RUN flutter pub get && flutter build web --release --base-href /app/ --no-web-resources-cdn

FROM rust:1-slim AS filmcraft
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates curl && rm -rf /var/lib/apt/lists/*
RUN rustup target add wasm32-unknown-unknown \
 && curl -fsSL https://github.com/rustwasm/wasm-bindgen/releases/download/0.2.129/wasm-bindgen-0.2.129-x86_64-unknown-linux-musl.tar.gz | tar -xz -C /opt \
 && ln -s /opt/wasm-bindgen-0.2.129-x86_64-unknown-linux-musl/wasm-bindgen /usr/local/bin/wasm-bindgen
WORKDIR /fc
COPY filmcraft/VERSION /wfm/VERSION
COPY filmcraft/patches/ /wfm/patches/
RUN git clone --depth 1 --branch "v$(cat /wfm/VERSION)" https://github.com/storytold/filmcraft /fc/src
WORKDIR /fc/src
RUN for p in /wfm/patches/*.patch; do git apply "$p"; done && cargo xtask web \
 && cargo build --release -p filmcraft-cli

FROM rust:1-slim AS build
WORKDIR /src
COPY server/ ./server/
COPY --from=web /app/build/web ./server/web/app/
WORKDIR /src/server
RUN cargo build --release --features postgres

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates ffmpeg && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 10001 --create-home wfm && mkdir -p /data && chown wfm:wfm /data
WORKDIR /app
COPY --from=build /src/server/target/release/wfm /app/wfm
COPY --from=filmcraft /fc/src/target/release/filmcraft-cli /usr/local/bin/filmcraft-cli
COPY filmcraft/ /app/filmcraft/
COPY --from=filmcraft /fc/src/target/web/dist /app/filmcraft/dist
ENV WFM_ADDR=0.0.0.0:8080 WFM_DATA=/data WFM_FILMCRAFT_DIR=/app/filmcraft WFM_FILMCRAFT_CLI=/usr/local/bin/filmcraft-cli
EXPOSE 8080
VOLUME /data
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:$${WFM_ADDR##*:}/api/health" || exit 1
# Fix up /data ownership (upgrades may have a root-owned volume) then drop to
# the unprivileged wfm user; setpriv execs so the server stays pid 1.
ENTRYPOINT ["sh", "-c", "chown -R wfm:wfm /data; exec setpriv --reuid=wfm --regid=wfm --init-groups /app/wfm"]
