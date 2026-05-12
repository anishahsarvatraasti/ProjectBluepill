from typing import Any

from app.config import get_settings

try:
    from agents import Agent, Runner
except ImportError:  # pragma: no cover - lets scaffolding run before deps install.
    Agent = None
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


async def run_bluepill_agent(
    *,
    message: str,
    user_context: dict[str, Any],
    memories: list[dict[str, Any]],
) -> dict[str, Any]:
    settings = get_settings()
    prompt = {
        "message": message,
        "user_context": user_context,
        "memories": memories,
    }

    if Agent is None or Runner is None:
        return {
            "text": "Agent dependencies are not installed in this worker yet.",
            "tool_names": [],
            "raw": {"prompt": prompt},
        }

    agent = Agent(
        name="BluePill Agent",
        instructions=SYSTEM_INSTRUCTIONS,
        model=settings.openai_model,
    )
    result = await Runner.run(agent, str(prompt))

    return {
        "text": result.final_output,
        "tool_names": [],
        "raw": {"final_output": result.final_output},
    }
