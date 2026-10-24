from typing import Any

from app.config import get_settings
from app.services.audio_input import AudioInputError

try:
    from agents import Agent, AsyncOpenAI, OpenAIProvider, RunConfig, Runner
except ImportError:  # pragma: no cover - lets scaffolding run before deps install.
    Agent = None
    AsyncOpenAI = None
    OpenAIProvider = None
    RunConfig = None
    Runner = None


SYSTEM_INSTRUCTIONS = """
You are the Project BluePill agent. Answer the user's latest message directly.
Use stored user context only when it is clearly relevant to goals, mission,
tasks, calendar, habits, check-ins, progress, planning, motivation, personal
patterns, or an explicit personalization request.

For simple factual questions, math, definitions, coding help, general
knowledge, or casual chat, answer normally without mentioning the user's
mission, profile, progress, weaknesses, tasks, habits, or next action.

Ask for approval before actions that mutate external systems.
"""

AGENT_PROFILE_INSTRUCTIONS = {
    "coach": "Use a warm, practical coaching voice. Encourage honestly and end with a clear next step when useful.",
    "strategist": "Act as a calm strategist. Analyze trade-offs, organize the problem, and offer a structured plan without unnecessary enthusiasm.",
    "cheerleader": "Use upbeat, energetic encouragement. Celebrate real progress while keeping advice concrete and avoiding empty praise.",
    "socratic_guide": "Act as a thoughtful Socratic guide. Use a small number of focused questions to help the user reason, while still answering directly when they ask for facts.",
    "direct_mentor": "Be concise and candid, with respectful accountability. Name the most useful action plainly; never shame or insult the user.",
}


def _profile_instructions(user_context: dict[str, Any]) -> str:
    profile = user_context.get("profile")
    profile_id = profile.get("agent_profile") if isinstance(profile, dict) else None
    if not isinstance(profile_id, str):
        profile_id = "coach"
    return AGENT_PROFILE_INSTRUCTIONS.get(
        profile_id, AGENT_PROFILE_INSTRUCTIONS["coach"]
    )


def _model_runtime(settings: Any, *, audio: bool = False) -> tuple[str, Any | None]:
    provider_name = settings.ai_provider.strip().lower()

    if provider_name == "openrouter":
        api_key = settings.openrouter_api_key or settings.openai_api_key
        model = settings.openrouter_audio_model if audio else settings.openrouter_model
        base_url = settings.openrouter_base_url
        headers = {
            "HTTP-Referer": settings.openrouter_site_url,
            "X-Title": settings.openrouter_app_name,
        }
    else:
        api_key = settings.openai_api_key
        model = settings.openai_audio_model if audio else settings.openai_model
        base_url = settings.openai_base_url
        headers = {}

    if not api_key or AsyncOpenAI is None or OpenAIProvider is None or RunConfig is None:
        return model, None

    client = AsyncOpenAI(
        api_key=api_key,
        base_url=base_url,
        default_headers=headers or None,
    )
    provider = OpenAIProvider(openai_client=client, use_responses=False)
    return model, RunConfig(model_provider=provider, tracing_disabled=audio, trace_include_sensitive_data=not audio)


async def run_bluepill_agent(
    *,
    message: str,
    user_context: dict[str, Any],
    memories: list[dict[str, Any]],
    conversation_history: list[dict[str, Any]] | None = None,
    attachments: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    settings = get_settings()
    audio = [a for a in (attachments or []) if "audio_base64" in a]
    if audio and settings.ai_provider.strip().lower() != "openrouter":
        if any(a.get("audio_format") not in {"wav", "mp3"} for a in audio):
            raise AudioInputError("This provider accepts WAV or MP3 audio. Please use one of those formats.")
    prompt = {
        "message": message,
        "conversation_history": conversation_history or [],
        "user_context": user_context,
        "memories": memories,
        "attachments": [{k: v for k, v in a.items() if k != "audio_base64"} for a in (attachments or [])],
    }

    if Agent is None or Runner is None:
        if audio:
            raise AudioInputError("Audio requires the agent SDK to be installed.")
        return {
            "text": "Agent dependencies are not installed in this worker yet.",
            "tool_names": [],
            "raw": {"prompt": prompt},
        }

    model, run_config = _model_runtime(settings, audio=bool(audio))
    if audio and run_config is None:
        raise AudioInputError("Configure the worker model provider credentials for audio.")
    agent = Agent(
        name="BluePill Agent",
        instructions=f"{SYSTEM_INSTRUCTIONS}\n\nSelected character profile:\n{_profile_instructions(user_context)}",
        model=model,
    )
    model_input: Any = str(prompt)
    if audio:
        model_input = [{"role": "user", "content": [
            {"type": "input_text", "text": str(prompt)},
            *[{"type": "input_audio", "input_audio": {
                "data": a["audio_base64"], "format": a["audio_format"],
            }} for a in audio],
        ]}]
    try:
        result = await Runner.run(agent, model_input, run_config=run_config)
    except Exception as error:
        if audio:
            status_code = getattr(error, "status_code", None)
            if status_code == 402:
                raise AudioInputError("The model provider requires account credit for audio. Add credit in the provider dashboard, then resend the voice note.") from None
            if status_code == 403:
                raise AudioInputError("The model provider denied audio access. Check the worker audio model and provider account permissions.") from None
            if status_code == 429:
                raise AudioInputError("The audio model is rate limited. Please try again later.") from None
            raise AudioInputError("The audio model could not process this clip. Please try a WAV or MP3 file, or check the worker audio model configuration.") from None
        raise

    return {
        "text": result.final_output,
        "tool_names": [],
        "raw": {"final_output": result.final_output},
    }
