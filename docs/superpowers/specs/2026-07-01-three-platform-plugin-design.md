# 设计：Swift-Agent-Skills 三平台插件化

**日期：** 2026-07-01
**状态：** 已批准（待规格说明书审查）

## 目标

将 Swift-Agent-Skills 仓库打包为 Claude Code、Codex、OpenCode 三个平台都支持的插件形式，用户可用各自平台的原生安装机制一键获取全部 31 个 Swift skills。

## 背景

### 项目现状

- 31 个 vendored Swift skills，位于 `skills/<category>/<name>/`，每个含 `SKILL.md`（frontmatter: `name`、`description`、`license`、`metadata`）
- **opencode**：已通过 `.opencode/plugins/swift-skills.ts`（config hook 注册 skills 路径）支持
- **Claude Code**：仅 4 个 skills 自带上游残留的 `.claude-plugin/plugin.json`，无顶层插件清单
- **Codex**：无任何适配
- 有 `scripts/sync.sh` + `scripts/catalog.json` 维护上游同步

### 三平台机制差异

| 平台 | 技能发现机制 | 清单要求 | 目录结构期望 |
|------|------------|---------|------------|
| Claude Code | `.claude-plugin/plugin.json` 顶层清单 | 必须 | 扁平 `skills/<name>/SKILL.md` |
| Codex | 递归扫描 `SKILL.md`（深度 6） | 无需清单 | 任意嵌套均可 |
| OpenCode | `skills.paths` 配置或 TS 插件 | 无需清单 | 扁平更佳 |

### 核心冲突

当前 `skills/<category>/<name>/` 两级嵌套结构与 Claude Code 期望的扁平 `skills/<name>/SKILL.md` 不兼容。

## 设计决策

1. **保留嵌套源结构，构建扁平视图** — `skills/<category>/<name>/` 作为源不变，新增 `scripts/build.sh` 生成 `dist/skills/<name>/` 扁平视图供三平台共用。
2. **opencode 简化为 skills.paths** — 删除 TS 插件机制，改用文档指导 `skills.paths` 配置指向 `dist/skills/`。破坏性变更，需迁移说明。
3. **dist/ 提交到 git** — 用户 clone 后无需构建即可安装；build.sh 仅维护者同步上游后重新生成时使用。

## 架构

### 目标目录结构

```
Swift-Agent-Skills/
├── skills/                          # 源（保留嵌套，不变）
│   ├── swiftui/swiftui-pro/SKILL.md
│   └── ...（31 个 skills，14 个 category）
├── dist/                            # 构建产物（提交到 git）
│   └── skills/                      # 扁平结构，三平台共用
│       ├── swiftui-pro/SKILL.md
│       └── ...
├── scripts/
│   ├── catalog.json                 # 上游源 catalog（不变）
│   ├── sync.sh                      # 上游同步脚本（不变）
│   └── build.sh                     # 新增：生成 dist/skills/ 扁平视图
├── .claude-plugin/
│   └── plugin.json                  # Claude Code 顶层插件清单
├── README.md                        # 三平台安装说明
├── LICENSE
├── CODE_OF_CONDUCT.md
├── assets/
└── .gitignore
```

### 删除的文件

- `.opencode/` 整个目录（plugins/swift-skills.ts、package.json、package-lock.json、INSTALL.md、.gitignore、node_modules/）
- 根目录 `package.json`、`package-lock.json`、`tsconfig.json`（opencode 插件专属依赖）
- 4 个 skills 内嵌的 `.claude-plugin/` 目录（上游残留，改用顶层清单统一管理）

## 组件设计

### 1. 构建脚本 `scripts/build.sh`

**职责：** 将 `skills/<category>/<name>/` 扁平复制到 `dist/skills/<name>/`，并验证 frontmatter 合规性。

**逻辑：**

1. 清空 `dist/skills/`（幂等，确保删除已移除的 skill）
2. 遍历 `skills/*/*/`（两级目录），每个含 `SKILL.md` 的目录为一个 skill
3. 读取 SKILL.md frontmatter 的 `name` 字段，校验：
   - `name` 存在
   - `name` 与目录名一致（Claude Code 和 Codex 都要求）
   - `description` 存在且非空
4. 不合规则输出 `WARN` 但继续（不阻断构建）
5. 用 rsync（回退 tar）复制到 `dist/skills/<name>/`，排除 `.git`
6. 输出统计：`synced` / `warned` / `failed`

**接口：**
- 输入：`skills/` 目录
- 输出：`dist/skills/` 目录
- 退出码：0（成功，可有 warning）；1（目录结构错误等致命错误）

**frontmatter 校验实现：** 用 `python3`（与 sync.sh 一致，jq 不保证可用）解析 YAML frontmatter，提取 `name` 和 `description` 字段。

**与 sync.sh 的关系：** sync.sh 从上游同步到 `skills/`，build.sh 从 `skills/` 生成 `dist/skills/`。维护者先跑 sync.sh，再跑 build.sh。

### 2. Claude Code 适配 `.claude-plugin/plugin.json`

**清单文件：**

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

**安装方式：**

