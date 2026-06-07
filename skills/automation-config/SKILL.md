---
name: automation-config
description: Use when seeding, editing, or reviewing the exact message copy, timing, and exit rules for the automation drips on a client site — the review-request SMS drip and the one-year follow-up SMS drip. This is the canonical content "snapshot." Use this to lay in the messages so they don't have to be written per client. NOT for feature mechanics (use features) — this is content only.
---

# Automation Config — canonical copy, timing & exit rules

Seed these EXACTLY. This is the opinionated, ready-to-run snapshot so a new client starts with fully-configured automations. All SMS obey the global send window (9am–7pm in the client's timezone) and the daily send cap. Day offsets are measured from enrollment into that drip. Placeholders are merge fields resolved at send time.

Merge keys used here:
- Built-in: `first_name`, `phone`, `review_link` (the per-contact tracked redirect for the review drip).
- Per-client `template_vars` (set in admin Settings): `company_owner_first_name`, `company_name`, `review_request_link` (client's own direct review link), `discount__on_referral`, `company_website_link`.
- Dynamic (not template_vars): `message.body` (the contact's reply text, captured by the on-reply handler).

---

## Drip 1 — Review Request SMS Drip

Opt-out keyword: **`pass`** (whole-word; in addition to standard STOP/etc.). Exit on click at ANY check stage → set status `Review Completed`, exit, and hand off to the One-Year Follow-Up drip.

**SMS 1 — day 0 (on enrollment, respecting send window):**
> Hey {first_name}, this is {company_owner_first_name}! I hope you had a great experience with {company_name}! We donate a meal to charity for every customer who takes 10 seconds to leave a review. Here's the link: {review_link}

**Wait 4 days → check click. Clicked → `Review Completed`, exit. Not clicked → SMS 2:**
> Hey {first_name}! I wanted to follow-up because I saw you haven't left a review yet. We donate a meal to charity for every customer that leaves a review! If you have 10 seconds to help someone you don't know, you're our kind of people. Click here: {review_link}  P.S. Just say 'pass' if you want me to stop texting you

**Wait 7 days → check. Clicked → exit. Not clicked → SMS 3:**
> Little review reminder incase you got extra busy this week (we give a free meal to someone in need for each new review). Here's the link again: {review_link}

**Wait 7 days → check. Clicked → exit. Not clicked → SMS 4:**
> Hey {first_name}! This is the last time I'll request a review from you I promise... if you have a sec to leave one we'll donate a meal to a person in need. Here's the link and thanks for helping those in need! {review_link}

**Wait 48 hours → check. Clicked → `Review Completed`, exit. Not clicked → internal notification to client's mobile-app Notifications tab (terminal, NOT a customer text):**
> Hey {company_owner_first_name}! We've attempted to get {first_name} to leave you a review 4 times over the course of the last 4 weeks. Try to get in touch with them to leave you a review. They'll have the link in their text messages. Their information: Name: {first_name} Phone: {phone}  Here's your direct review link again if you need it: {review_request_link}

On completion (clicked OR ran through all 4 without opt-out) → enroll into the One-Year Follow-Up drip. Opted-out contacts are NOT enrolled.

---

## Drip 2 — One-Year Follow-Up SMS Drip

Enrollment: automatic handoff from review-drip completion (no form). Exit on REPLY (non-opt-out inbound → remove + interest notification) or OPT-OUT (remove, silent). Never exit on click. Discount links are plain `{company_website_link}/get-your-discount`, untracked.

**Interest notification (fires on ANY reply during the drip, then remove from drip):**
> Hey {company_owner_first_name}, {first_name} just replied to your return/referral discount offer in the 1-year follow-up sequence! Here's their response: {message.body}  You can reach them at {phone} if needed. (Do NOT reply to this message; it's not the client!)

**SMS 1 — day 30:**
> Hey {first_name}! I'm running a season special this week and giving {discount__on_referral}. It's only for the first three people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount  -{company_owner_first_name} from {company_name}

**Wait 8 weeks → SMS 2:**
> Hey {first_name}! I'm running a customer anniversary special for the next 6 days and giving {discount__on_referral}, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount  -{company_owner_first_name} from {company_name}

**After SMS 2 → internal notification to client:**
> {company_owner_first_name}, it's been 3 months since you added {first_name} into your 1 year follow up sequence. We just sent them a little discount offer to ask for referrals! Their number is {phone} if you want to reach out / or they contact you! (Do NOT reply to this message; it's not the client!)

**Wait 3 months → SMS 3:**
> Hey {first_name}! I'm running a loyalty special this week and giving {discount__on_referral}. It's only for the first three people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount  -{company_owner_first_name} from {company_name}

**Wait 3 months → SMS 4:**
> Hey {first_name}! I'm running a special this week and giving {discount__on_referral}. It's only for the first four people, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount  -{company_owner_first_name} from {company_name}

**Wait 3 months → SMS 5:**
> Hey {first_name}! I'm running an anniversary special giving {discount__on_referral}. It's only for the next 6 days, so if you're interested (or know someone who might be), just tap this link: {company_website_link}/get-your-discount  -{company_owner_first_name} from {company_name}

**After SMS 5 → final internal notification + remove from sequence (end of drip):**
> Hey {company_owner_first_name}! It's been about a year since we added {first_name} to your 1 year follow up sequence for referrals / return customer discounts. We are removing them from further follow up. If you want to contact them for a referral or to see if they'd like to use your service again please contact them at {phone}! (Do NOT reply to this message; it's not the client!)

---

## TBD (do not seed yet)
- Customer Review Request Email Drip — steps pending.
- Reactivation / missed-call / one-year discount-claim copy may be revised — confirm before seeding.

## Seeding rules
- Seed all of the above as `templates` rows + `sequences` steps_json, verbatim, exactly as written (including casing and punctuation).
- Verify required `template_vars` keys exist for the client before activating: `company_owner_first_name`, `company_name`, `review_request_link`, `discount__on_referral`, `company_website_link`. Missing keys render blank silently — do not let a client go live with these unset.
