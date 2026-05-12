from typing import Any


async def call_mcp_tool_later(
    tool_name: str,
    payload: dict[str, Any],
) -> dict[str, Any]:
    return {
        "tool_name": tool_name,
        "payload": payload,
        "status": "mcp_not_enabled",
    }