1. **Marketplace 安装**：用户先 `/plugin marketplace add SameTrouble/Swift-Agent-Skills`，再 `/plugin install swift-agent-skills`
2. **Git clone 本地安装**：clone 到 `~/.claude/plugins/swift-agent-skills`，Claude Code 自动发现 `.claude-plugin/plugin.json`

**清理：** 删除 4 个 skills 内嵌的 `.claude-plugin/` 目录（`swiftui-pro`、`swift-testing-pro`、`swift-concurrency-pro`、`swift-focusengine-pro`），避免与顶层清单冲突。

### 3. Codex 适配

**无需额外清单文件。** Codex 原生递归扫描 `SKILL.md`，`dist/skills/` 中的 SKILL.md frontmatter（`name` + `description`）即为发现机制。

**安装方式：**

1. **Marketplace 安装（推荐）：** 用户在 `~/.codex/config.toml` 添加：
   ```toml
   [marketplaces.swift-agent-skills]
   source_type = "git"
   source = "https://github.com/SameTrouble/Swift-Agent-Skills.git"
   ref = "main"
   ```
   然后通过 Codex plugin install 安装，skills 以 user scope 加载。

2. **Drop-in 用户目录：** clone 仓库后，在 config.toml 中按 skill 配置路径：
   ```toml
   [[skills.config]]
   path = "/absolute/path/to/Swift-Agent-Skills/dist/skills/swiftui-pro"
   enabled = true
   ```

3. **项目级（.agents/skills/）：** 在 Swift 项目中创建 `.agents/skills/` 并 symlink 所需 skills。

### 4. OpenCode 适配

**删除 TS 插件机制，改用 `skills.paths` 配置。**

**安装方式：**

1. **全局配置（opencode.json）：**
   ```json
   {
     "skills": { "paths": ["~/.config/opencode/plugins/Swift-Agent-Skills/dist/skills"] }
   }
   ```

2. **项目级配置：**
   ```json
   {
     "skills": { "paths": ["./Swift-Agent-Skills/dist/skills"] }
   }
   ```

3. **本地 clone：**
   ```bash
   git clone https://github.com/SameTrouble/Swift-Agent-Skills ~/.config/opencode/plugins/Swift-Agent-Skills
   ```
   然后在 opencode.json 中引用 `dist/skills` 路径。

**后向兼容：** 破坏性变更。现有用 `plugin: ["swift-agent-skills@git+..."]` 安装的用户需迁移到 `skills.paths`。README 中提供迁移说明。

### 5. README 更新

**改动点：**

1. 副标题更新为：`Swift Agent Skills for Claude Code, Codex, and OpenCode`
2. 新增 "Installation" 章节，替换现有 "Use as an opencode plugin" 章节，按平台分小节：
   - Claude Code — marketplace + git clone
   - Codex — marketplace config.toml + drop-in
   - OpenCode — skills.paths + git clone
   - 从 opencode plugin 迁移说明
3. "Syncing skills" 章节扩展，说明 sync.sh + build.sh 两步工作流
4. 删除 `.opencode/INSTALL.md`（内容已合并到 README）

### 6. .gitignore 改动

- 移除 `node_modules/`（不再有 node_modules）
- `superpowers/` 改为 `/superpowers/`（根锚定，避免误匹配 `docs/superpowers/`）
- **不**添加 `dist/`（dist 提交到 git）
- 保留 `.DS_Store`、`.worktrees/`

## 维护者工作流

```
1. 编辑 scripts/catalog.json（如需新增/移除 skill）
2. ./scripts/sync.sh     → 刷新 skills/<category>/<name>/
3. ./scripts/build.sh    → 刷新 dist/skills/<name>/
4. git diff              → 审查变更
5. git add && git commit
```

## 错误处理

- **build.sh frontmatter 校验失败：** 输出 WARN，继续构建，不阻断。维护者审查输出决定是否修复上游。
- **build.sh 目录结构错误：** 致命错误，退出码 1。
- **skill 目录名与 name 不一致：** WARN 提示，仍以目录名作为 dist 中的目录名。

## 测试策略

- build.sh 运行后，验证 `dist/skills/` 中目录数 = 31，每个含 SKILL.md
- 验证 `dist/skills/` 中无 `.claude-plugin/` 子目录
- 验证 `.claude-plugin/plugin.json` 是合法 JSON 且 `skills` 字段指向 `./dist/skills`
- 验证 git clone 后无需构建即可看到 `dist/skills/`（dist 已提交）

## 范围边界

**本次做：**
- 新增 `scripts/build.sh`
- 新增 `.claude-plugin/plugin.json`
- 新增 `dist/skills/`（构建产物）
- 删除 `.opencode/` 目录及根目录 opencode 专属文件
- 删除 4 个 skills 内嵌的 `.claude-plugin/`
- 更新 README、.gitignore

**本次不做：**
- 不修改 `skills/` 源目录内容
- 不修改 `scripts/sync.sh` 和 `scripts/catalog.json`
- 不添加 CI/CD 自动构建
- 不添加 Codex 的 `agents/openai.yaml` sidecar 元数据（SKILL.md 已足够）
