from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.agent_chat import router as agent_chat_router
from app.config import get_settings
from app.jobs.agent_runs import AgentRunDelivery, process_agent_run
from app.jobs.scheduled_jobs import ScheduledJobDelivery, process_scheduled_job
from app.security.worker_auth import verify_worker_request

app = FastAPI(title="BluePill Worker")
settings = get_settings()
allow_origins = [
    origin.strip()
    for origin in settings.cors_allow_origins.split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins or ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(agent_chat_router)


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/jobs/agent-run", dependencies=[Depends(verify_worker_request)])
async def agent_run_job(payload: AgentRunDelivery) -> dict[str, str]:
    await process_agent_run(payload)
    return {"status": "accepted"}


@app.post("/jobs/scheduled-job", dependencies=[Depends(verify_worker_request)])
async def scheduled_job(payload: ScheduledJobDelivery) -> dict[str, str]:
    await process_scheduled_job(payload)
    return {"status": "accepted"}
