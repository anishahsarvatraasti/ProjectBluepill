from typing import Any


async def send_push_notification(
    user_id: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "title": title,
        "body": body,
        "data": data or {},
        "status": "not_configured",
    }
