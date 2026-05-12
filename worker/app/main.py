from fastapi import Depends, FastAPI

from app.jobs.agent_runs import AgentRunDelivery, process_agent_run
from app.jobs.scheduled_jobs import ScheduledJobDelivery, process_scheduled_job
from app.security.worker_auth import verify_worker_request

app = FastAPI(title="BluePill Worker")


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
