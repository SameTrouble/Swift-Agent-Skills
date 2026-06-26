# Installing Swift-Agent-Skills for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed

## Installation

Add swift-agent-skills to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["swift-agent-skills@git+https://github.com/SameTrouble/Swift-Agent-Skills.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and
registers all bundled Swift skills automatically.

Verify by asking: "List your available Swift skills"

## Pinning a version

```json
{
  "plugin": ["swift-agent-skills@git+https://github.com/SameTrouble/Swift-Agent-Skills.git#v0.1.0"]
}
```

## Alternative: local clone

```bash
git clone https://github.com/SameTrouble/Swift-Agent-Skills ~/.config/opencode/plugins/Swift-Agent-Skills
```

OpenCode auto-loads `*.ts` files in `~/.config/opencode/plugins/`.

## Alternative: skills.paths only (no plugin code)

```json
{
  "skills": { "paths": ["./Swift-Agent-Skills/skills"] }
}
```

## Usage

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
use skill tool to load swiftui-pro
```

## Updating

Re-run the install or clear OpenCode's package cache. Swift skills are static;
updating requires the maintainer to run `scripts/sync.sh` and publish a new
version.

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i swift`
2. Verify the plugin line in your `opencode.json`
3. Make sure you're running a recent version of OpenCode

### Skills not found

1. Use `skill` tool to list what's discovered
2. Check that the plugin is loading (see above)
