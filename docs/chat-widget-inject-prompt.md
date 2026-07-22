# Chat Widget — Canonical Injection Prompt (capture-first)

> **What this is:** the proven Lovable prompt that adds the **capture-first chat widget** to a marketing-site template project. Referenced by `docs/template-build-prompt-TEMPLATE.md` (the master build prompt deliberately excludes the widget — "separately-injected"). **When to run:** immediately after building any NEW style template (styles 2–6). Existing remixes made BEFORE the widget existed need it applied separately (remixes are copies); remixes made AFTER inherit it automatically. First applied 2026-07-16 to `Template — Family-Owned` (CW4-R). Spec authority: `/chat-widget` skill.

```
Add a CHAT WIDGET to this site — a capture-first lead form in a chat skin. It must feel like a chat bubble but functionally
it is a lead form: submitting enrolls the visitor into the same automations as the main lead form, via a dedicated backend
route. One self-contained component; no AI, no streaming, no third-party chat libraries.

1. COMPONENT + RENDER GATE
   - New component (e.g. src/components/ChatWidget.tsx), mounted globally (every page), fixed bottom-right chat bubble.
   - THEMING (required): ALL widget chrome — bubble, panel header, outgoing-bubble accents, buttons — derives from the
     client's brand theme tokens (client.brand_color, same tokens the rest of the site uses). NO hardcoded palette; the
     widget must look native to each client's branding automatically.
   - Render ONLY when the client data has chat_widget_enabled !== false. This field is returned by the existing
     get_client_public data loader — add `chat_widget_enabled` to the client data type and consumption (it's already in
     the RPC's response).
   - In demo mode (no VITE_CLIENT_SLUG), behave exactly like the existing lead form does in demo mode.

2. OPEN STATE (chat panel)
   - Header: business name (from client data) + close button.
   - A "message bubble" from the business showing the GREETING: use client template_vars.chat_widget_greeting when set,
     else the default: "Hi! This goes right to the owner's phone. What can I help you with?"
   - Below it, the form styled as a chat reply: First Name, Last Name, Phone (same client-side E.164 normalization the
     lead form uses), and an optional message textarea labeled "What do you need help with?".
   - CONSENT: the single REQUIRED consent checkbox — reuse the EXACT single-consent marketing skeleton the discount form
     uses (same verbatim copy structure with the site's consent-category tokens, linking to this site's /privacy and
     /terms). The form must not submit without it.
   - Invisible native PoW bot-shield (2026-07-22 — replaces the Turnstile widget): same shared bot-shield module as the site's other forms (challenge from `/api/public/challenge`, Web Worker solve, `pow_token` + hidden `website` honeypot). No visible check UI.

3. SUBMIT — POST to the platform backend route /api/public/chat/optin using the SAME base URL / transport / env the
   existing lead form uses for /api/public/intake (do NOT invent a new host). JSON body:
     {
       slug: <the same site slug used by the data loader (VITE_CLIENT_SLUG)>,
       first_name, last_name,
       phone_e164,                       // E.164 with +
       your_message,                     // omit if empty
       consent: true,
       pow_token (+ website honeypot, empty for humans)
     }
   Response: { ok: true, enrolled: "<sequence>" } on success.

4. SUCCESS STATE — an in-chat conversation, NOT a close: on success the panel STAYS OPEN and the form is replaced by a
   conversation view: the greeting bubble → the visitor's submitted message as an OUTGOING bubble (right-aligned; skip if
   they left the message empty) → an INCOMING reply bubble (left-aligned, styled like the greeting) showing
   client template_vars.chat_widget_confirmation when set, else the default: "Thanks, I've received your message and
   will respond as soon as possible!" It must read as if the business replied to their submission. sessionStorage:
   a visitor who already submitted this session reopens to this conversation view, never the form.

5. ERRORS (as chat bubbles, friendly): 429 → "We're getting a lot of messages right now — please try again in a few
   minutes."; captcha_failed → re-mint + re-solve the PoW challenge and ask to retry; anything else → "Something went wrong — please use
   the contact form or call us."

6. MOBILE: on small screens the panel opens as a full-width bottom sheet; the bubble must not overlap the site's existing
   floating elements; sensible z-index; panel is keyboard-accessible and closable via Escape.

Keep it lightweight (no new deps beyond what the site already has). Do not modify the existing lead form, discount form,
or any other page content.
```

**Post-injection verification:** widget renders (client `chat_widget_enabled` default true) · greeting falls back correctly · submit → contact (source `chat_widget`) + conversation + `channel='chat'` message + lead-form enrollment + "New Website Chat Lead" notification. **Turnstile caveat:** template projects carry the Cloudflare TEST site key — against the live backend secret, submissions will return `captcha_failed` until the site gets its real Turnstile site key (+ its hostname added in the Turnstile dashboard). That swap is part of per-client launch (Phase D/E), not the template build.
