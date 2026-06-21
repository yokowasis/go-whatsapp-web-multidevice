# AGENTS

Agent instructions for `go-whatsapp-web-multidevice`.

Go WhatsApp Web Multi-Device is a Go 1.25.5 WhatsApp Web API server with REST and MCP SSE modes. It uses whatsmeow sessions, Fiber, plain Vue 3 modules, and SQLite-backed chat/session storage by default.

## Start Here

- Read [CLAUDE.md](CLAUDE.md) first for architecture map and core pitfalls.
- Use [readme.md](readme.md) for runtime, Docker, and environment setup details.
- For payload and integration specifics, link out to:
  - [docs/webhook-payload.md](docs/webhook-payload.md)
  - [docs/chatwoot.md](docs/chatwoot.md)

## Build, Run, Test

Run commands from `src/` unless noted.

- `go run . rest` (REST mode, default port 3000)
- `go run . mcp` (MCP mode, default port 8080)
- `go build -o whatsapp`
- `go test ./...`
- `go vet ./...`
- `go mod tidy`
- `docker compose up --build`

Important: REST and MCP cannot run simultaneously in one process.

## Project Structure

```text
go-whatsapp-web-multidevice/
|-- src/                         # Go module root; run Go commands here
|   |-- main.go                  # go:embed views, then cmd.Execute
|   |-- cmd/                     # Cobra root, rest, mcp, global app wiring
|   |-- config/                  # Mutable package globals bound from flags/env
|   |-- domains/                 # Interfaces and DTOs; see child AGENTS
|   |-- usecase/                 # Business orchestration; see child AGENTS
|   |-- validations/             # ozzo-validation plus table tests
|   |-- ui/                      # REST, MCP, websocket adapters
|   |-- infrastructure/
|   |   |-- whatsapp/            # Device manager, events, presence pulse, JID utilities
|   |   |-- chatstorage/         # chat/message/device SQL repository
|   |   `-- chatwoot/            # Chatwoot REST sync and direct PG import
|   |       `-- pgimport/        # Direct Chatwoot Postgres importer; see child AGENTS
|   |-- views/                   # Embedded Vue 3 plain JS UI
|   |-- statics/                 # Runtime media, QR codes, send items
|   `-- storages/                # Runtime SQLite DBs and history dumps
|-- docs/                        # OpenAPI, webhook payload docs, SDK config
|-- docker/                      # Multi-stage Alpine image and entrypoint
|-- gallery/                     # Static screenshots and project images
`-- .github/workflows/           # Docker publish, release, latest promotion
```

## Where to Look

| Task | Location | Notes |
|------|----------|-------|
| Add message type | `src/domains/send/`, `src/usecase/send.go`, `src/ui/rest/send.go` | REST is primary; MCP support is selective. |
| Add quoted reply support | `src/domains/send/`, `src/usecase/send.go`, `src/views/components/Send*.js` | Optional `reply_message_id`; use device-scoped quote lookup. |
| Add REST endpoint | `src/ui/rest/`, `src/usecase/`, `src/domains/` | Handler parses request, usecase validates/executes, domain owns DTO/interface. |
| Add MCP tool | `src/ui/mcp/` | Register in `Add*Tools`; resolve a device with `helpers.ContextWithDefaultDevice`. |
| Handle WhatsApp event | `src/infrastructure/whatsapp/event_*.go` | Register the concrete event in `event_handler.go`. |
| Presence behavior | `src/infrastructure/whatsapp/event_handler.go`, `presence_pulse.go`, `src/cmd/helpers.go` | Connect-time and scheduled pulse presence. |
| Add chat storage method | `src/domains/chatstorage/interfaces.go`, `sqlite_repository.go`, `chatstorage_wrapper.go` | Update domain, repository, and wrapper together. |
| Add DB migration | `src/infrastructure/chatstorage/sqlite_repository.go` `getMigrations()` | Append only. Current list has 29 migrations. |
| Add UI component | `src/views/components/`, `src/views/index.html` | Plain JS modules, no `.vue` single-file components. |
| Device management | `src/infrastructure/whatsapp/device_manager.go` | Central registry and purge/load/create logic. |
| Chatwoot integration | `src/infrastructure/chatwoot/` and `src/ui/rest/chatwoot.go` | REST sync, public webhook, optional direct Postgres import. |
| Direct Chatwoot import | `src/infrastructure/chatwoot/pgimport/` | Direct Chatwoot schema writes; see child AGENTS. |
| Chatwoot link/retry state | `src/infrastructure/chatstorage/sqlite_repository.go`, `src/infrastructure/whatsapp/webhook_forward.go` | Message links, read/delete sync, and persistent forward retries. |
| CLI flags / config | `src/cmd/root.go`, `src/config/settings.go`, `src/.env.example` | Flags and env mutate config package globals. |
| Shared helpers | `src/pkg/utils/`, `src/pkg/error/`, `src/pkg/sqlite/` | Utilities, aliased package errors, and CGO/purego SQLite driver selection. |
| Docker/release | `docker/golang.Dockerfile`, `.github/workflows/*.yaml` | Multi-arch Docker, tag/manual workflows, generated GoReleaser configs. |

