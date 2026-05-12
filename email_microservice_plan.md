# Email Microservice — Plan

A self-hosted transactional email API, conceptually similar to Brevo's transactional API.
Built in Elixir/Phoenix, deployable as a standalone service.

---

## What it is

Any internal application sends an HTTP request to this service with a recipient, template name, and
variables. The service renders the email, delivers it via SMTP, logs the attempt, and returns
a result. No external email SaaS required.

This service is only available on the internal network — no authentication is required.
A LiveView admin UI is included for managing templates without code deployments.

---

## Architecture

```
Client App  →  POST /api/v1/send  →  Validate payload
                                   →  Render template (EEx/HEEx) or accept raw HTML
                                   →  Enqueue (GenServer queue)
                                   →  Deliver via SMTP (Swoosh)
                                   →  Log result to DB
                                   →  Return {message_id, status}

Grafana     →  POST /webhooks/grafana  →  Translate payload → free-form email send
```

---

## API Design

### Authentication
No authentication required. The service is restricted to the internal network at the
infrastructure level.

### Send Email
```
POST /api/v1/send

{
  "to": {
    "email": "user@example.com",
    "name": "John Doe"           // optional
  },
  "from": {
    "email": "noreply@myapp.com", // optional, falls back to default
    "name": "My App"
  },
  "subject": "Welcome!",          // required if not using a template
  "template_id": "welcome",       // optional — use stored template
  "data": {                       // passed to template as assigns
    "username": "johndoe",
    "locale": "en"
  },
  "html": "<h1>Hello</h1>",       // optional — raw HTML (skip template)
  "text": "Hello",                // optional — raw plain text
  "app": "seveneat"               // optional — identifies the calling service (for logs)
}
```

**Response (202 Accepted)**
```json
{
  "message_id": "01J...",
  "status": "queued"
}
```

**Response (400/401/422)**
```json
{
  "error": "invalid_payload",
  "details": "..."
}
```

### Get Send Status
```
GET /api/v1/messages/:message_id
```

```json
{
  "message_id": "01J...",
  "status": "delivered" | "failed" | "queued" | "retrying",
  "attempts": 1,
  "sent_at": "2026-03-21T10:00:00Z",
  "error": null
}
```

### List Templates
```
GET /api/v1/templates
POST /api/v1/templates
GET /api/v1/templates/:id
PUT /api/v1/templates/:id
DELETE /api/v1/templates/:id
```

---

## Project Structure

```
gonemail/                         ← standalone repo
├── lib/
│   ├── gonemail/
│   │   ├── application.ex
│   │   ├── repo.ex
│   │   ├── mailer.ex             ← Swoosh.Mailer wrapper (copied from seveneat)
│   │   ├── email/
│   │   │   ├── email.ex          ← build/5, render_template/2 (from seveneat)
│   │   │   ├── sender.ex         ← delivers email, wraps Mailer.deliver/1
│   │   │   └── queue/
│   │   │       ├── supervisor.ex ← starts pool of N workers
│   │   │       └── worker.ex     ← polls DB, claims job with FOR UPDATE SKIP LOCKED
│   │   ├── templates/
│   │   │   ├── template.ex       ← Ecto schema (id, name, html_body, text_body, variables)
│   │   │   └── renderer.ex       ← preprocesses {{ path.to.var }} then renders via EEx
│   │   └── messages/
│   │       └── message.ex        ← Ecto schema for delivery log
│   └── gonemail_web/
│       ├── router.ex
│       ├── controllers/
│       │   ├── send_controller.ex
│       │   └── message_controller.ex
│       └── live/
│           ├── template_live/
│           │   ├── index.ex      ← list templates
│           │   └── form.ex       ← create/edit template with HTML preview
│           └── message_live/
│               └── index.ex      ← delivery log viewer
├── priv/repo/migrations/
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   └── runtime.exs
├── test/
├── .env.template
├── Makefile
└── README.md
```

---

## Database Schema

### `templates`
| column       | type      | notes                          |
|--------------|-----------|--------------------------------|
| id           | string    | e.g. "welcome", "verify"       |
| subject      | text      |                                |
| html_body    | text      | EEx template string            |
| inserted_at  | timestamp |                                |
| updated_at   | timestamp |                                |

`text_body` is derived at render time by stripping HTML tags from `html_body` — no need to store it.
`variables` is also dropped — expected variables can be inferred by parsing `{{ }}` expressions in the template.

