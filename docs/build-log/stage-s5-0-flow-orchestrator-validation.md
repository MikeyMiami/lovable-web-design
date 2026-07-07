# Stage — S5-0 (flow-run orchestrator infra) — validation [DONE]

> 2026-07-07. Verified against `cloud-spark-setup` `origin/main`. ONE additive table (`content_flows`); `audit_tenant_rls()=0`.

## What shipped
- **Additive `content_flows` table** (client_id, flow_type, status, checkpoint, payload jsonb {pages[], currentIndex, flowLog}, RLS mirrors `content_jobs`).
- **`createContentFlow`** (dedupes to one active flow/client), **`advanceContentFlow`** (one step per call; 'test' no-op path advances pages pending→written; real-flow branches stubbed for S5-1+), **`setFlowStatus`** (pause/resume/cancel).
- **Client batch UI** (497-gated): run test flow → poll → progress page X/N + step + status/checkpoint; pause/resume/cancel; resume re-seeds from the active `content_flows` row on reload.

## Validation (PASS)
- Test flow advanced **page 1/2 (hardscaping) → 2/2 (home) → done**; `flowLog` recorded each step; `currentIndex` reached total. ✅
- **Resume:** reload mid-flow → re-seeds from the active row, no restart. Pause/resume/cancel work; dedupe holds. ✅ `audit_tenant_rls()=0`.

## Roadmap
Durable resumable batch orchestrator proven. Next: **S5-1** (Flow 1 Build All Core — real research→deep-write per page + two human gates + publish-all), then S5-2 (Geo), S5-3 (Supporting) — each a thin config of the orchestrator.
