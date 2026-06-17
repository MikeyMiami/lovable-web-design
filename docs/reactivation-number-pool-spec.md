# Reactivation Number Pool — requirements spec (placement TBD by Claude Code review)

A NET-NEW agency-level feature. Lets the agency run finite, one-time reactivation review campaigns for a client from a pool of agency-owned, pre-approved A2P numbers (registered under the agency's own "PierceWorks" TextGrid campaign), then auto-releases the number when the campaign fully completes.

> **Supersedes the frozen per-client reactivation drip** (logically deprecated 2026-06-16; see features skill + spec §12). The per-client path (`enrollReactivation`, sends from `clients.twilio_number`) is enrollment-driven only (admin "Upload Customers" CSV) and routes zero real traffic going forward. Frozen code left physically intact.

## Critical framing (for placement decision)
This is **agency traffic on agency-owned numbers** (agency's own brand/campaign), NOT per-client tenant traffic. It must NOT entangle with the frozen per-client model: not `clients.twilio_number` (that's the client's own standing number), not tenant RLS. It MAY reuse the send primitive + drip mechanics. Placement options (CC to weigh against real code):
(a) separate agency-ops layer/module, or (b) agency-level tables in the shared backend (post-freeze, re-validated + re-tagged). Conceptually leans (a) to keep tenant isolation clean.

## What TextGrid provides vs. what our system provides
- **TextGrid:** the send transport (`Messages.json` from the chosen pool number) + the registry where the numbers are registered (agency PierceWorks campaign). TextGrid has NO concept of "number busy dripping a list."
- **Our system:** pool state tracking, availability logic, the dropdown, CSV→assign, the finite-drip queue, and auto-release. ~90% app logic.

## Data model (net-new)
- **reactivation_numbers** (the pool): `id`, `phone_number` (agency number, approved under PierceWorks campaign), `status` (`available` | `in_use`), `current_campaign_id` (nullable), `date_added`. Agency-owned; NOT tenant-scoped.
- **reactivation_campaigns**: `id`, `client_id` (which client this list is FOR), `pool_number_id` (assigned number), `status` (`dropping` | `dripping` | `completed`), `csv_uploaded_at`, `completed_at`, counts.
- Per-contact reactivation enrollments (reuse the existing enrollment/drip structure, scoped to a reactivation_campaign).

## Agency-view UI
1. **Settings → Reactivation Numbers:** add/remove pool numbers (the agency's PierceWorks-approved numbers). Show each number's status + current client if in use.
2. **CSV upload flow:** upload a client's past-customer CSV → **dropdown of pool numbers**:
   - `available` numbers = normal/black/selectable.
   - `in_use` numbers = greyed out + label (e.g. "in use — <client name>").
   - Select an available number → it flips to `in_use`, bound to this reactivation_campaign → list drops on it.
3. Optional: a view of active reactivation campaigns + progress.

## The number-state machine (the core logic)
- On assign: number → `in_use`, `current_campaign_id` set.
- **Release condition (ALL THREE true):** (1) entire CSV enrolled/dropped, (2) no initial sends pending, (3) NO remaining follow-up drip texts for ANY contact on this list. Only then → number `available`, ungreys in dropdown.
- **Release check:** after each drip tick, for the campaign's number, test "zero remaining enrollments with a future next_run_at" → if true, mark campaign `completed` + release number. (A reactivation drip has follow-ups; the number stays `in_use` until the LAST follow-up for the LAST contact fires.)

## Reuses (from frozen master, do not modify)
- The send primitive (send from the pool number instead of clients.twilio_number — pass the `from` explicitly).
- The drip/enrollment mechanics (claim-lease, advance, window/caps if desired).
- TextGrid §2 outbound send.

## Compliance note (already decided)
Bounded, finite, one-time reactivation to the client's OWN past customers, run on the agency's own approved brand/campaign. Defensible as bounded (not a standing bridge). Risk: brand↔content mismatch during the finite window hits the agency number; numbers cycle, so isolate a dirty list to one number. NOT a swap — the client's STANDING setup (site + ongoing automations) is on the client's OWN freshly-approved A2P number, separate from this pool.

## Open questions for CC
- Placement (a vs b above).
- Whether to reuse the per-client runner or a separate finite-campaign runner.
- How reactivation enrollments coexist with per-client enrollments without violating tenant RLS (since these are agency-owned, client_id is "for whom" not "tenant of").
