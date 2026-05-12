# BluePill FastAPI Worker

This worker is the execution engine from `docs/architecture.md`.

It receives QStash webhook deliveries, loads durable state from Supabase, runs the OpenAI Agents SDK, calls approved tools, writes audit logs, and updates Realtime-visible tables.

## Local Setup

```bash
cd worker
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Use `server.env.example` as the source for required environment variables.

## Endpoints

- `GET /healthz`: health check.
- `POST /jobs/agent-run`: QStash delivery for immediate agent runs.
- `POST /jobs/scheduled-job`: QStash delivery for scheduled jobs.

## Module Map

- `app/main.py`: FastAPI entrypoint.
- `app/security/`: QStash/shared-secret verification.
- `app/jobs/`: job execution handlers.
- `app/agents/`: OpenAI Agents SDK orchestration.
- `app/services/`: Supabase, context, and audit helpers.
- `app/tools/`: tool adapters for Postgres, memory, Storage, Google Calendar, Google Tasks, FCM, and future MCP.
