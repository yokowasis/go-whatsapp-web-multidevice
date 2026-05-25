# AGENTS

Agent instructions for `go-whatsapp-web-multidevice`.

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

Important: REST and MCP cannot run simultaneously in one process.

## Architecture Rules

- Keep clean boundaries: `domains` (contracts) -> `usecase` (business logic) -> `ui` (REST/MCP handlers).
- Keep 1:1 mapping pattern when adding features: domain + usecase + validation + handler.
- Do not place business logic in `domains`.

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

## File-Level Conventions

- `views/components/` uses plain JavaScript components (no `.vue` SFC pattern).
- Optional filter booleans use pointer bools (`*bool`) to represent unset state.
- Config precedence is CLI flags > environment variables > `.env` file.

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

## Change Validation

- Prefer targeted tests for touched packages first, then `go test ./...`.
- For handler changes, verify device scoping behavior in both REST and MCP paths when applicable.
- For webhook or Chatwoot changes, verify against:
  - [docs/webhook-payload.md](docs/webhook-payload.md)
  - [docs/chatwoot.md](docs/chatwoot.md)