### `messages`
| column        | type      | notes                              |
|---------------|-----------|------------------------------------|
| id            | bigserial | PK, returned as message_id         |
| app           | string    | nullable — calling service label   |
| to_email      | string    |                                    |
| to_name       | string    |                                    |
| from_email    | string    |                                    |
| subject       | string    |                                    |
| template_id   | string    | nullable                           |
| data          | json     | nullable                           |
| body          | text      | rendered HTML — always populated   |
| status        | string    | queued / delivered / failed        |
| attempts      | integer   | default 0                          |
| last_error       | text      | nullable                           |
| sent_at          | timestamp | nullable                           |
| next_attempt_at  | timestamp | nullable — when to next retry      |
| inserted_at      | timestamp |                                    |

**Indexes:**
```sql
-- Queue workers: filter by status + date, ordered by insertion
CREATE INDEX idx_messages_queue ON messages (status, next_attempt_at, inserted_at);

-- LiveView log viewer: filter by app and status
CREATE INDEX idx_messages_app_status ON messages (app, status);
```

---

## Template Rendering

Templates use a `{{ path.to.var }}` syntax for safe variable interpolation. Before passing
a template to EEx, the renderer preprocesses it — replacing `{{ }}` expressions with
`get_in(assigns, [...]) || ""` calls. Missing or null paths silently render as empty string,
so a missing payload field never crashes the renderer.

```elixir
defmodule GonEmail.Templates.Renderer do
  def render(template, assigns) do
    html = template |> preprocess() |> EEx.eval_string(assigns: assigns)
    text = extract_text(html)
    {html, text}
  end

  defp preprocess(template) do
    Regex.replace(~r/\{\{\s*([\w.]+)\s*\}\}/, template, fn _, path ->
      keys = String.split(path, ".")
      "<%= get_in(assigns, #{inspect(keys)}) || \"\" %>"
    end)
  end

  defp extract_text(html) do
    html
    |> String.replace(~r/<style[^>]*>.*?<\/style>/s, "")
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
```

Example template snippet:
```html
<p>Alert: {{ body.commonLabels.alertname }}</p>
<p>Status: {{ body.status }}</p>
<p>Hi {{ variables.username }}, welcome!</p>
```

The full assigns map passed to the renderer contains:
- `body` — the raw decoded JSON payload from the request
- `data` — the explicit `data` map from the request (for structured templates)

---

## Delivery Queue (DB-backed pool)

The queue is the `messages` table itself — no in-memory queue. A pool of N worker
processes polls the DB for pending messages, each using `SELECT ... FOR UPDATE SKIP LOCKED`
so workers never step on each other.

**Why DB-backed:**
- Survives server restarts — anything stuck in `queued` or `retrying` is re-picked on startup
- Unbounded backpressure — queue lives on disk, not in a process mailbox
- No extra infrastructure — the `messages` table is already there

**Pool structure:**
- `GonEmail.Email.Queue.Supervisor` — starts N worker processes (default 5)
- `GonEmail.Email.Queue.Worker` — each worker polls DB every second, claims one message
  with `FOR UPDATE SKIP LOCKED`, delivers it, updates status

```elixir
defmodule GonEmail.Email.Queue.Worker do
  use GenServer

  @poll_interval 1_000
  @retry_delays [5_000, 30_000, 120_000]

  # Each worker independently polls:
  # SELECT * FROM messages WHERE status IN ('queued', 'retrying')
  #   AND (next_attempt_at IS NULL OR next_attempt_at <= NOW())
  #   ORDER BY inserted_at
  #   LIMIT 1 FOR UPDATE SKIP LOCKED
  #
  # On success: status = "delivered", sent_at = now
  # On failure: increment attempts, set next_attempt_at via retry delay,
  #             status = "retrying" (or "failed" after max attempts)
end
```

Retry schedule: `[5_000, 30_000, 120_000]` ms (exponential backoff, max 3 attempts)

`next_attempt_at` column added to `messages` to support scheduled retries.

---

## Existing Code to Extract from Seveneat

These files can be copied directly and adapted (rename module prefix):

### `lib/seveneat/mailer.ex` → `lib/gonemail/mailer.ex`
```elixir
defmodule Seveneat.Mailer do
  use Swoosh.Mailer, otp_app: :seveneat
end
```

### `lib/seveneat/emails/email.ex` → `lib/gonemail/email/email.ex`
```elixir
defmodule Seveneat.Emails.Email do
  import Swoosh.Email

  @default_from_name "Seveneat"

  def build(to, subject, template, assigns \\ %{}, opts \\ []) do
    html = render_template(template, assigns)
    text = extract_text_from_html(html)
    from_email = Keyword.get(opts, :from_email, "noreply@seveneat.com")

    new()
    |> to(to)
    |> from({@default_from_name, from_email})
    |> subject(subject)
    |> html_body(html)
    |> text_body(text)
  end

  def render_template(template, assigns) do
    template.render(assigns)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp extract_text_from_html(html) do
    html
    |> String.replace(~r/<style[^>]*>.*?<\/style>/s, "")
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
```

