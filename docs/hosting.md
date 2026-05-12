# Project BluePill Hosting

Reference: `docs/architecture.md`

This file only explains how each part runs locally and how it should run in production. Status lives in `docs/deployment-checklist.md`.

## Flutter App

### Local

```bash
cd flutter
flutter run -d web-server --web-hostname localhost --web-port 3000
```

Use `http://localhost:3000` for local development.

### Production

```bash
cd flutter
flutter build web --release
```

Deploy the build output:

```text
flutter/build/web
```

Use Vercel, Netlify, or Firebase Hosting.

## Supabase Project

### Local

```bash
supabase login
supabase link --project-ref qhunsphxuzmheduacull
```

Optional local Supabase stack:

```bash
supabase start
```

Local Supabase URLs:

```text
API:    http://127.0.0.1:54321
Studio: http://127.0.0.1:54323
DB:     postgresql://postgres:postgres@127.0.0.1:54322/postgres
```

### Production

Use the existing Supabase cloud project:

```text
Name: Project BluePill
Ref: qhunsphxuzmheduacull
Region: Southeast Asia, Singapore
Dashboard: https://supabase.com/dashboard/project/qhunsphxuzmheduacull
```

Check the connected project:

```bash
supabase projects list
```

## Supabase Edge Functions

### Local

Keep source code in:

```text
supabase/functions/
supabase/functions/_shared/
```

Functions:

```text
agent-chat
approve-action
schedule-job
```

### Production

Deploy functions:

```bash
supabase functions deploy agent-chat
supabase functions deploy approve-action
supabase functions deploy schedule-job
```

Check deployed functions:

```bash
supabase functions list
```

## Supabase Database, Storage, Realtime

### Local

Keep schema and seed files in:

```text
supabase/schema.sql
supabase/migrations/
supabase/seed.sql
```

Check migration state:

```bash
supabase migration list
```

### Production

Push migrations only when the schema is ready:

```bash
supabase db push
```

`supabase db push` changes the remote database.

## FastAPI Worker

### Local

```bash
cd worker
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Check:

```bash
curl http://localhost:8000/healthz
```

### Production

Host on Render as a **Web Service**.

Render settings:

```text
Service type: Web Service
Root directory: worker
Runtime: Python
Build command: pip install -r requirements.txt
Start command: uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

Production endpoints:

```text
GET  https://your-worker.onrender.com/healthz
POST https://your-worker.onrender.com/jobs/agent-run
POST https://your-worker.onrender.com/jobs/scheduled-job
```

Do not use Render Background Worker because QStash needs public HTTP endpoints.

## QStash

### Local

No local hosting is needed. Local development can call the worker directly.

### Production

Create an Upstash QStash project, then set the token in Supabase:

```bash
supabase secrets set QSTASH_TOKEN="..."
```

QStash targets:

```text
POST https://your-worker.onrender.com/jobs/agent-run
POST https://your-worker.onrender.com/jobs/scheduled-job
```

## OpenAI / Model Provider

### Local

Add model provider env values to the local worker environment.

```text
OPENAI_API_KEY=...
OPENAI_MODEL=gpt-4o-mini
OPENAI_EMBEDDING_MODEL=text-embedding-3-small
```

Keep model keys out of Flutter.

### Production

Add model provider env values in Render.

```text
OPENAI_API_KEY=...
OPENAI_MODEL=gpt-4o-mini
OPENAI_EMBEDDING_MODEL=text-embedding-3-small
```

## Google Calendar / Tasks

### Local

Add this Google OAuth JavaScript origin:

```text
http://localhost:3000
```

### Production

Add the production frontend domain in Google Cloud OAuth:

```text
https://your-frontend-domain
```

Also add the same frontend URL to Supabase Auth redirect URLs.

## Firebase Cloud Messaging

### Local

Configure Firebase client setup if push notifications are enabled.

Configure worker Firebase env if backend notifications are enabled:

```text
FIREBASE_PROJECT_ID=...
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY=...
```
### Production

Create or use a Firebase project, then add Firebase admin env values to Render:

```text
FIREBASE_PROJECT_ID=...
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY=...
```
