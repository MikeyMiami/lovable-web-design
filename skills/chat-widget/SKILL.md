---
name: chat-widget
description: Use when building the AI chat widget — the corner website widget where a Lovable-native AI answers FAQs from the client's business data and routes quote/pricing interest into the lead pipeline. Covers the opt-in gate, the FAQ vs Request paths, the pricing guardrail, the AI system-prompt hard rules, and the owner notification. Built on the foundation; its knowledge bundle comes from onboard-from-form. The Request path reuses the §7 lead-form enrollment exactly.
---

# AI Chat Widget Lead Opt-In (§7e)

A corner chat widget on the client's marketing site. A Lovable-native AI answers FAQs from the client's business data and routes quote/pricing interest into the SAME lead pipeline as the website lead form (§7). Net-new; the largest single feature. Built on `/scratch-foundation`; knowledge comes from `/onboard-from-form`.

## AI model & knowledge
- **Model:** Lovable's native/built-in AI (no third-party API). NOT per-client fine-tuning — **retrieval**: the client's business info is given to the model as context at chat time.
- **Knowledge bundle [from `/onboard-from-form`]:** About Us, services (detailed), service areas, hours, special/differentiators, business identity + the client's website content. Answer quality = onboarding data captured. Load this bundle as model context for every chat.

## Opt-in gate [LOCKED]
- Widget opens: **"What do you need help with?"** → two options: **Question** and **Request Services / Contact Us**.
- BEFORE the AI converses on EITHER path, the person opts in: **First Name, Last Name, Email, Phone, and their message/question.** SMS opt-in + terms consent language required (phone is collected for texting).
- Contact created with source **`chat_widget`** (distinct from `web_form` — leads attributable to the widget). Phone E.164. (Write via the server fn / admin client, not anon — per foundation §6.)

## Behavior [LOCKED]
- **Question (FAQ) path:** AI answers general questions about the business and its services from the knowledge bundle (e.g. "do you offer drain cleaning?", "what are your hours?").
- **Pricing/quote guardrail:** the AI must NOT quote prices or give official pricing. Any price/quote question → redirect to a request: *"Let me get you an accurate quote — fill in your request and the team will reach out."* General service INFO is answered; PRICING/QUOTES are redirected. System-prompt guardrail (firm).
- **Request path:** works EXACTLY like the main website lead form (§7) — creates the contact, enrolls into the SAME lead-form drip + automations (business-hours branching, single SMS#1, day-10 reminder, owner email). After submit, the AI confirms it sent the request to the team and they'll hear back shortly.
- **The ONLY difference from the website lead form:** the owner notification (in-app + email) reads **"New Website AI Chat Lead"** instead of "New Website Lead." All downstream automation/enrollment is IDENTICAL — do not duplicate the lead-form logic; reuse it, just pass the different notification label.

## AI hard rules (system-prompt guardrails) [LOCKED]
- Never quote prices or give official pricing → always redirect to the request form.
- Only discuss THIS business and its services; don't answer off-topic/general questions unrelated to the business.
- Don't make promises or commitments on the owner's behalf beyond "the team will reach out."
- If unsure / lacks the info → direct them to submit a request so the team can follow up.

## Owner notification copy (variant of §7 / §7d)
**In-app + email subject: New Website AI Chat Lead** (otherwise identical to the website-lead notification/email):
> Hey {company_owner_first_name},
>
> You've got a new lead from your website AI chat!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've already replied to them in the chat. Open your app to see the conversation.

Business-hours / after-hours branching applies the same as §7 (it feeds the same lead-form drip). The notification label is the ONLY copy difference.

## Build notes [BUILD]
- Real-time AI chat UI (corner widget) on the client marketing site; Lovable native AI for responses.
- Opt-in gate before chat; consent capture; `chat_widget` contact source (write via foundation's server-fn path with CORS/allowlist/bot-protection — the widget lives on the cross-origin marketing domain).
- Retrieval context = the `/onboard-from-form` knowledge bundle + site content, loaded per chat.
- Request path reuses the §7 lead-form enrollment EXACTLY; only the owner-notification label differs ("New Website AI Chat Lead").
- The pricing guardrail + hard rules go in the system prompt; treat as firm instructions.
- Conversation is visible in the client's mobile-app Conversations tab (§8) like any other thread.
