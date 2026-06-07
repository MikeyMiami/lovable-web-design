# Lovable Web Design

A library of skills and reference docs for building websites with [Lovable](https://lovable.dev).

This repo is the single source of truth for the reusable skills, prompts, and `.md`
guides used across Lovable website builds. Skills are added here, version-controlled,
and updated over time so improvements are tracked and never lost.

## Structure

```
lovable-web-design/
├── README.md              # You are here
├── skills/                # One folder per skill
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

## Index of skills

<!-- Add a line here for each skill as it's created -->
_No skills yet — add your first one to get started._
