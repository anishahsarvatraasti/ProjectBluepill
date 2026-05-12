from typing import Any

from app.services.supabase import SupabaseRestClient


async def list_user_tasks(
    supabase: SupabaseRestClient,
    user_id: str,
) -> list[dict[str, Any]]:
    return await supabase.select(
        "tasks",
        {
            "user_id": f"eq.{user_id}",
            "select": "*",
            "order": "due_date.asc.nullslast,created_at.desc",
        },
    )


async def create_user_task(
    supabase: SupabaseRestClient,
    user_id: str,
    title: str,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return await supabase.insert(
        "tasks",
        {
            "user_id": user_id,
            "title": title,
            **(payload or {}),
        },
    )
