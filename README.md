# Project BluePill

Project BluePill is a Flutter + Supabase personal life dashboard. It connects a user's long-term mission to today's tasks, habits, reflections, check-ins, progress score, and Agent feedback.

## Features

- Supabase email/password authentication
- Interactive onboarding for name, city, DOB, dream goal, skills, and interests
- Dynamic dashboard with life score, today's focus, tasks, mission progress, habit streaks, AI suggestion, weakness alert, motivation, and weekly chart
- Task CRUD with priority, category, due date, estimate, completion, missed status, and move-to-tomorrow
- Google Calendar event scheduling with create, edit, delete, attendees, location, and upcoming event views
- Google Tasks sync for the Todo list through a dedicated Project BluePill task list
- Mission hierarchy: dream mission, life/yearly/monthly/weekly goals, parent goals, milestones, progress percentage
- Habit tracking with frequency, completion logs, missed/partial status, streaks, and completion rate
- Agent chat with attachments and stored user context through `McpContextService`
- Morning, afternoon, night, and weekly AI check-ins
- Natural-language check-in extraction into structured JSON
- Life score engine using tasks, habits, focus, and reflection
- Progress analytics with `fl_chart`
- Settings profile details and connection status

## Tech Stack

- Flutter Material UI
- Supabase Auth, Postgres, pgvector, Storage, Realtime, and Edge Functions
- Upstash QStash queue with a Python FastAPI worker for production agent jobs
- OpenAI Agents SDK as the default production agent framework
- Firebase Cloud Messaging for push notifications
- `fl_chart` for charts
- MCP-style context service in `flutter/lib/services/mcp_context_service.dart`

See `docs/architecture.md` for the final production flow and backend responsibilities.

## Project Structure

```text
flutter/                     Flutter app root
flutter/lib/                 Flutter UI and client-safe Supabase calls
flutter/lib/services/agent_gateway_service.dart
                             Flutter -> Edge Function gateway client
supabase/schema.sql          Postgres, RLS, pgvector, Storage, Realtime setup
supabase/functions/          Edge Functions API gateway
supabase/functions/_shared/  Auth, permission, audit, QStash helpers
worker/app/                  FastAPI worker execution engine
worker/app/agents/           OpenAI Agents SDK orchestration boundary
worker/app/jobs/             QStash job handlers
worker/app/tools/            Supabase, memory, Storage, Google, FCM, MCP tools
docs/architecture.md         Final architecture contract
```

## Setup

This repository contains the Flutter app source and Supabase schema. If platform folders are missing, generate them after installing Flutter:

```bash
(cd flutter && flutter create --platforms=android,ios,web .)
```

Install packages:

```bash
(cd flutter && flutter pub get)
```

Create your environment file:

```bash
(cd flutter && cp .env.example .env)
```

Edit `flutter/.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
GOOGLE_OAUTH_CLIENT_ID=your-google-oauth-client-id.apps.googleusercontent.com
```

Enable the Google Calendar API and Google Tasks API in Google Cloud, create an OAuth 2.0 Web client, and add your local origin such as `http://127.0.0.1:5174` or `http://localhost:5174` under Authorized JavaScript origins.

Server-only secrets for Edge Functions, workers, QStash, AI providers, and FCM belong in `server.env.example`-style deployment environments, not `flutter/.env`.

## Supabase

1. Create a Supabase project.
2. Open the SQL editor.
3. Run `supabase/schema.sql` from the repository root.
4. In Authentication settings, configure email confirmation based on your development preference.
5. Enable Google under Authentication -> Providers if you want Google login.
6. Add your local and production redirect URLs under Authentication -> URL Configuration. For local web development, add `http://127.0.0.1:5174`.
7. Add your Supabase URL and anon key to `flutter/.env`.

Every table has RLS enabled. Policies restrict each user to rows where `auth.uid() = user_id`.

## Run

```bash
(cd flutter && flutter run -d chrome)
```

For mobile:

```bash
(cd flutter && flutter run -d android)
(cd flutter && flutter run -d ios)
```

## AI Notes

The final production path is Flutter -> Supabase Auth -> Supabase Edge Functions -> permission/rate-limit check -> `agent_runs` or `scheduled_jobs` -> QStash -> FastAPI worker -> OpenAI Agents SDK -> tool layer -> audit logs and Realtime updates.

Flutter should call `AgentGatewayService` for production agent work. The older direct AI service remains a local fallback path and should not receive production secrets.

## Core Files

- `flutter/lib/main.dart` initializes dotenv, Supabase, theme, and auth gate.
- `flutter/lib/services/agent_gateway_service.dart` invokes Edge Functions for agent runs, scheduled jobs, and approvals.
- `flutter/lib/services/mcp_context_service.dart` is the MCP-style memory/context layer.
- `supabase/functions/` contains the Edge Function API gateway layer.
- `worker/app/` contains the FastAPI worker, job handlers, agent boundary, and tool adapters.
- `flutter/lib/services/progress_engine.dart` calculates and builds daily life score logs.
- `supabase/schema.sql` creates tables, enums, indexes, and RLS policies.
- `flutter/test/progress_engine_test.dart` covers the weighted life score formula.
