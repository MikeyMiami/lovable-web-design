---
name: automation-config
description: Use when seeding, editing, or reviewing the exact message copy, timing, and exit rules for the automation drips on a client site — the review-request SMS drip, the one-year follow-up SMS drip, the website lead-form drip, the discount-claim drip, the missed-call textback drip, and the owner email notifications. This is the canonical content "snapshot" so messages are not written per client. NOT for feature mechanics (use features) or form field layouts (use opt-in-forms).
---

# Automation Config — canonical copy, timing & exit rules

Seed these EXACTLY (casing/punctuation/typos/line breaks included). All copy is formatted with intended line breaks — preserve them. Marketing SMS obey the SMS Send Window (9am–7pm client tz) + daily send cap; lead-form SMS branches on Business Hours. Customer SMS are also editable on-site after seeding. Day offsets are from enrollment into that drip.

Merge keys:
- Built-in: `first_name`, `phone`, `review_link` (per-contact tracked redirect, review drip only).
- Per-client template_vars: `company_owner_first_name`, `company_name`, `review_request_link`, `discount__on_referral`, `company_website_link`, `discount_amount`, `website_terms_page_link`.
- Per-client template_vars also include `quote_form_link` (defaults to the site lander `{company_website_link}`; overridable in /admin-view Settings — the page hosting the quote form).
- Dynamic (not template_vars): `message.body`, `request_time` (client tz), `full_name`, `your_message`, `caller_phone`, `call_time` (client tz), `feedback_message`, `email`.
- Naming: `{first_name}` customer-facing; `{full_name}` internal notifications.
- Formatting standard: internal notifications + emails stack details (Name / Phone / Message) on separate lines — never inline.

---

## Drip 1 — Review Request SMS Drip
Opt-out keyword **`pass`** (whole-word; + standard STOP/etc.). Exit on click at ANY check stage → status `Review Completed`, exit, hand off to One-Year drip (unless opted out).

**SMS 1 — day 0:**
> Hi {first_name}! This is {company_owner_first_name}. If you loved working with {company_name}, would you mind leaving us a review? We really appreciate it! Here's the link:
>
> {review_link}

**Wait 4 days → check. Clicked → `Review Completed`, exit. Else SMS 2:**
> Hi {first_name}! I see you haven't left a review yet. If you loved {company_name}, could you leave one? It's a HUGE help for us!
>
> {review_link}

**Wait 7 days → check. Else SMS 3:**
> Hi {first_name}! I see you haven't left a review for {company_name} yet. It takes 20 seconds, and that review helps us for YEARS to come! This link makes it easy:
>
> {review_link}

**Wait 7 days → check. Else SMS 4:**
> Hi {first_name}! Don't forget to leave us a review for {company_name}. It helps us serve our community better when more people find us! Here's the link:
>
> {review_link}

