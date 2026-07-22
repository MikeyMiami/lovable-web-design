---
name: chat-widget
description: Use when building or modifying the website CHAT WIDGET — the corner bubble on the client's marketing site that captures leads chat-style (greeting → First/Last/Phone/message form → enrolls the SAME lead-form drip). CAPTURE-FIRST since 2026-07-16: no AI conversation (the AI Q&A path is PARKED, not deleted). Covers the widget UI, the customizable greeting, the opt-in wire contract, conversations-tab threading, the owner notification, and the admin card. NOT for lead-form drip copy/timing (automation-config) or the main website lead form (opt-in-forms §2).
---

# Website Chat Widget — capture-first lead form in a chat skin (§7e)

**PIVOT 2026-07-16 (operator decision):** the widget's job is to **capture the lead, not answer questions**. AI Q&A let visitors get answers and leave without converting; capture-first converts the intent of opening the widget directly into an enrolled, SMS-connected lead. The widget is a chat-styled lead form that behaves EXACTLY like the website lead form once submitted.

## Behavior [LOCKED]

1. **Bubble** (bottom-right, brand-themed) renders ONLY when `clients.chat_widget_enabled` is true (boolean, default TRUE; exposed via `get_client_public` — the anon template reads it).
2. **Two customizable messages per client** (both anon-safe `template_vars` keys, NO dedicated columns; **both seeded into `template_vars` at client-create when absent** so new clients ship with the defaults below; both edited in Admin · Settings → **Chat Widget card** — toggle + two textareas; every write is the LOCKED read-merge-write full-object `template_vars` pattern):
   - **Greeting** — `template_vars.chat_widget_greeting`; default: *"Hi! This goes right to the owner's phone. What can I help you with?"*
   - **Confirmation reply** — `template_vars.chat_widget_confirmation`; default: *"Thanks, I've received your message and will respond as soon as possible!"* Shown as the business's in-chat reply after submit (§7).
3. **Form** (chat-styled): First Name, Last Name, Phone (E.164 client-side), optional message, **single REQUIRED consent checkbox** (reuse the a2p-site-compliance single-consent marketing skeleton verbatim, links to the site's /privacy + /terms — same posture as the discount form), Turnstile.
4. **Submit → `POST /api/public/chat/optin`** — the capture-first contract (as-built):
   `{ slug?, first_name, last_name, phone_e164, email?, your_message?, consent: true, turnstile_token }`
   The route (CORS allowlist + IP/client rate limits + Turnstile): dedupes the contact by (client_id, phone_e164) → source `chat_widget` → `your_message`→`contacts.notes` → **upserts the conversation + inserts the message as `messages.channel='chat'`** (inbound, twilio_sid null) → **enrolls the SAME lead-form drip** (Business-Hours branch → `lead_form_business_hours` / `lead_form_after_hours`) → `chat_widget_lead` event. Re-submits never error (already_enrolled guard; message still recorded). Response `{ ok, enrolled }` — no chat token.
5. **Downstream = identical to the website lead form:** same SMS #1 ("just got your form…"), after-hours variant, day-10 reminder + Auto-Enroll. **The ONLY difference:** the runner's dispatcher sees `source='chat_widget'` and swaps the owner notification to `ai_chat_lead_internal_notify` — label/subject **"New Website Chat Lead"** (renamed from "AI chat" 2026-07-16; template keys keep the `ai_chat_lead*` identifiers).
6. **Conversations tab:** the widget message threads into the contact's conversation (`channel='chat'`); the drip's SMS #1 materializes into the SAME thread; an owner in-app reply goes out as a normal SMS — web-chat lead converts to an SMS thread by design.
7. **Post-submit = an in-chat conversation, NOT a close [LOCKED — operator decision 2026-07-17]:** on success the panel **STAYS OPEN** and the form is replaced by a conversation view: the greeting bubble → the visitor's submitted message as an **outgoing** bubble (right-aligned; skipped if they left it empty) → an **incoming reply** bubble (left, styled like the greeting) showing `template_vars.chat_widget_confirmation` (default above). It must read as if the business replied to their submission. sessionStorage: a visitor who already submitted this session reopens to this conversation view, never the form. Errors (as chat bubbles): 429 → "please try again in a few minutes"; captcha fail → re-render Turnstile + retry copy; else generic fallback.
8. **Brand theming [LOCKED]:** ALL widget chrome — the bubble, panel header, outgoing-bubble accents, buttons — derives from the client's brand theme (`clients.brand_color` → the template's theme tokens, same as the rest of the site). Never a hardcoded palette; the widget must look native to each client's branding automatically.

## Widget component (template-side) [BUILD — CW4-R master template / CW5-R x3 remix]

Lives in the **marketing-site TEMPLATE project** (frontend-only) as one self-contained component. The template already has everything it needs: `VITE_CLIENT_SLUG`, the platform API host used by the existing lead form (reuse the SAME transport/env — do not invent a new base URL), and the Turnstile site key. Render-gate on `chat_widget_enabled` from the client data loader (add the field to its type). Match the existing lead form's demo-mode behavior when no slug is set. **Propagation rule: remixes are COPIES — build in the master template AND apply separately to existing remixes (x3); the parameterized template-build master prompt (`docs/template-build-prompt-TEMPLATE.md`) must include the widget so future style templates get it from birth.**

## PARKED — the AI Q&A path (v2 option, deployed but unused)

`/api/public/chat/stream` (Lovable AI Gateway, gemini-3-flash, layered-prompt design), `/api/public/chat/request`, `src/lib/chat/knowledge.server.ts`, `src/lib/chat/token.server.ts`, and the private `clients.chat_ai_instructions` column all remain in the codebase, **untouched and uncalled**. If AI answers ever return (per-client toggle), the layered-prompt design is in git history + this skill's history: identity → code-locked HARD RULES (no prices, only-this-business, no promises, escalate-if-unsure) → auto-injected business facts (business_name/phone/address/hours/service_area + template_vars) → owner instructions injected last under "hard rules always win". Do not delete the parked files casually; do not wire anything new to them without reviving the design consciously.

## Build status (2026-07-16)

- ✅ CW1 migration: `chat_widget_enabled` (default true) + `chat_ai_instructions` (private, unused/parked) + `messages.channel`; `chat_widget_enabled` exposed in both public RPCs.
- ✅ CW2-R: `optin.ts` rebuilt capture-first (schema, dedupe, conversation+channel='chat' message, lead-form enrollment, `chat_widget_lead` event, tokenless response).
- ✅ CW3-R: Admin Chat Widget card (toggle + merge-safe greeting) + "New Website Chat Lead" copy rename.
- ✅ CW4-R: widget component APPLIED 2026-07-16 in the single template project (which doubles as x3's site — CW5-R moot; future remixes inherit). Live-validated 2026-07-17: greeting/toggle round-trip ✅; submit end-to-end ✅ (after adding the preview origin to x3's allowed_origins — CORS preflight lesson: a new site origin MUST be in `clients.allowed_origins` or the browser never sends the POST).
- ✅ template-build master prompt updated (imports seo-build; requires the inject prompt post-build; VITE_PLATFORM_API_HOST mandatory).
- 🔄 2026-07-17 tweak prompts delivered (apply-status pending): admin card gains the "Confirmation message" textarea (`chat_widget_confirmation`); widget gains the stays-open conversation view (§7).
- Optional micro-fix: `ai_chat_lead_internal_notify` closing line "replied to them in the chat" → "texted them to say you'll be in touch".