## Code Map

| Symbol | Type | Location | Role |
|--------|------|----------|------|
| `cmd.Execute` | function | `src/cmd/root.go` | Stores embedded views and runs Cobra root command. |
| `initApp` | function | `src/cmd/root.go` | Creates folders, DBs, WhatsApp client, device manager, repositories, and usecases. |
| `DeviceManager` | struct | `src/infrastructure/whatsapp/device_manager.go` | Owns active device registry and persisted device records. |
| `DeviceInstance` | struct | `src/infrastructure/whatsapp/device_instance.go` | Wraps per-device ID, JID, client, state, and storage. |
| `IChatStorageRepository` | interface | `src/domains/chatstorage/interfaces.go` | Storage contract for chats, messages, edits, calls, stats, schema, and device records. |
| `SQLiteRepository` | struct | `src/infrastructure/chatstorage/sqlite_repository.go` | Implements chat storage, Chatwoot link/retry state, and inline migrations. |
| `deviceChatStorage` | wrapper | `src/infrastructure/whatsapp/chatstorage_wrapper.go` | Injects or enforces device scoping for event-side storage access. |
| `StartPresencePulseScheduler` | function | `src/infrastructure/whatsapp/presence_pulse.go` | Periodically marks connected devices available, then unavailable. |
| `StartChatwootForwardRetryWorker` | function | `src/infrastructure/whatsapp/webhook_forward.go` | Replays queued WhatsApp-to-Chatwoot forward failures. |
| `NormalizeJIDFromLID` | function | `src/infrastructure/whatsapp/jid_utils.go` | Converts `@lid` JIDs to phone JIDs where whatsmeow can resolve them. |
| `pgimport.Importer` | struct | `src/infrastructure/chatwoot/pgimport/conn.go` | Direct Chatwoot Postgres importer for historical messages. |
| `DeviceMiddleware` | middleware | `src/ui/rest/middleware/device.go` | Resolves `X-Device-Id` or `device_id` and injects device context. |
| `ContextWithDefaultDevice` | helper | `src/ui/mcp/helpers/context.go` | MCP equivalent of REST device middleware for default/only device. |

## Architecture Rules

- Keep clean boundaries: `domains` (contracts) -> `usecase` (business logic) -> `ui` (REST/MCP handlers).
- Keep 1:1 mapping pattern when adding features: domain + usecase + validation + handler.
- Do not place business logic in `domains`.
- Process-wide helpers in `cmd/helpers.go` guard auto-reconnect and presence-pulse startup for both REST and MCP.
- Usecases validate first, then obtain the device/client from context, then call whatsmeow/storage.
- Device-scoped REST routes must pass `whatsapp.ContextWithDevice(c.UserContext(), getDeviceFromCtx(c))`.
- MCP handlers do not receive `X-Device-Id`; they resolve the default/only device via `ContextWithDefaultDevice`.

## Critical Data Rules

- Do not confuse device alias with WhatsApp JID.
- For DB chat/message scoping, use WhatsApp JID in non-AD form (`ToNonAD().String()`).
- Always scope chat/message storage operations with `device_id`.
- Normalize `@lid` JIDs before DB operations (`NormalizeJIDFromLID`).

## High-Risk Change Areas

- If you add methods to `IChatStorageRepository`, update both wrappers:
  - `infrastructure/whatsapp/chatstorage_wrapper.go`
  - `infrastructure/chatstorage/device_repository.go`
- For SQLite migrations, only append new migrations in `getMigrations()`; never reorder or insert in the middle.
- Keep the receipt forwarding duplicate-prevention behavior (`Device == 0` check) intact.

## Adding Env Variables and Flags

When adding a new setting, keep env key, config field, and CLI flag aligned.

1. Add default config in `src/config/settings.go`.
2. Read env value in `initEnvConfig()` in `src/cmd/root.go`.
3. Add CLI flag in `initFlags()` in `src/cmd/root.go`.
4. Add sample key in `src/.env.example`.
5. Add tests for behavior changes in the touched package.

Naming pattern:

- Env variable: `UPPER_SNAKE_CASE` (example: `CHATWOOT_SKIP_UNSUPPORTED_MESSAGES`).
- Viper key in code: `lower_snake_case` (example: `chatwoot_skip_unsupported_messages`).
- CLI flag: `kebab-case` (example: `--chatwoot-skip-unsupported-messages`).

