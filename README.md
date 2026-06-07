# Lovable Web Design

A library of skills and reference docs for building websites with [Lovable](https://lovable.dev).

This repo is the single source of truth for the reusable skills, prompts, and `.md`
guides used across Lovable website builds. Skills are added here, version-controlled,
and updated over time so improvements are tracked and never lost.

## 📐 Source of truth

**[docs/platform-spec-source-of-truth.md](docs/platform-spec-source-of-truth.md)** is the
canonical record of all build decisions for the multi-tenant Reviews / SMS automation
platform. **Skills are derived FROM this spec** — when a decision lands, update the spec
first, then regenerate/adjust the affected skill. Status tags in the spec: `[LOCKED]`
decided · `[BUILD]` net-new to construct · `[TBD]` awaiting input.

## Structure

```
lovable-web-design/
├── README.md              # You are here
├── docs/
│   └── platform-spec-source-of-truth.md   # Canonical build decisions
├── skills/                # One folder per skill (derived from the spec)
│   └── <skill-name>/
│       └── SKILL.md       # The skill definition / instructions
└── _template/             # Copy this to start a new skill
    └── SKILL.md
```

## Adding a new skill

1. Copy the `_template/` folder into `skills/` and rename it to your skill's
   kebab-case name (e.g. `skills/hero-section-builder/`).
2. Fill in `SKILL.md`.
3. Commit and push:
   ```
   git add skills/<skill-name>
   git commit -m "Add <skill-name> skill"
   git push
   ```

## Updating a skill

Edit the relevant `SKILL.md`, then commit with a clear message describing the change.
Git history keeps every previous version, so updates are safe and reversible.

## Planned skill set

Derived from the spec (§1). Checked = authored in this repo.

- [ ] `/scratch-foundation` — deterministic core (schema, RLS, helpers, server-fn/route skeleton, auth/roles)
- [ ] `/features` — per-feature mechanics & build scope
- [ ] `/automation-config` — exact message copy + timing
- [ ] `/opt-in-forms` — which forms feed which automations
- [ ] `/mobile-app` — client app (Conversations, Review Request, Notifications)
- [ ] `/admin-view` — admin tabs/settings on the client website
- [ ] `/launch-check` — pre-go-live verification gate
- [ ] `/new-client-site` — orchestrates the from-scratch build
- [ ] `/onboard-from-form` _(pending decisions)_
- [ ] `/theme-to-brand` _(pending decisions)_

## Index of authored skills

<!-- Add a line here for each skill as its SKILL.md is created -->
_No skills authored yet — derive the first one from the spec._