**Wait 48 hours → check. Clicked → `Review Completed`, exit. Else internal notification (terminal, not a customer text):**
> Hey {company_owner_first_name}!
>
> We've attempted to get {first_name} to leave you a review 4 times over the last 4 weeks. Try to get in touch with them — they'll have the link in their text messages.
>
> Name: {first_name}
> Phone: {phone}
>
> Here's your direct review link if you need it: {review_request_link}
>
> (Do NOT reply to this message; it's not the client!)

On completion (clicked OR ran all 4 without opt-out) → enroll into One-Year drip. Opted-out → not enrolled.

---

## Drip 2 — One-Year Follow-Up SMS Drip
Enrollment: automatic handoff from review-drip completion (no form). Exit on REPLY (non-opt-out → remove + interest notification), OPT-OUT (remove, silent), or DISCOUNT-FORM SUBMIT (remove). Never exit on click.

**SMS 1 — day 30:**
> Hey {first_name}! I'm running a season special this week and giving {discount__on_referral}.
>
> It's only for the first three people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount
>
> -{company_owner_first_name} from {company_name}

**Interest notification (on ANY reply during the drip, then remove):**
> Hey {company_owner_first_name},
>
> {first_name} just replied to your return/referral discount offer in the 1-year follow-up sequence!
>
> Their response: {message.body}
>
> You can reach them at {phone} if needed.
>
> (Do NOT reply to this message; it's not the client!)

**Wait 8 weeks → SMS 2:**
> Hey {first_name}! I'm running a customer anniversary special for the next 6 days and giving {discount__on_referral}, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount
>
> -{company_owner_first_name} from {company_name}

**After SMS 2 → internal notification:**
> {company_owner_first_name}, it's been 3 months since you added {first_name} into your 1-year follow-up sequence.
>
> We just sent them a discount offer to ask for referrals!
>
> Their number is {phone} if you want to reach out / or they contact you.
>
> (Do NOT reply to this message; it's not the client!)

**Wait 3 months → SMS 3:**
> Hey {first_name}! I'm running a loyalty special this week and giving {discount__on_referral}.
>
> It's only for the first three people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount
>
> -{company_owner_first_name} from {company_name}

**Wait 3 months → SMS 4:**
> Hey {first_name}! I'm running a special this week and giving {discount__on_referral}.
>
> It's only for the first four people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount
>
> -{company_owner_first_name} from {company_name}

**Wait 3 months → SMS 5:**
> Hey {first_name}! I'm running an anniversary special giving {discount__on_referral}.
>
> It's only for the next 6 days, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount
>
> -{company_owner_first_name} from {company_name}

**After SMS 5 → final internal notification + remove (end of drip):**
> Hey {company_owner_first_name}!
>
> It's been about a year since we added {first_name} to your 1-year follow-up sequence for referrals / return-customer discounts. We're removing them from further follow-up.
>
> If you'd like to contact them for a referral or to see if they'd use your service again, reach them at {phone}.
>
> (Do NOT reply to this message; it's not the client!)

The interest notification fires on a reply after ANY of SMS 1–5.

---

## Drip 3 — Website Lead-Form Drip
Branches on Business Hours (separate setting). `{full_name}` internal, `{first_name}` customer-facing.

**Internal notification to client (both branches, ~30s / on submit):**
> New Lead from Website lead-form!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've let them know you'll be in touch soon.
>
> (Do NOT reply to this message; it's not the client!)

**SMS #1 to lead — DURING business hours only (single text, correctly spelled):**
> Hey {first_name}! Just got your form! I'll be in touch shortly!
> -{company_owner_first_name} with {company_name}

**After-hours SMS to lead — OUTSIDE business hours (replaces #1):**
> Hey {first_name}, just got your form. We'll be in touch as soon as possible!
> -{company_owner_first_name} with {company_name}

**After-hours owner notification — outside business hours (after the after-hours SMS):**
> Hey {company_owner_first_name}!
>
> {full_name} submitted a request on your website at {request_time} — outside your business hours, so we sent them an after-hours reply.
>
> Phone: {phone}
>
> Reach out when you're back.
>
> (Do NOT reply to this message; it's not the client!)

**Day-10 owner reminder — BOTH branches; suppress if lead's phone is now in the review automation; includes Auto-Enroll button:**
> Hey {company_owner_first_name},
>
> It's been about 10 days since {full_name} filled out a request on your website. If you've worked with them, please remember to add their info to your marketing form. This is important!
>
> Name: {full_name}
> Phone: {phone}
>
> If you haven't added them yet, add their info into the Review Request form — or auto-enroll them below.
>
> [Auto-Enroll button]
>
> (Do NOT reply to this message; it's not the client!)

---

## Drip 4 — Discount-Claim Drip
On submit of the discount form. If submitter is in the One-Year drip, the submit also EXITS them from it.

**On submit → internal notification to client (immediate):**
> Hey {company_owner_first_name},
>
> {first_name} just filled out your discount form on the website!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've told them you'll be reaching out soon.
>
> (Do NOT reply to this message; it's not the client!)

**Wait 2 minutes → SMS to lead:**
> Hey {first_name}, just got your discounted request! I'll be in touch shortly and get you that discount!
> -{company_owner_first_name} with {company_name}

Then ends.

---

## Drip 5 — Missed-Call Textback
Fires 24/7 (live call; not gated by send window or Business Hours). Trigger: Twilio call status `busy`/`no-answer`/`canceled`/`failed` (literal Twilio strings; voicemail reports as `completed` and does NOT fire). Re-eligibility: fires only if this contact (client_id + phone) has NOT received a missed-call textback in the last 7 days (boundary = 7 days from the last send). Wait 1 min → SMS #1 + internal notification → wait 2 min → SMS #2 only if no reply.

**SMS #1 (after 1-min wait):**
> Hey, sorry I missed you! I'll get back to you as soon as possible!
>
> If you want to give me a few details about the job, that would be great. You can click this link for a free quote:
>
> {quote_form_link}
> -{company_owner_first_name} from {company_name}

**SMS #2 (after 2-min wait, only if no reply):**
> Look forward to hearing from you!... In the meantime are there any quick questions I can answer here for ya?

**Internal notification (fires with SMS #1):**
> You missed a call from {caller_phone} at {call_time}, so we sent them a text.
>
> View the conversation here: [Open conversation button]

`{quote_form_link}` defaults to the site lander, overridable in Settings. Dynamic keys: `{caller_phone}`, `{call_time}` (client tz). A brand-new caller has no name — notification keys off phone + time. If the caller submits the quote form, they also enter the Lead-Form drip (intentional, independent).

---

## Drip 6 — Customer Review Reactivation
Bulk-upload past customers → drip-fed slowly to win reviews organically (don't flag Google). Source `reactivation`. Per-drip safety caps: max 50 new enrollments/day, max 2 dripped every 20 min. Cadence: SMS 1 immediately → +24h → +24h → +24h, all within the send window. Dedup guard: skip contacts already through reactivation or already `Review Completed`. Click → exit + funnel + reactivation click notification. One-Year handoff only on `Review Completed`.

**Uses the SAME 4 message texts as Drip 1 (Review Request §4)** — no separate copy. (No "pass" P.S. line; opt-out still functions via webhook.)

**Reactivation click notification (owner mobile app; fires on click/landing; show only fields present):**
> {company_owner_first_name}, you just got a review link click from your Customer Review Reactivation campaign!
>
> Customer Info:
> Name: {full_name}
> Phone: {phone}
> Email: {email}

---

## Owner Email Notifications (§7d)
Sent in ADDITION to the in-app notification when a lead-form or discount-form submission occurs. One email per lead. Channel: Lovable NATIVE transactional email (from the client's sending subdomain; not the external marketing sender). Phone displays as text (no click-to-call in email).

**Subject: New Website Lead** (business-hours version):
> Hey {company_owner_first_name},
>
> You've got a new lead from your website form!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've already texted them to say you'll be in touch. Open your app to see the conversation.

**Subject: New Website Lead** (after-hours version):
> Hey {company_owner_first_name},
>
> You've got a new lead from your website form — submitted at {request_time}, outside your business hours, so we sent them an after-hours reply.
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> Open your app and reach out when you're back.

**Subject: New Referral/Discount Lead:**
> Hey {company_owner_first_name},
>
> {first_name} just filled out your discount form!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've told them you'll be reaching out soon. Open your app to see the details.

**Subject: New Website AI Chat Lead** (chat-widget variant of New Website Lead — §7e; same business-hours/after-hours branching as the website lead form, since it feeds the same lead-form drip):
> Hey {company_owner_first_name},
>
> You've got a new lead from your website AI chat!
>
> Name: {full_name}
> Phone: {phone}
> Message: {your_message}
>
> We've already replied to them in the chat. Open your app to see the conversation.

**Subject: We Saved You From a Negative Review** (fires when a contact submits `/api/public/r/feedback` below threshold):
> Hey {company_owner_first_name},
>
> We just saved you from getting a bad Google review. You can read about this customer's experience here:
>
> Name: {full_name}
> Email: {email}
> Phone: {phone}
> Message: {feedback_message}

(Same content also fires as a mobile-app notification. The contact is marked `Negative Review` — NOT enrolled in the One-Year drip.)

---

## Seeding rules
- Seed all of the above as `templates` rows + `sequences` steps_json, verbatim — including line breaks.
- Verify required `template_vars` exist before activating: `company_owner_first_name`, `company_name`, `review_request_link`, `discount__on_referral`, `company_website_link`, `discount_amount`, `website_terms_page_link`, `quote_form_link`. Missing keys render blank silently — don't let a client go live with these unset.