Type handling pattern in `initEnvConfig()`:

- Bool/int: use `viper.IsSet("key")` before assigning, so explicit `false` and `0` are honored.
- String: assign when non-empty unless empty is a meaningful runtime value.
- Slice values: parse comma-separated env values only where existing code uses that pattern.

Documentation rule:

- Update [readme.md](readme.md) environment variable table for user-facing settings.
- If behavior impacts payload/integration semantics, also update [docs/webhook-payload.md](docs/webhook-payload.md) or [docs/chatwoot.md](docs/chatwoot.md).

## Conventions

- Go commands run from `src/`; the repo root is not the Go module root.
- Local runtime paths are relative to process cwd, so direct local runs should start from `src/`.
- Config priority is CLI flags > environment variables > `.env` file (Cobra flags, then env/Viper, then `.env` loaded from `src/`).
- `views/components/` uses plain JavaScript components (no `.vue` SFC pattern).
- Optional filter booleans use pointer bools (`*bool`) to represent unset state.
- Tests are colocated as `*_test.go`, mostly table-driven with `testify/assert` and occasional `testify/suite`.
- Tests that mutate config, package globals, or background worker state should stay serial and restore state with `defer`.

## Anti-Patterns

- Do not query chats or messages without `device_id` scoping for user-facing/device-scoped flows.
- Do not use `instance.ID()` as the chat/message table `device_id` after login; use `client.Store.ID.ToNonAD().String()` when deriving the WhatsApp storage identity.
- Do not use raw `@lid` event JIDs for DB lookups; normalize with `NormalizeJIDFromLID()` first.
- Do not add `IChatStorageRepository` methods without updating `chatstorage_wrapper.go` and the concrete repository.
- Do not insert migrations in the middle of `getMigrations()`; append new entries only.
- Do not remove the `evt.Sender.Device != 0` receipt check; it prevents duplicate webhook deliveries from linked devices.
- Do not put generated/runtime media, QR codes, SQLite DBs, `.env`, or history dumps into source-oriented docs or commits unless explicitly requested.
- Do not treat Chatwoot direct Postgres import as the live forwarding path; keep REST media handling and direct DB idempotency separate.

## Unique Styles

- Cobra subcommands are registered by `init()` side effects in `cmd/rest.go` and `cmd/mcp.go`.
- The app uses mutable package globals for config, clients, repositories, and usecases instead of dependency injection from `main`.
- REST has wider coverage than MCP: REST send has 12 routes; MCP exposes send, query, app, and group tool subsets.
- Chat storage migrations are Go string literals in the repository, not external migration files.
- The embedded UI uses Vue 3 from CDN, Fomantic UI modals/toasts, and custom delimiters `[[`, `]]`.
- Release workflows generate GoReleaser YAML into `/tmp`; there is no committed `.goreleaser.yml`.
- `AppVersion` is hard-coded as `v8.6.0` in `src/config/settings.go`; release workflows do not inject it with ldflags.
- `src/pkg/error` declares package name `error`; import it with aliases such as `pkgError`.
- Default SQLite builds use CGO `github.com/mattn/go-sqlite3`; `-tags purego` switches to `modernc.org/sqlite`.

## Change Validation

- Prefer targeted tests for touched packages first, then `go test ./...`.
- For handler changes, verify device scoping behavior in both REST and MCP paths when applicable.
- For webhook or Chatwoot changes, verify against:
  - [docs/webhook-payload.md](docs/webhook-payload.md)
  - [docs/chatwoot.md](docs/chatwoot.md)

## Notes

- Docker builds use `docker/golang.Dockerfile`, Go `1.25-alpine3.23`, CGO, and a final non-root `gowauser` process after the entrypoint fixes volume ownership.
- Docker Compose mounts root-level `./storages` and `./statics` into `/app`; direct local runs from `src/` use `src/storages` and `src/statics`.
- Docker publish is tag/manual driven. Arch-specific `-amd`, `-arm`, and `-armv7` images are merged into a versioned manifest; `latest` is also promoted by workflows.
- `release.yml` declares `workflow_dispatch`, but release jobs are still guarded to tag refs.
- GitHub workflows are release/publish oriented; there is no PR workflow that runs `go test`, `go vet`, or lint.
- `DBKeysURI` defaults to the main DB URI when empty; avoid in-memory keys storage in production because privacy tokens must survive long-lived sessions.
- `status@broadcast` chat names intentionally resolve to `Status`.
- `src/.air.toml` excludes `statics` and `storages`; keep hot reload from watching runtime data.
- Chatwoot direct Postgres import is for history. Live forwarding still uses REST plus link/retry storage.
