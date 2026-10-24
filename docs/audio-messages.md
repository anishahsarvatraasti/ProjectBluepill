# Audio messages

The existing microphone button starts capture. Press it again to attach a mono
PCM WAV voice note, then press Send to submit it with optional typed text.
Add → Audio file attaches WAV, MP3, M4A, AAC, OGG, FLAC, or WebM files. There is
no recognizer, speech model, transcription endpoint, or transcript inserted into
the composer. Recording stops at the 8 MB limit or when the app loses focus.
Up to four attachments are allowed; audio must total at most 8 MB per request.

Flutter sends base64 audio to the authenticated worker `/agent/chat` route.
The same agent context, character, memories and conversation history are used.
The Agents SDK forwards audio as `input_audio` content to Chat Completions.
Text messages keep using the existing provider/model settings.

Worker audio model settings:

- OpenRouter: `OPENROUTER_AUDIO_MODEL`, default `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free`.
- OpenAI: `OPENAI_AUDIO_MODEL`, default `gpt-audio-1.5`.
- Credentials and `AI_PROVIDER` use the existing worker settings. OpenAI accepts
  WAV/MP3 here; OpenRouter format support depends on the configured provider.

Audio is uploaded to the worker and the selected model provider. This feature
requires network access. The worker saves attachment metadata, not raw audio,
in chat history, run input and audit records. Agent SDK tracing is disabled for
audio requests. Clips cannot be replayed from reopened history or retried from
a queue: resend the audio instead. Provider retention follows provider policy.
The app clears retired local speech model caches on startup of the chat page.

Deploy the worker implementation before the matching Firebase frontend. The
current Render repository differs from local origin; see AGENTS.md and hosting
notes. Do not deploy only the frontend against the previous worker, which rejects
audio payloads. No database migration is required.

## Provider verification (2026-10-24)

A live SDK request with generated test speech reached the configured Nemotron
model, but OpenRouter returned HTTP 402 requiring at least $0.50 balance for
audio. End-to-end audio understanding is therefore not verified on this account.
The chat displays an account-credit error and restores the attachment for retry.
No automatic paid-model fallback is used.
