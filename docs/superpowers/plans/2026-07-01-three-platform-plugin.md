# Swift-Agent-Skills 三平台插件化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Swift-Agent-Skills 仓库打包为 Claude Code、Codex、OpenCode 三平台都支持的插件形式，用户可用各自平台原生机制一键获取全部 31 个 Swift skills。

**Architecture:** 保留 `skills/<category>/<name>/` 嵌套源结构不变，新增 `scripts/build.sh` 生成 `dist/skills/<name>/` 扁平视图。三平台共用 dist/skills/：Claude Code 用顶层 `.claude-plugin/plugin.json` 清单，Codex 用原生 SKILL.md 发现 + marketplace config.toml，OpenCode 用 `skills.paths` 配置。删除现有 opencode TS 插件机制和上游残留的 .claude-plugin 目录。

**Tech Stack:** Bash（构建脚本）、JSON（插件清单）、Markdown（README 文档）

## Global Constraints

- 源 skills/ 目录内容不修改（仅删除 4 个内嵌 .claude-plugin/ 目录）
- scripts/sync.sh 和 scripts/catalog.json 不修改
- dist/ 提交到 git（用户 clone 即用，无需构建）
- build.sh 用 python3 解析 frontmatter（与 sync.sh 一致，jq 不保证可用）
- build.sh 用 rsync（回退 tar）复制（与 sync.sh 一致）
- bash 3.2 兼容（macOS，与 sync.sh 一致：无 declare -A、无 mapfile）

---

### Task 1: 创建构建脚本 scripts/build.sh

**Files:**
- Create: `scripts/build.sh`

**Interfaces:**
- Consumes: `skills/<category>/<name>/SKILL.md`（现有源目录）
- Produces: `dist/skills/<name>/`（扁平视图，三平台共用）

- [ ] **Step 1: 创建 scripts/build.sh**

```bash
#!/usr/bin/env bash
# Build flat dist/skills/<name>/ from nested skills/<category>/<name>/.
# Validates SKILL.md frontmatter (name matches dir, description present).
# Idempotent: rm -rf dist/skills before copying. Does not auto-commit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/../skills"
DIST_DIR="$SCRIPT_DIR/../dist/skills"

# Validate source directory.
if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "ERROR: skills directory not found at $SKILLS_DIR" >&2
  exit 1
fi

# Clean dist/skills (idempotent).
rm -rf "${DIST_DIR:?}"
mkdir -p "$DIST_DIR"

synced=0
warned=0
failed=0

# Walk skills/*/*/ (two-level nesting).
for category_dir in "$SKILLS_DIR"/*/; do
  [[ -d "$category_dir" ]] || continue
  for skill_dir in "$category_dir"*/; do
    [[ -d "$skill_dir" ]] || continue

    skill_path="${skill_dir%/}"
    skill_name="$(basename "$skill_path")"

    if [[ ! -f "$skill_dir/SKILL.md" ]]; then
      echo "  WARN: no SKILL.md in $skill_path, skipping" >&2
      skipped=$((skipped + 1))
      continue
    fi

    # Validate frontmatter: name and description.
    validation="$(python3 -c '
import sys, re

skill_path = sys.argv[1]
skill_name = sys.argv[2]

with open(skill_path + "/SKILL.md", "r") as f:
    content = f.read()

# Extract YAML frontmatter between --- delimiters.
match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
if not match:
    print("WARN\t" + skill_name + "\tno frontmatter block found")
    sys.exit(0)

fm = match.group(1)

# Extract name field.
name_match = re.search(r"^name:\s*(.+?)\s*$", fm, re.MULTILINE)
if not name_match:
    print("WARN\t" + skill_name + "\tfrontmatter missing name field")
else:
    fm_name = name_match.group(1).strip().strip("\"'")
    if fm_name != skill_name:
        print("WARN\t" + skill_name + "\tfrontmatter name (" + fm_name + ") != dir name (" + skill_name + ")")

# Extract description field.
if not re.search(r"^description:\s*\S", fm, re.MULTILINE):
    print("WARN\t" + skill_name + "\tfrontmatter missing or empty description")
' "$skill_path" "$skill_name" 2>&1)"

    if [[ -n "$validation" ]]; then
      echo "  $validation" >&2
      warned=$((warned + 1))
    fi

    # Copy to dist/skills/<name>/ (flat), excluding .git.
    target="$DIST_DIR/$skill_name"
    mkdir -p "$target"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --exclude='.git' "$skill_dir" "$target/"
    else
      # Fallback: tar pipe excluding .git (portable, no rsync needed).
      ( cd "$skill_dir" && tar -cf - --exclude='./.git' . ) | ( cd "$target" && tar -xf - )
    fi

    # Remove upstream .claude-plugin if present in the copied skill.
    if [[ -d "$target/.claude-plugin" ]]; then
      rm -rf "${target:?}/.claude-plugin"
    fi

    echo "  built: $skill_name"
    synced=$((synced + 1))
  done
done

echo ""
echo "Build complete: $synced built, $warned warned, $failed failed."
```

