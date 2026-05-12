# Project BluePill Environment

Environment values are grouped by where they belong. Flutter gets only public client values. Backend secrets stay in Supabase Edge Function secrets or Render.

## Supabase Project

```text
Project: Project BluePill
Project ref: qhunsphxuzmheduacull
Region: Southeast Asia, Singapore
Dashboard: https://supabase.com/dashboard/project/qhunsphxuzmheduacull
```

CLI connection:

```bash
supabase login
supabase link --project-ref qhunsphxuzmheduacull
```

## Flutter Public Env

File:

```text
flutter/.env
```

Allowed values:

```text
SUPABASE_URL=https://qhunsphxuzmheduacull.supabase.co
SUPABASE_ANON_KEY=...
GOOGLE_OAUTH_CLIENT_ID=...
AI_PROVIDER=...
```

Never put backend secrets in Flutter.

## Supabase Edge Function Secrets

```bash
supabase secrets set \
  SUPABASE_URL="https://qhunsphxuzmheduacull.supabase.co" \
  SUPABASE_ANON_KEY="..." \
  SUPABASE_SERVICE_ROLE_KEY="..." \
  QSTASH_TOKEN="..." \
  WORKER_BASE_URL="https://your-worker.onrender.com" \
  WORKER_SHARED_SECRET="..."
```

Check:

```bash
supabase secrets list
```

## Render Worker Env

```text
SUPABASE_URL=https://qhunsphxuzmheduacull.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...
WORKER_SHARED_SECRET=...
OPENAI_API_KEY=...
OPENAI_MODEL=gpt-4o-mini
OPENAI_EMBEDDING_MODEL=text-embedding-3-small
FIREBASE_PROJECT_ID=...
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY=...
```

## Google OAuth

Local JavaScript origin:

```text
http://localhost:3000
```

Production JavaScript origin:

```text
https://your-frontend-domain
```

Also add the production frontend URL to Supabase Auth redirect URLs.
