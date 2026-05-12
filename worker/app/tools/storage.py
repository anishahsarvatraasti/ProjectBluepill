from typing import Any

from app.services.supabase import SupabaseRestClient


async def record_storage_attachment(
    supabase: SupabaseRestClient,
    user_id: str,
    storage_path: str,
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return await supabase.insert(
        "agent_memory_sources",
        {
            "user_id": user_id,
            "source_type": "file",
            "storage_bucket": "agent-attachments",
            "storage_path": storage_path,
            "metadata": metadata or {},
        },
    )
