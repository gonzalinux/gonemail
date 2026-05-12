# Gonemail

A self-hosted transactional email microservice built with Elixir/Phoenix. Any internal
service sends an HTTP request with a recipient, template, and data — Gonemail renders,
queues, and delivers the email via SMTP, then logs the result.

Conceptually similar to Brevo's transactional API, but fully self-hosted and requiring
no external email SaaS.

---

## Features

- **REST API** — send emails with a template or raw HTML
- **Template system** — DB-stored templates with `{{ path.to.var }}` variable syntax
- **LiveView admin UI** — manage templates and monitor delivery log without code deploys
- **Async delivery** — DB-backed worker pool with exponential backoff retry
- **App registry** — per-app default templates and sender configuration
- **Full audit log** — every send attempt tracked with status, errors, and timestamps

---

## API

### Send an email

```
POST /api/v1/send

{
  "app": "seveneat",
  "to": { "email": "user@example.com" },
  "from": { "email": "noreply@myapp.com", "name": "My App" },
  "subject": "Welcome!",
  "template_id": "welcome",
  "data": { "username": "johndoe" }
}
```

- `template_id` is optional — falls back to the default template configured for the `app`
- `html` (raw HTML string) can be passed instead of `template_id` for free-form emails
- `app` is optional but recommended — used for log attribution and default template lookup

**Response (202)**
```json
{ "message_id": 1, "status": "queued" }
```

### Get message status

```
GET /api/v1/messages/:id
```

```json
{
  "message_id": 1,
  "status": "delivered",
  "attempts": 1,
  "sent_at": "2026-05-12T10:00:00Z",
  "error": null
}
```

---

## Template syntax

Templates are stored in the database and edited via the LiveView UI. Variables use
`{{ path.to.var }}` syntax — missing or null paths render as empty string, never crash.

```html
<p>Hello {{ data.username }},</p>
<p>Alert: {{ body.commonLabels.alertname }}</p>
<p>Status: {{ body.status }}</p>
```

The assigns available in every template:
- `data` — the `data` map from the request payload
- `body` — the full raw request body (useful for webhook sources like Grafana)

---

## Setup

```bash
# Install dependencies and create the database
mix setup

# Start the server
mix phx.server
```

The API is available at `http://localhost:4001`.
The admin UI is available at `http://localhost:4001/admin`.

### Environment variables

```bash
# Database
DATABASE_URL=ecto://user:pass@localhost/gonemail_dev

# SMTP
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_RELAY=smtp.email.uk-london-1.oci.oraclecloud.com

# App
SECRET_KEY_BASE=   # mix phx.gen.secret
PHX_HOST=localhost
PORT=4001
```

---

## Architecture

```
Client App  →  POST /api/v1/send
                → validate payload
                → insert message (status: queued)
                → return {message_id, status}

Worker pool →  poll messages WHERE status = 'queued'
                → FOR UPDATE SKIP LOCKED
                → render template
                → deliver via SMTP (Swoosh)
                → update status (delivered / retrying / failed)
```

Retry schedule: 5s → 30s → 120s (max 3 attempts)

---

## Deployment

```bash
docker build -t gonemail .
docker-compose up
```

> This service is intended for internal network use only. Do not expose it publicly.
