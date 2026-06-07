---
name: automation-config
description: Use when seeding, editing, or reviewing the exact message copy, timing, and exit rules for the automation drips on a client site — the review-request SMS drip, the one-year follow-up SMS drip, the website lead-form drip, the discount-claim drip, and the owner email notifications. This is the canonical content "snapshot" so messages are not written per client. NOT for feature mechanics (use features) or form field layouts (use opt-in-forms).
---

# Automation Config — canonical copy, timing & exit rules

Seed these EXACTLY (casing/punctuation/typos/line breaks included). All copy is formatted with intended line breaks — preserve them. Marketing SMS obey the SMS Send Window (9am–7pm client tz) + daily send cap; lead-form SMS branches on Business Hours. Customer SMS are also editable on-site after seeding. Day offsets are from enrollment into that drip.

Merge keys:
- Built-in: `first_name`, `phone`, `review_link` (per-contact tracked redirect, review drip only).
- Per-client template_vars: `company_owner_first_name`, `company_name`, `review_request_link`, `discount__on_referral`, `company_website_link`, `discount_amount`, `website_terms_page_link`.
- Dynamic (not template_vars): `message.body`, `request_time` (client tz, human-readable), `full_name`, `your_message`.
- Naming: `{first_name}` customer-facing; `{full_name}` internal notifications.
- Formatting standard: internal notifications + emails stack details (Name / Phone / Message) on separate lines — never inline.

---

## Drip 1 — Review Request SMS Drip
Opt-out keyword **`pass`** (whole-word; + standard STOP/etc.). Exit on click at ANY check stage → status `Review Completed`, exit, hand off to One-Year drip (unless opted out).

**SMS 1 — day 0:**
> Hey {first_name}, this is {company_owner_first_name}! I hope you had a great experience with {company_name}!
>
> We donate a meal to charity for every customer who takes 10 seconds to leave a review. Here's the link: {review_link}

**Wait 4 days → check. Clicked → `Review Completed`, exit. Else SMS 2:**
> Hey {first_name}! I wanted to follow-up because I saw you haven't left a review yet. We donate a meal to charity for every customer that leaves a review!
>
> If you have 10 seconds to help someone you don't know, you're our kind of people. Click here: {review_link}
>
> P.S. Just say 'pass' if you want me to stop texting you

**Wait 7 days → check. Else SMS 3:**
> Little review reminder incase you got extra busy this week (we give a free meal to someone in need for each new review).
>
> Here's the link again: {review_link}

**Wait 7 days → check. Else SMS 4:**
> Hey {first_name}! This is the last time I'll request a review from you I promise...
>
> if you have a sec to leave one we'll donate a meal to a person in need. Here's the link and thanks for helping those in need! {review_link}

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

**SMS #1 to lead — DURING business hours only — [INTENTIONAL TYPO "touchr" — DO NOT CORRECT]:**
> Hey {first_name}! Just got your form! I'll be in touchr shortly!
> -{company_owner_first_name} with {company_name}

**SMS #2 to lead — DURING business hours, the correction (skip if lead already replied):**
> I'll be in *touch* shortly! Sorry I haven't had enough coffee today haha!
> Talk soon!

**After-hours SMS to lead — OUTSIDE business hours (replaces #1 and #2):**
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
Fires 24/7 (live call; not gated by send window or Business Hours). Trigger: inbound call status busy/cancelled/no-answer/voicemail. Re-eligibility: fires only if this contact (client_id + phone) has NOT received a missed-call textback in the last 7 days (boundary = 7 days from the last send). Wait 1 min → SMS #1 + internal notification → wait 2 min → SMS #2 only if no reply.

**SMS #1 (after 1-min wait):**
> Hey, sorry I missed you! I'll get back to you as soon as possible!
>
> If you want to give me a few details about the job, that would be great. You can click this link for a free quote:
>
> {company_website_link}/contact
> -{company_owner_first_name} from {company_name}

**SMS #2 (after 2-min wait, only if no reply):**
> Look forward to hearing from you!... In the meantime are there any quick questions I can answer here for ya?

**Internal notification (fires with SMS #1):**
> You missed a call from {caller_phone} at {call_time}, so we sent them a text.
>
> View the conversation here: [Open conversation button]

Dynamic keys: `{caller_phone}`, `{call_time}` (client tz). A brand-new caller has no name — notification keys off phone + time.

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

---

## Seeding rules
- Seed all of the above as `templates` rows + `sequences` steps_json, verbatim — including line breaks and the intentional "touchr" typo in lead-form SMS #1 (mark do-not-correct).
- Verify required `template_vars` exist before activating: `company_owner_first_name`, `company_name`, `review_request_link`, `discount__on_referral`, `company_website_link`, `discount_amount`, `website_terms_page_link`. Missing keys render blank silently — don't let a client go live with these unset.
