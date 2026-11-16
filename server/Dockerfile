FROM rust:1-slim AS build
WORKDIR /src
COPY server/ ./server/
WORKDIR /src/server
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg curl unzip ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /src/server/target/release/wfm /app/wfm
COPY filmcraft/ /app/filmcraft/
RUN test -f /app/filmcraft/dist/index.html || (curl -fsSL "https://github.com/storytold/filmcraft/releases/download/v$(cat /app/filmcraft/VERSION)/filmcraft-web-$(cat /app/filmcraft/VERSION).zip" -o /tmp/fc.zip && mkdir -p /tmp/fx && unzip -q /tmp/fc.zip -d /tmp/fx && mkdir -p /app/filmcraft/dist && mv /tmp/fx/filmcraft-web-*/. /app/filmcraft/dist/ && rm -rf /tmp/fx /tmp/fc.zip)
ENV WFM_ADDR=0.0.0.0:8080 WFM_DATA=/data WFM_FILMCRAFT_DIR=/app/filmcraft
EXPOSE 8080
VOLUME /data
ENTRYPOINT ["/app/wfm"]
