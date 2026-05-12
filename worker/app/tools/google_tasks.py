from typing import Any


async def create_google_task_after_approval(
    user_id: str,
    task_payload: dict[str, Any],
) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "task_payload": task_payload,
        "status": "approval_required",
    }
