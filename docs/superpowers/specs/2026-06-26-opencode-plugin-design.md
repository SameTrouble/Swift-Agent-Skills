# Design: Swift-Agent-Skills as an opencode plugin

**Date:** 2026-06-26
**Status:** Approved (pending spec review)

## Background

The Swift-Agent-Skills repository is currently an awesome-list style index: the
`README.md` links to ~25 external Swift skill repositories (SwiftUI, SwiftData,
Concurrency, Testing, etc.), but the actual `SKILL.md` files do not live in
this repo. The goal is to repackage this collection as an installable opencode
plugin so users get all Swift skills bundled, auto-registered, and
triggerable by description — with a one-line install.

The design follows the reference implementation in
[obra/superpowers](https://github.com/obra/superpowers)
(`.opencode/plugins/superpowers.js` + `package.json` with `main` pointing at
the plugin entry, installable via `plugin: ["name@git+https://..."]`).

## Decisions

- **Vendor all skills into this repo.** The actual `SKILL.md` files (and any
  referenced resources) from each upstream repo are copied into `skills/`.
  Vendoring policy is "all, as-is" — no license filtering at sync time. Each
  skill directory preserves its upstream `LICENSE` if present; the repo root
  `LICENSE` (MIT) covers the plugin code itself.
- **Static skills + sync script.** Skills are committed as static files. A
  maintainer-run shell script (`scripts/sync.sh`) re-clones upstreams and
  refreshes the vendored copies. No runtime network dependency.
- **TypeScript plugin entry.** `.opencode/plugins/swift-skills.ts` exports a
  `Plugin` whose `config` hook injects the repo's `skills/` directory into
  `config.skills.paths`. No `messages.transform` bootstrap injection — Swift
  skills are passive domain knowledge triggered by their `description`
  frontmatter, not a workflow that needs forced behavior injection (unlike
  superpowers' `using-superpowers` bootstrap).
- **GitHub-direct install.** Primary install is
  `"plugin": ["swift-agent-skills@git+https://github.com/SameTrouble/Swift-Agent-Skills.git"]`,
  matching the superpowers install pattern. opencode uses Bun to clone+install
  at startup; the plugin's `config` hook then auto-registers skills.

## Architecture

```
Swift-Agent-Skills/
├── .opencode/plugins/swift-skills.ts   # TS plugin entry (config hook)
├── skills/<category>/<name>/SKILL.md   # vendored skills (static)
├── scripts/
│   ├── catalog.json                    # upstream source manifest (single source of truth)
│   └── sync.sh                         # maintainer sync script
├── package.json                        # name + main + @opencode-ai/plugin type dep
├── README.md                           # existing index + new "Use as opencode plugin" section
└── (existing files retained: LICENSE, CODE_OF_CONDUCT.md, assets/)
```

### Components

**`swift-skills.ts`** — TypeScript plugin module. Resolves the repo-local
`skills/` directory via `__dirname` (computed from `import.meta.url`), then in
the `config` hook pushes it onto `config.skills.paths` with dedup. ~15 lines of
logic. No frontmatter parsing, no file reads, no bootstrap injection.

**`skills/`** — 16 category subdirectories (see Directory layout below). Each
skill lives in its own folder named after the skill, containing `SKILL.md` plus
any resources the skill references (images, `references/`, etc.). opencode
recursively scans `**/SKILL.md` and registers each by its frontmatter `name`
and `description`.

**`catalog.json`** — machine-readable manifest, the single source of truth for
what gets vendored. Each entry has: `name`, `category`, `repo` (GitHub URL),
`subdir` (path within the repo to the skill folder; `.` for root). Multi-skill
repos (e.g. `Dimillian/Skills`) appear as multiple entries with the same `repo`
but different `subdir` and `name`.

**`sync.sh`** — bash script. Reads `catalog.json`, clones each unique upstream
repo once (depth 1, cached in a temp dir via an associative array), copies the
target `subdir` into `skills/<category>/<name>/`. Idempotent: `rm -rf` target
before each copy. Validates `SKILL.md` presence; warns and skips on miss.
Does not auto-commit — maintainer reviews `git diff` after.

**`package.json`** — npm package metadata so `git+https` install works. `name`
matches the `plugin` array key; `main` points at the plugin entry;
`@opencode-ai/plugin` is a dev dependency for types only.

## Data flow

```
[catalog.json]
      │
      ▼  scripts/sync.sh         (maintainer runs, offline-able)
[skills/<cat>/<name>/SKILL.md]   (committed to git)
      │
      ▼  opencode startup        (Bun clones repo via plugin spec)
[swift-skills.ts config hook]    (pushes skills/ onto config.skills.paths)
      │
      ▼  opencode skill loader   (recursive **/SKILL.md scan)
[skills registered by name + description]
      │
      ▼  user writes Swift / agent matches description
[skill content loaded on demand]
```

Single direction, no runtime network dependency. `sync.sh` is the only "pull"
step and is maintainer-run.

## Directory layout

Category subdirectories under `skills/`, aligned with the README sections:

| Directory       | README section            |
| --------------- | ------------------------- |
| `swiftui`       | SwiftUI Skills            |
| `swiftdata`     | SwiftData Skills          |
| `concurrency`   | Swift Concurrency Skills  |
| `testing`       | Swift Testing Skills      |
| `language`      | Swift Language Skills     |
| `accessibility` | Accessibility Skills      |
| `app-intents`   | App Intents Skills        |
| `app-store`     | App Store Skills          |
| `architecture`  | Architecture Skills       |
| `core-data`     | Core Data Skills          |
| `focus`         | Focus Management Skills   |
| `performance`   | Performance Skills        |
| `security`      | Security Skills           |
| `audit`         | Codebase Audit Skills     |
| `tools`         | Tool Skills               |
| `ui`            | User Interface Skills     |

## catalog.json schema

```json
[
  {
    "name": "swiftui-pro",
    "category": "swiftui",
    "repo": "https://github.com/twostraws/SwiftUI-Agent-Skill",
    "subdir": "."
  },
  {
    "name": "swiftui-ui-patterns",
    "category": "swiftui",
    "repo": "https://github.com/Dimillian/Skills",
    "subdir": "SwiftUI-UI-Patterns"
  }
]
```

Fields:
- `name` — skill folder name, matches the skill's frontmatter `name` (lowercase
  hyphen-separated).
- `category` — one of the 16 directory names above.
- `repo` — cloneable GitHub URL.
- `subdir` — path within the repo to the folder containing `SKILL.md`. `"."`
  means root.

## swift-skills.ts (reference skeleton)

```ts
import path from "path";
import { fileURLToPath } from "url";
import type { Plugin } from "@opencode-ai/plugin";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const skillsDir = path.resolve(__dirname, "../../skills");

export default (async () => {
  return {
    config: async (config) => {
      config.skills = config.skills ?? {};
      config.skills.paths = config.skills.paths ?? [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }
    },
  };
}) satisfies Plugin;
```

## package.json

```json
{
  "name": "swift-agent-skills",
  "version": "0.1.0",
  "description": "Curated Swift and Apple platform agent skills for opencode",
  "type": "module",
  "main": ".opencode/plugins/swift-skills.ts",
  "license": "MIT",
  "devDependencies": {
    "@opencode-ai/plugin": "latest"
  }
}
```

## sync.sh behavior

1. Validate `catalog.json` exists and is valid JSON (`python3 -m json.tool`).
   Exit immediately on parse failure.
2. `mktemp -d` for clone workspace.
3. For each catalog entry:
   a. If `repo` not yet cloned this run → `git clone --depth 1 <repo>
      <tmp>/<repo-basename>`. Track cloned repos in a bash associative array
      (`declare -A cloned`) so multi-skill repos clone once.
   b. Source dir = `<tmp>/<repo-basename>/<subdir>`.
   c. If source dir has no `SKILL.md` → warn, skip, continue.
   d. Target dir = `skills/<category>/<name>/`.
   e. `rm -rf` target (idempotent).
   f. `cp -R <source>/* <target>/`.
4. Clean up temp dir.
5. Print summary: counts of synced / skipped / failed.

### Edge cases

| Situation                                         | Handling                                                          |
| ------------------------------------------------- | ----------------------------------------------------------------- |
| `subdir` missing or no `SKILL.md`                 | Warn, skip entry, continue with rest                              |
| Repo private or network failure                   | `git clone` fails → warn, skip, do not abort                       |
| `SKILL.md` frontmatter missing `name`             | Copy anyway, warn maintainer to fix upstream                       |
| Skill dir contains non-`SKILL.md` resources       | Copied alongside, relative paths preserved                         |
| `catalog.json` invalid JSON                       | Exit immediately, sync nothing                                     |
| Orphan dir in `skills/` no longer in catalog      | Not deleted (avoid clobbering manual additions); reported as warning |
| Same repo provides multiple skills (Dimillian)    | Cloned once, each entry copies its own `subdir`                    |

### Non-goals

- No auto-commit after sync; maintainer reviews `git diff`.
- No LICENSE aggregation file; each skill keeps its upstream `LICENSE`.
- No license filtering (vendoring policy is "all, as-is").
- No runtime fetch; skills are static.

## Installation

### Primary: GitHub-direct (matches superpowers pattern)

```json
{
  "plugin": ["swift-agent-skills@git+https://github.com/SameTrouble/Swift-Agent-Skills.git"]
}
```

opencode uses Bun to clone+install at startup. The plugin's `config` hook
registers `skills/` on `config.skills.paths`. Requires `package.json` `name` to
match the package key and `main` to point at the plugin entry.

Pin a version:

```json
{
  "plugin": ["swift-agent-skills@git+https://github.com/SameTrouble/Swift-Agent-Skills.git#v0.1.0"]
}
```

### Alternative 1: local clone, auto-discovery

```bash
git clone https://github.com/SameTrouble/Swift-Agent-Skills ~/.config/opencode/plugins/Swift-Agent-Skills
```

opencode auto-loads `*.ts` files in `~/.config/opencode/plugins/`.

### Alternative 2: skills.paths only (no plugin code)

```json
{
  "skills": { "paths": ["./Swift-Agent-Skills/skills"] }
}
```

For users who want the static skills without executing any plugin code.

## README update

A new section is inserted before the existing "License" section, titled
"Use as an opencode plugin". It documents the three install methods, lists
available skills (generated from / cross-checked against `catalog.json`), and
describes `scripts/sync.sh` for maintainers. The existing awesome-list content
is retained unchanged — it remains the human-readable index; the plugin is the
machine-consumable projection.

## Verification

| Check                                  | Method                                                                   |
| -------------------------------------- | ------------------------------------------------------------------------ |
| TS plugin loads without error          | Start `opencode`; no startup error; `config.skills.paths` contains skills dir |
| Skills registered                      | Use `skill` tool to list; `swiftui-pro` et al. visible                   |
| `sync.sh` idempotent                   | Run twice; `git diff` shows no changes                                   |
| Multi-skill repo handled               | `Dimillian/Skills` produces 4 independent skill folders                  |
| Edge: missing `SKILL.md`               | Bad `subdir` in catalog → script warns and skips, does not abort          |
| No TS type errors                      | `npx tsc --noEmit` passes (needs `@opencode-ai/plugin` in devDeps)       |

## Out of scope

- No `messages.transform` bootstrap injection (Swift skills are passive
  knowledge, not a forced workflow).
- No custom tools or commands registered by the plugin.
- No runtime sync; updating requires maintainer to run `sync.sh` and publish a
  new version.
- No transpilation build step; opencode executes `.ts` directly via Bun.
