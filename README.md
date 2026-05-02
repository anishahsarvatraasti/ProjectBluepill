# Project BluePill

Project BluePill is a Flutter + Supabase personal life dashboard. It connects a user's long-term mission to today's tasks, habits, reflections, check-ins, progress score, and Agent feedback.

## Features

- Supabase email/password authentication
- Interactive onboarding for name, city, DOB, education, dream goal, skills, and interests
- Dynamic dashboard with life score, today's focus, tasks, mission progress, habit streaks, AI suggestion, weakness alert, motivation, and weekly chart
- Task CRUD with priority, category, due date, estimate, completion, missed status, and move-to-tomorrow
- Google Calendar event scheduling with create, edit, delete, attendees, location, and upcoming event views
- Google Tasks sync for the Todo list through a dedicated Project BluePill task list
- Mission hierarchy: dream mission, life/yearly/monthly/weekly goals, parent goals, milestones, progress percentage
- Habit tracking with frequency, completion logs, missed/partial status, streaks, and completion rate
- Agent chat with selectable personas, attachments, and stored user context through `McpContextService`
- Morning, afternoon, night, and weekly AI check-ins
- Natural-language check-in extraction into structured JSON
- Life score engine using tasks, habits, focus, and reflection
- Progress analytics with `fl_chart`
- Daily journal with AI weekly pattern summaries
- Settings profile details and connection status

## Tech Stack

- Flutter Material UI
- Supabase Auth and Postgres with Row Level Security
- OpenAI-compatible chat completions, OpenRouter, or Gemini
- `fl_chart` for charts
- MCP-style context service in `lib/services/mcp_context_service.dart`

## Setup

This repository contains the Flutter app source and Supabase schema. If platform folders are missing, generate them after installing Flutter:

```bash
flutter create --platforms=android,ios,web .
```

Install packages:

```bash
flutter pub get
```

Create your environment file:

```bash
cp .env.example .env
```

Edit `.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
AI_PROVIDER=openai
OPENAI_API_KEY=sk-your-openai-key
OPENAI_MODEL=gpt-4o-mini
```

For OpenRouter:

```env
AI_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-your-key
OPENROUTER_MODEL=openai/gpt-4o-mini
```

For Gemini:

```env
AI_PROVIDER=gemini
GEMINI_API_KEY=your-gemini-key
GEMINI_MODEL=gemini-1.5-flash
```

For Google Calendar and Google Tasks:

```env
GOOGLE_OAUTH_CLIENT_ID=your-google-oauth-client-id.apps.googleusercontent.com
```

Enable the Google Calendar API and Google Tasks API in Google Cloud, create an OAuth 2.0 Web client, and add your local origin such as `http://127.0.0.1:5174` or `http://localhost:5174` under Authorized JavaScript origins.

## Supabase

1. Create a Supabase project.
2. Open the SQL editor.
3. Run `supabase/schema.sql`.
4. In Authentication settings, configure email confirmation based on your development preference.
5. Enable Google under Authentication -> Providers if you want Google login.
6. Add your local and production redirect URLs under Authentication -> URL Configuration. For local web development, add `http://127.0.0.1:5174`.
7. Add your Supabase URL and anon key to `.env`.

Every table has RLS enabled. Policies restrict each user to rows where `auth.uid() = user_id`.

## Run

```bash
flutter run -d chrome
```

For mobile:

```bash
flutter run -d android
flutter run -d ios
```

## AI Notes

The app supports AI calls directly from Flutter for development speed. For production, route AI requests through a backend or Supabase Edge Function so private API keys are never shipped inside a mobile/web client.

If no AI key is configured, the app still works with local fallback Agent messages and lightweight local extraction.

## Core Files

- `lib/main.dart` initializes dotenv, Supabase, theme, and auth gate.
- `lib/services/mcp_context_service.dart` is the MCP-style memory/context layer.
- `lib/services/ai_service.dart` contains Agent chat, extraction, weekly review, priority ordering, and provider switching.
- `lib/services/progress_engine.dart` calculates and builds daily life score logs.
- `supabase/schema.sql` creates tables, enums, indexes, and RLS policies.
- `test/progress_engine_test.dart` covers the weighted life score formula.
