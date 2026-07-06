# Stage S4-D1 — content_jobs table + resumable job-runner (no-op) — validation [DONE]

> Point-in-time validation record, 2026-07-06. Verified against `cloud-spark-setup` `origin/main` @ `60b0475`. ONE additive table. First infra piece of the S4-D 8-pass deep writer.

## What shipped
- **Additive `content_jobs` table** (`client_id`, `page_id`, `status`, `current_pass` 0-8, `section_idx`, `payload jsonb`, `attempts`, `next_run_at`, timestamps; indexes on `(client_id,status)` + `(status,next_run_at)`). RLS enabled, policy mirrors `content_pages` (`is_admin OR client_id in user_client_ids`). **`audit_tenant_rls()` → 0.**
- **`createContentJob({clientId,pageId})`** — admin-gated; de-dupes (returns the existing active job for a page instead of creating a duplicate).
- **`advanceJobOnce(admin, job)`** in `src/lib/seo/content-jobs.server.ts` — the advance-one-step state machine, **shared** by `processContentJob` (interactive poll) and the cron route. Pass model: `current_pass` = passes completed (0 fresh, 8 done); **pass 3 has `section_idx` sub-progress**; every step persists `{current_pass, section_idx, payload}` → **resumability is free**. No-op: `passLog` trace + `payload.sections[]` with timestamps; `attempts` increments; failure marks the row `failed` with `payload.error`.
- **`processContentJob({jobId})`** delegates to `advanceJobOnce`. **Client poll loop** (497-gated deep-write-test action) reuses the batch-progress pattern (pass X/8, section i/N).
- **`/api/public/cron/content-jobs`** stub — `x-cron-secret` gate + `?ping=1` health check + `FOR UPDATE SKIP LOCKED` claim; ready to schedule later (S4-E), not wired now.

## Validation (PASS)
- No-op state machine walks pass 0→8→**done**; `passLog` shows the full trace (pass 1-2, pass 3 sections 1/3→2/3→3/3, pass 4-8); `payload.sections` recorded with timestamps; `attempts` matches the 9-step model. ✅
- **Resumable:** each call resumes from persisted `current_pass` (passLog accumulates across calls, no restart from 0). ✅
- `createContentJob` de-dupes; cron `?ping` works; **`audit_tenant_rls()` = 0**. No `content_pages` writes (pure state machine). ✅

## Roadmap
**S4-D1 → DONE** (durable resumable runner proven). Next: **S4-D2** — replace the no-op for passes 1-3 with REAL AI (pass 1 research→brief, pass 2 outline, pass 3 section-by-section into `payload`, reusing writer.ts primitives; no `content_pages` write yet). Then S4-D3 (passes 4-7), S4-D4 (pass 8 + final write), S4-D5 (UI/resume/workflow wiring).
