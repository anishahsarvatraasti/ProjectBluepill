# Project BluePill

Project BluePill is a Flutter + Supabase life operating system. It connects a user's mission, tasks, habits, calendar, AI check-ins, daily streaks, progress analytics, and Agent conversations into one dashboard.

## What It Does

- Flutter web app with Supabase Auth.
- Mission, goals, tasks, habits, check-ins, progress, calendar, and settings screens.
- AI check-ins that extract structured progress from natural language.
- Daily AI check-in streak tracking with current streak, best streak, and last check-in date.
- Dashboard and Progress views for life score, focus, completion rates, blockers, habit streaks, and check-in streaks.
- Agent chat with stored Project BluePill context and attachment metadata.
- Google Calendar / Tasks browser OAuth integration.
- Supabase Edge Functions for production agent API entry points.
- FastAPI worker for queued agent jobs, tool calls, audit logs, and notifications.

## Architecture

```text
Flutter App
  -> Supabase Auth
  -> Supabase Edge Functions
  -> Supabase Postgres
  -> Upstash QStash
  -> FastAPI Worker
  -> OpenAI Agents SDK
  -> Tools: Supabase, Google, Firebase
  -> Audit Logs + Realtime Updates
  -> Flutter UI
```

Full architecture: [docs/architecture.md](docs/architecture.md)

## Repository

```text
flutter/                     Flutter app root
flutter/lib/                 UI and client-safe app services
flutter/lib/services/        Supabase, AI, context, calendar, and agent clients
supabase/schema.sql          Current database schema source
supabase/migrations/         Supabase migration files
supabase/functions/          Edge Functions API gateway
worker/app/                  FastAPI worker, jobs, agent boundary, and tools
docs/                        Architecture, hosting, environment, and checklist docs
```

## Documentation

- [docs/architecture.md](docs/architecture.md): production architecture and responsibility boundaries.
- [docs/app-theme.md](docs/app-theme.md): Material 3 Expressive theme, brand palette, and UI usage rules.
- [docs/hosting.md](docs/hosting.md): how each service runs locally and in production.
- [docs/environment.md](docs/environment.md): public env values and backend secrets.
- [docs/deployment-checklist.md](docs/deployment-checklist.md): what is done and what is still pending.

## Local App

Install Flutter packages:

```bash
cd flutter
flutter pub get
```

Create local Flutter env:

```bash
cp .env.example .env
```

Run web locally on the required port:

```bash
flutter run -d web-server --web-hostname localhost --web-port 3000
```

Open:

```text
http://localhost:3000
```

## Supabase

The repo is set up for the Supabase cloud project:

```text
Project: Project BluePill
Ref: qhunsphxuzmheduacull
Region: Southeast Asia, Singapore
```

Useful commands:

```bash
supabase projects list
supabase functions list
supabase migration list
```

Deploy Edge Functions:

```bash
supabase functions deploy agent-chat
supabase functions deploy approve-action
supabase functions deploy schedule-job
```

Push migrations only when ready:

```bash
supabase db push
```

## Worker

Run locally:

```bash
cd worker
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Production host: Render Web Service. See [docs/hosting.md](docs/hosting.md).

## Daily AI Check-In Streak

The streak system is backed by `ai_checkin_streaks`.

Rules:

- First AI check-in starts a 1-day streak.
- Another check-in on the same day does not double count.
- A check-in on the next day increments the streak.
- Missing a day resets the current streak to 1.
- Best streak is preserved.

The app updates the streak after saving a check-in and shows it on the Check-In, Dashboard, and Progress screens.

## Tests

```bash
cd flutter
flutter analyze
flutter test
```

## Secrets

Flutter only gets public/client-safe values in `flutter/.env`.

Never put these in Flutter:

```text
SUPABASE_SERVICE_ROLE_KEY
QSTASH_TOKEN
WORKER_SHARED_SECRET
OPENAI_API_KEY
FIREBASE_PRIVATE_KEY
```

Use [docs/environment.md](docs/environment.md) for where each value belongs.
