from typing import Any


async def read_calendar_availability(
    user_id: str,
    time_min: str,
    time_max: str,
) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "time_min": time_min,
        "time_max": time_max,
        "events": [],
        "status": "not_connected",
    }


async def create_calendar_event_after_approval(
    user_id: str,
    event_payload: dict[str, Any],
) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "event_payload": event_payload,
        "status": "approval_required",
    }