### SMTP Configuration (`config/runtime.exs` excerpt)
```elixir
smtp_username = System.get_env("SMTP_USERNAME")
smtp_password = System.get_env("SMTP_PASSWORD")
smtp_relay    = System.get_env("SMTP_RELAY") || "smtp.email.uk-london-1.oci.oraclecloud.com"

if smtp_username && smtp_password do
  config :gonemail, GonEmail.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: smtp_relay,
    port: 587,
    username: smtp_username,
    password: smtp_password,
    tls: :always,
    ssl: false,
    auth: :always,
    retries: 2,
    tls_options: [
      versions: [:"tlsv1.2"],
      verify: :verify_none
    ]
else
  config :gonemail, GonEmail.Mailer, adapter: Swoosh.Adapters.Local
end
```

### Email Templates (all 4 can be brought over as starting point)

| Template module                               | Subject (EN)                          | Subject (ES)                               |
|-----------------------------------------------|---------------------------------------|--------------------------------------------|
| `Seveneat.Emails.Templates.Welcome`           | "Welcome to Seveneat!"                | "¡Bienvenido a Seveneat!"                  |
| `Seveneat.Emails.Templates.Verify`            | "Verify your email - Code inside"     | "Verifica tu correo - Código de verificación" |
| `Seveneat.Emails.Templates.PasswordReset`     | "Reset your password - Security code" | "Restablece tu contraseña - Código de seguridad" |
| `Seveneat.Emails.Templates.PasswordChanged`   | "Your password has been changed"      | "Tu contraseña ha sido cambiada"           |

In the microservice, templates will be stored in the DB (EEx strings) rather than compiled
modules. The template modules from seveneat become the initial seed data.

---

## Dependencies (mix.exs)

```elixir
{:phoenix, "~> 1.7"},
{:phoenix_live_view, "~> 1.0"},
{:ecto_sql, "~> 3.10"},
{:postgrex, ">= 0.0.0"},
{:swoosh, "~> 1.5"},
{:gen_smtp, "~> 1.2"},
{:finch, "~> 0.13"},
{:jason, "~> 1.2"},
{:bandit, "~> 1.5"},
```

---

## Environment Variables (`.env.template`)

```bash
# Database
DATABASE_URL=ecto://user:pass@localhost/gonemail_dev

# SMTP (required for real delivery)
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_RELAY=smtp.email.uk-london-1.oci.oraclecloud.com

# App
SECRET_KEY_BASE=   # mix phx.gen.secret
PHX_HOST=localhost
PORT=4001
```

---

## Build Order (implementation phases)

### Phase 1 — Core (MVP)
1. `mix phx.new gonemail --no-assets` (Phoenix app with LiveView)
2. Copy and adapt `mailer.ex`, `email.ex`, SMTP config
3. `messages` schema + migration
4. `POST /api/v1/send` — accepts raw HTML/text or `template_id`, delivers, logs result with optional `app` field

### Phase 2 — Templates
5. `templates` schema + migration
6. `Renderer` module — EEx render with variable map
7. Update send endpoint to accept `template_id` + `variables`
8. Seed the 4 seveneat templates as initial data
9. LiveView admin UI — template list + create/edit form with HTML preview

### Phase 3 — Reliability
10. Add `next_attempt_at` to `messages` migration
11. `Queue.Supervisor` + `Queue.Worker` pool — DB polling with `FOR UPDATE SKIP LOCKED`, exponential backoff retry
12. On startup re-enqueue anything stuck in `queued` or `retrying`
13. `GET /api/v1/messages/:id` status endpoint
14. LiveView message log viewer (filterable by `app`, status)

### Phase 4 — Integrations & Polish
13. Per-app default template — if no `template_id` in the request, fall back to the default configured for that `app` (e.g. Grafana just posts its raw payload with `"app": "grafana"`)
14. Request/response logging via Plug
15. Health check endpoint `GET /health`
16. Docker setup (`Dockerfile` + `docker-compose.yml`)
17. README with API reference and setup instructions

---

## What makes this resume-worthy

- Standalone deployable service (Docker-ready)
- Clean REST API design following real-world conventions (Brevo-style)
- LiveView admin UI for template management (no code deploy needed for content changes)
- Delivery queue with retry/backoff using OTP GenServer
- Template system with variable substitution (EEx, DB-stored)
- Full delivery audit log (every send attempt tracked, filterable by app)
- Grafana webhook integration for ops alerting emails
- Demonstrates understanding of email infrastructure (SMTP, TLS, async delivery)
- Real Elixir/OTP patterns (GenServer, Plug pipeline, Ecto, LiveView)
