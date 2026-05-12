from typing import Any

from app.services.supabase import SupabaseRestClient


async def search_memory(
    supabase: SupabaseRestClient,
    user_id: str,
    query: str,
) -> list[dict[str, Any]]:
    if not query.strip():
        return []

    # Embedding generation is intentionally separate from this scaffold.
    # Once wired, pass the generated vector to match_agent_memory.
    return []


async def write_memory_source(
    supabase: SupabaseRestClient,
    user_id: str,
    source_type: str,
    title: str,
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return await supabase.insert(
        "agent_memory_sources",
        {
            "user_id": user_id,
            "source_type": source_type,
            "title": title,
            "metadata": metadata or {},
        },
    )
