# WFM - Web Film Manager

Self-hosted media project manager built for a school film program. Students
upload footage, edit in the browser with [FilmCraft](https://github.com/storytold/filmcraft),
and queue renders on the server. Teachers manage accounts, roles and the audit log.

## Layout

- `server/` - Rust (axum) backend: auth, projects, file API, render queue, audit
- `lib/` - Flutter web app, embedded into the server binary
- `filmcraft/` - vendored FilmCraft release + `wfm.html` host page (locks, media bin, saves)
- `server/migrations/{sqlite,postgres}/` - plain `.sql` migrations, applied in filename order
- `landing/` - small standalone landing page (optional)
- `scripts/` - `fetch-filmcraft.sh`, `build-web.sh`

## Quick start (Docker)

```sh
cp .env.example .env   # set real secrets
docker compose up --build
```

This runs RustFS (S3) on :9000 and WFM on :8080. Open http://localhost:8080
and create the owner account.

## Quick start (dev)

```sh
./scripts/build-web.sh          # builds the Flutter app into server/web/app
cd server && cargo run          # sqlite + local media dir by default
```

The app is at `/app/`, the editor bridge at `/filmcraft/wfm.html?project=<id>`.

## Configuration

Everything is a flag or env var (`wfm --help`):

- `WFM_DB` - `sqlite:<path>` (default) or `postgres://...` (build with `--features postgres`)
- `WFM_MEDIA` - `s3` or `local`; S3 settings via `WFM_S3_*`. Any S3-compatible
  store works: RustFS, MinIO, AWS, Backblaze
- `WFM_RENDER_WORKERS` / `WFM_LOCAL_RENDERS` - local ffmpeg workers
- `WFM_FFMPEG` / `WFM_FFPROBE` - binary paths
- `WFM_WEB_DIR` / `WFM_FILMCRAFT_DIR` - serve frontend from disk instead of embedded
- `WFM_MAX_UPLOAD_MB`, `WFM_SESSION_DAYS`, `WFM_LOCK_TTL`, `WFM_SECURE_COOKIES`

### Databases

Swap engines by pointing `WFM_DB` at another URL. All data access goes through
the `Db` trait (`server/src/store.rs`); migrations are plain `.sql` files under
`server/migrations/<dialect>/` applied in filename order. To add a backend,
implement `Db` and register it in `store::connect`.

### Media storage

`WFM_MEDIA=s3` talks S3 to any compatible service (RustFS is the default in
compose). `WFM_MEDIA=local` keeps files under `WFM_MEDIA_PATH`. Because both the
database and the media are external, a reinstall only needs the DB dump and the
bucket contents.

### Remote render nodes

Create a node under Manage > Render nodes, then on the worker machine:

```sh
wfm --worker http://server:8080 <token> <name>
```

The node polls for jobs, downloads inputs, runs ffmpeg, and uploads the export.

## Roles

`student` < `mod` < `teacher` < `admin` < `owner`. Each account belongs to the
tree of whoever created it; managers only see their own subtree. The first
account created at `/api/setup` is the owner.

## Editing

FilmCraft is pinned in `filmcraft/VERSION` and fetched as a release bundle
(`./scripts/fetch-filmcraft.sh`). `filmcraft/wfm.html` is the host page: it
acquires the project edit lock, serves the media bin, and stores the project as
`project.fcproj` in project storage. Projects are locked while open; a second
tab gets a take-over prompt.

## Testing

```sh
cd server && cargo test     # unit tests (paths, ranges, roles, ffmpeg args)
flutter test                # widget tests
```

## License

AGPL-3.0
