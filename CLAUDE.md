# Gonemail — Claude Code Guidelines

## What this project is

A self-hosted transactional email microservice built in Elixir/Phoenix. Internal services
send HTTP requests to deliver emails via SMTP. No external email SaaS required.

This service is **internal-network only** — there is no authentication layer. Network
restriction is the security boundary.

## Architecture

- `POST /api/v1/send` — receive send request, insert message as `queued`, workers deliver async
- `GET /api/v1/messages/:id` — check delivery status
- LiveView admin UI — manage templates and view delivery log
- DB-backed worker pool — N workers poll `messages` with `FOR UPDATE SKIP LOCKED`, no in-memory queue

## Key technical decisions

- **No auth** — internal network only, no API keys, no AuthPlug
- **DB-backed queue** — `messages` table IS the queue; workers poll it every second
- **Template syntax** — `{{ path.to.var }}` is preprocessed into `get_in(assigns, [...]) || ""`
  before EEx evaluation. Missing paths silently return `""`, never crash
- **Text body derived** — plain text version is extracted from HTML at render time, never stored
- **`app` field** — string FK to `apps` table, identifies the calling service for log attribution
- **String PKs** — both `apps` and `templates` use string PKs (`name`), not bigserial

## Project structure

- `lib/gonemail/apps/` — App schema (registered calling services + domain verification)
- `lib/gonemail/templates/` — Template schema + Renderer (preprocessor + EEx)
- `lib/gonemail/messages/` — Message schema (delivery log + queue)
- `lib/gonemail/email/` — Email builder + Sender (Swoosh wrapper)
- `lib/gonemail/email/queue/` — Supervisor + Worker pool
- `lib/gonemail_web/` — Router, controllers, LiveView UI

## Database

Three tables: `apps`, `templates`, `messages`. See migrations in `priv/repo/migrations/`.

`messages` indexes:
- `(status, next_attempt_at, inserted_at)` — for queue worker polling
- `(app, status)` — for LiveView log filtering

## Template rendering

```elixir
GonEmail.Templates.Renderer.render(template, assigns)
# assigns contains:
#   :body — raw decoded JSON payload from the request
#   :data — explicit data map from the request
```

Template syntax: `{{ body.alert.title }}`, `{{ data.username }}` — safe, missing = `""`

## Queue workers

- Pool of N workers (configurable via env), each polls DB independently
- `SELECT ... WHERE status IN ('queued','retrying') AND next_attempt_at <= NOW() ORDER BY inserted_at LIMIT 1 FOR UPDATE SKIP LOCKED`
- Retry schedule: 5s, 30s, 120s (max 3 attempts), then `status = "failed"`
- On startup: re-enqueue anything stuck in `queued` or `retrying`

## Domain verification

Apps must have `status: :active` before `enqueue_email` will accept requests from them.
The current flow is **manual**:

1. Register the app via `POST /api/apps`
2. Set up the domain in Oracle Cloud Email Delivery console (SPF + DKIM DNS records)
3. Once OCI confirms the domain, activate the app:
   ```
   PUT /api/apps/:name
   { "status": "active", "verify_date": "2026-05-15T00:00:00Z" }
   ```

The `App` schema already has `verify_changeset/2` for this purpose.

### Future: automated verification

If this becomes a multi-tenant product, replace the manual step with an automated check:

- **DNS-based** — query the domain's TXT records for the expected SPF/DKIM values using
  `:inet_res` or a DNS library. Can be triggered on demand or via a scheduled job.
- **OCI API-based** — call the OCI Email Delivery API (`GET /20170907/senders`) to check
  whether the domain/sender is verified on Oracle's side. Requires OCI SDK credentials
  (`OCI_TENANCY`, `OCI_USER`, `OCI_KEY_FILE`, `OCI_FINGERPRINT`).

In either case, a `POST /api/apps/:name/verify` action should trigger the check and call
`AppService.update_app(name, %{status: :active, verify_date: DateTime.utc_now()})` on
success, or return the specific DNS/API failure reason so the caller knows what to fix.

## Mix aliases

- `mix setup` — install deps + create + migrate + seed
- `mix precommit` — compile (warnings as errors) + unlock unused deps + format + test
- Always run `mix precommit` before considering a task done
- Preffer with statements instead of case when they are more readable.