- [ ] **Step 2: 赋予执行权限**

Run: `chmod +x scripts/build.sh`
Expected: 无输出，退出码 0

- [ ] **Step 3: 运行 build.sh 验证生成 dist/skills/**

Run: `./scripts/build.sh`
Expected: 输出 31 个 "built: <name>" 行，结尾 "Build complete: 31 built, X warned, 0 failed."

- [ ] **Step 4: 验证 dist/skills/ 结构**

Run: `ls dist/skills/ | wc -l && find dist/skills -name SKILL.md | wc -l`
Expected: 31（目录数）和 31（SKILL.md 数）

- [ ] **Step 5: 验证 dist 中无 .claude-plugin 残留**

Run: `find dist/skills -name ".claude-plugin" -type d | wc -l`
Expected: 0

- [ ] **Step 6: 提交**

```bash
git add scripts/build.sh dist/skills/
git commit -m "Add build.sh to generate flat dist/skills/ for multi-platform support

Flattens skills/<category>/<name>/ into dist/skills/<name>/ with
frontmatter validation (name matches dir, description present).
Excludes upstream .claude-plugin directories from the flat copy."
```

---

### Task 2: 创建 Claude Code 插件清单

**Files:**
- Create: `.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: `dist/skills/`（Task 1 产出）
- Produces: `.claude-plugin/plugin.json`（Claude Code 顶层插件清单）

- [ ] **Step 1: 创建 .claude-plugin/plugin.json**

```json
{
  "name": "swift-agent-skills",
  "version": "0.1.0",
  "description": "31 curated Swift and Apple platform agent skills for SwiftUI, SwiftData, Swift concurrency, testing, and more.",
  "author": { "name": "Paul Hudson", "url": "https://hackingwithswift.com" },
  "license": "MIT",
  "repository": "https://github.com/SameTrouble/Swift-Agent-Skills",
  "skills": "./dist/skills"
}
```

- [ ] **Step 2: 验证 JSON 合法性**

Run: `python3 -m json.tool .claude-plugin/plugin.json >/dev/null && echo "valid"`
Expected: `valid`

- [ ] **Step 3: 提交**

```bash
git add .claude-plugin/plugin.json
git commit -m "Add Claude Code plugin manifest pointing to dist/skills"
```

---

### Task 3: 删除 opencode TS 插件机制和根目录 opencode 专属文件

**Files:**
- Delete: `.opencode/`（整个目录：plugins/swift-skills.ts、package.json、package-lock.json、INSTALL.md、.gitignore、node_modules/）
- Delete: `package.json`（根目录 opencode 插件专属）
- Delete: `package-lock.json`（根目录 opencode 插件专属）
- Delete: `tsconfig.json`（根目录 opencode 插件专属）

**Interfaces:**
- Consumes: 无
- Produces: 无（纯删除，移除已废弃的 opencode TS 插件机制）

- [ ] **Step 1: 删除 .opencode 目录**

Run: `rm -rf .opencode`
Expected: 无输出，退出码 0

- [ ] **Step 2: 删除根目录 opencode 专属文件**

Run: `rm -f package.json package-lock.json tsconfig.json`
Expected: 无输出，退出码 0

- [ ] **Step 3: 验证删除完成**

Run: `ls .opencode package.json package-lock.json tsconfig.json 2>&1`
Expected: 4 行 "No such file or directory" 错误

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "Remove opencode TS plugin mechanism and root packaging files

Replaced by skills.paths config (documented in README). Removes:
- .opencode/ directory (swift-skills.ts, INSTALL.md, package files)
- root package.json, package-lock.json, tsconfig.json
Existing users migrate from plugin:[...] to skills.paths config."
```

---

### Task 4: 删除 4 个 skills 内嵌的 .claude-plugin 目录

**Files:**
- Delete: `skills/swiftui/swiftui-pro/.claude-plugin/`
- Delete: `skills/concurrency/swift-concurrency-pro/.claude-plugin/`
- Delete: `skills/testing/swift-testing-pro/.claude-plugin/`
- Delete: `skills/focus/swift-focusengine-pro/.claude-plugin/`

**Interfaces:**
- Consumes: 无
- Produces: 清理后的 skills/ 源目录（无上游残留清单冲突）

- [ ] **Step 1: 删除 4 个内嵌 .claude-plugin 目录**

Run: `rm -rf skills/swiftui/swiftui-pro/.claude-plugin skills/concurrency/swift-concurrency-pro/.claude-plugin skills/testing/swift-testing-pro/.claude-plugin skills/focus/swift-focusengine-pro/.claude-plugin`
Expected: 无输出，退出码 0

- [ ] **Step 2: 验证删除完成**

Run: `find skills -name ".claude-plugin" -type d | wc -l`
Expected: `0`

- [ ] **Step 3: 重新运行 build.sh 确保 dist 中也无残留**

Run: `./scripts/build.sh && find dist/skills -name ".claude-plugin" -type d | wc -l`
Expected: build 输出 "Build complete: 31 built, ..."，find 结果为 `0`

- [ ] **Step 4: 提交**

```bash
git add -A dist/skills/
git commit -m "Remove upstream .claude-plugin dirs from 4 vendored skills

These were upstream remnants (swiftui-pro, swift-concurrency-pro,
swift-testing-pro, swift-focusengine-pro). Now managed by the single
top-level .claude-plugin/plugin.json manifest. Rebuild dist/skills/."
```

---

### Task 5: 更新 .gitignore

**Files:**
- Modify: `.gitignore`

**Interfaces:**
- Consumes: 无
- Produces: 清理后的 .gitignore（移除 node_modules，superpowers 已在 spec 阶段改为根锚定）

- [ ] **Step 1: 查看 .gitignore 当前内容**

Run: `cat .gitignore`
Expected:
```
.DS_Store
.worktrees/
node_modules/
/superpowers/
```

- [ ] **Step 2: 移除 node_modules 行**

将 `.gitignore` 内容改为：
```
.DS_Store
.worktrees/
/superpowers/
```

- [ ] **Step 3: 提交**

```bash
git add .gitignore
git commit -m "Remove node_modules from .gitignore (no longer needed)"
```

---

### Task 6: 更新 README

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: `.claude-plugin/plugin.json`（Task 2）、`dist/skills/`（Task 1）
- Produces: 三平台安装说明文档

- [ ] **Step 1: 更新标题副标题**

将 README 第 5 行：
```
<h1 align="center">Swift Agent Skills for Claude Code, Codex, and more</h1>
```
改为：
```
<h1 align="center">Swift Agent Skills for Claude Code, Codex, and OpenCode</h1>
```

- [ ] **Step 2: 替换 "Use as an opencode plugin" 章节为三平台 Installation 章节**

将 README 中从 `## Use as an opencode plugin` 到 `## License` 之前的全部内容（即第 172-208 行：opencode plugin 章节、Alternative install methods、Syncing skills 章节）替换为：

```markdown
## Installation

This repository is packaged as a plugin for three platforms. All install methods give you the same 31 bundled Swift skills (e.g. `swiftui-pro`, `swiftdata-pro`, `swift-concurrency-pro`). Skills trigger automatically when their description matches your task.

### Claude Code

**Option A — Marketplace install:**

```
/plugin marketplace add SameTrouble/Swift-Agent-Skills
/plugin install swift-agent-skills
```

**Option B — Git clone (local):**

```bash
git clone https://github.com/SameTrouble/Swift-Agent-Skills ~/.claude/plugins/swift-agent-skills
```

Claude Code auto-discovers the `.claude-plugin/plugin.json` manifest and registers all skills under `dist/skills/`.

### Codex

Codex natively discovers `SKILL.md` files. Add this repository as a marketplace in `~/.codex/config.toml`:

**Option A — Marketplace (recommended):**

```toml
[marketplaces.swift-agent-skills]
source_type = "git"
source = "https://github.com/SameTrouble/Swift-Agent-Skills.git"
ref = "main"
```

Then install the plugin via Codex's plugin install command. Skills load at user scope.

**Option B — Drop-in (per-skill path):**

Clone the repo, then add each skill you want to `~/.codex/config.toml`:

```toml
[[skills.config]]
path = "/absolute/path/to/Swift-Agent-Skills/dist/skills/swiftui-pro"
enabled = true
```

### OpenCode

OpenCode discovers skills via `skills.paths` in your `opencode.json`.

**Option A — Global config:**

```json
{
  "skills": { "paths": ["~/.config/opencode/plugins/Swift-Agent-Skills/dist/skills"] }
}
```

**Option B — Project-level config:**

```json
{
  "skills": { "paths": ["./Swift-Agent-Skills/dist/skills"] }
}
```

**Option C — Git clone:**

```bash
git clone https://github.com/SameTrouble/Swift-Agent-Skills ~/.config/opencode/plugins/Swift-Agent-Skills
```

Then reference `dist/skills` in your `skills.paths` as shown above.

#### Migrating from the old opencode plugin

If you previously installed via `plugin: ["swift-agent-skills@git+..."]`, switch to the `skills.paths` config shown above. The TS plugin mechanism has been removed.

### Syncing skills (maintainers)

Vendored skills live under `skills/<category>/<name>/`. To refresh from upstream repos and rebuild the flat distribution:

```bash
./scripts/sync.sh    # re-clone upstreams, copy into skills/
./scripts/build.sh   # flatten skills/ into dist/skills/<name>/
```

Review `git diff` before committing. Both scripts are idempotent.
```

- [ ] **Step 3: 验证 README 结构完整**

Run: `grep -n "^## " README.md`
Expected: 包含 `## Installation`、`## License`，且无 `## Use as an opencode plugin` 残留

- [ ] **Step 4: 提交**

```bash
git add README.md
git commit -m "Update README with three-platform installation instructions

Replaces opencode-only plugin section with installation docs for
Claude Code (marketplace/clone), Codex (marketplace/drop-in), and
OpenCode (skills.paths). Adds migration note for old opencode plugin
users. Documents sync.sh + build.sh maintainer workflow."
```

---

### Task 7: 最终验证

**Files:**
- 无文件变更（纯验证）

**Interfaces:**
- Consumes: 所有前序任务产出
- Produces: 验证结果

- [ ] **Step 1: 验证 dist/skills/ 完整性**

Run: `ls dist/skills/ | wc -l && find dist/skills -name SKILL.md | wc -l && find dist/skills -name ".claude-plugin" -type d | wc -l`
Expected: `31`、`31`、`0`

- [ ] **Step 2: 验证 .claude-plugin/plugin.json 合法且指向 dist/skills**

Run: `python3 -m json.tool .claude-plugin/plugin.json >/dev/null && echo "valid" && grep '"skills"' .claude-plugin/plugin.json`
Expected: `valid` 和 `  "skills": "./dist/skills"`

- [ ] **Step 3: 验证 opencode 旧文件已删除**

Run: `ls .opencode package.json package-lock.json tsconfig.json 2>&1 | grep -c "No such file"`
Expected: `4`

- [ ] **Step 4: 验证无内嵌 .claude-plugin 残留**

Run: `find skills -name ".claude-plugin" -type d | wc -l`
Expected: `0`

- [ ] **Step 5: 验证 .gitignore 内容**

Run: `cat .gitignore`
Expected: 三行 — `.DS_Store`、`.worktrees/`、`/superpowers/`（无 node_modules）

- [ ] **Step 6: 验证 README 无旧章节残留**

Run: `grep -c "Use as an opencode plugin" README.md`
Expected: `0`

- [ ] **Step 7: 验证 git 状态干净**

Run: `git status --short`
Expected: 无输出（工作区干净，所有变更已提交）

## 自审

**1. 规格覆盖：**
- build.sh 生成 dist/skills/ → Task 1 ✓
- Claude Code .claude-plugin/plugin.json → Task 2 ✓
- Codex 安装方式（marketplace + drop-in）→ Task 6 README ✓
- OpenCode skills.paths 配置 → Task 6 README ✓
- 删除 .opencode/ 及根目录 opencode 文件 → Task 3 ✓
- 删除 4 个内嵌 .claude-plugin → Task 4 ✓
- .gitignore 改动 → Task 5 ✓
- README 更新 → Task 6 ✓
- 维护者工作流（sync.sh + build.sh）→ Task 6 README ✓
- 测试策略（dist 完整性、无残留、JSON 合法）→ Task 7 ✓

**2. 占位符扫描：** 无 TBD/TODO。每步都有确切命令和预期输出。

**3. 类型一致性：** `dist/skills/` 路径在所有任务中一致。plugin.json 的 `skills` 字段值 `./dist/skills` 在 Task 2 创建、Task 7 验证。build.sh 的输出路径 `$SCRIPT_DIR/../dist/skills` 与 Task 7 验证路径 `dist/skills/` 一致。
