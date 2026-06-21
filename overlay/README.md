# overlay —— AI-SDLC 方法论注入层（gsd 主干消费）

把《AI 自动化开发闭环方案》的方法论注入 gsd 工作流。**全部注入目标项目本地，零升级风险**——
`integrate-engines.sh` 重新整合 gsd 上游时不会覆盖这些（它们不在 `engine/gsd-core/` 里）。

## 注入点（均经 gsd 源码验证）

| overlay 内容 | 装到目标项目 | 谁消费它（gsd 源码证据） |
|--------------|--------------|--------------------------|
| `claude-md/sdlc-conventions.md` | `CLAUDE.md` 的 conventions 段 | gsd-planner.md:44 / gsd-verifier.md:50 强制读 `./CLAUDE.md` |
| `skills/sdlc-gates/` | `.claude/skills/sdlc-gates/` | gsd-plan-checker.md:56 自动扫描 `.claude/skills/` |
| `commands/sdlc-*.md` | `.claude/commands/` | gsd 命令加载扫描目录，无前缀白名单，自定义命令与 /gsd 共存 |
| `agents/*.md`（如有） | `.claude/agents/` | 同上，自定义 agent 共存 |
| `config/sdlc-config-overrides.json` | 合并进 `.planning/config.json` | gsd 读 config 决定门控（verifier/security/gates 开关） |

## 8 条方法论 → 注入点映射

| 方法论 | 主注入点 |
|--------|----------|
| 测试金字塔 | skills/rules/test-pyramid.md + CLAUDE.md |
| 双验证门 | skills/rules/dual-verification.md + config(verifier/security) + /sdlc-gates |
| 测试独立于实现 | skills/rules/test-independence.md + CLAUDE.md |
| 需求质量矩阵 | skills/rules/requirement-matrix.md |
| 影响分析门 | skills/rules/impact-analysis.md + /sdlc-impact |
| 自愈封顶 | skills/rules/self-healing-cap.md + CLAUDE.md |
| 可追溯链 | skills/rules/traceability.md + /sdlc-trace |
| 发布安全 | skills/rules/progressive-release.md + /sdlc-release |

## 为什么不直接改 gsd 自带文件

gsd 的 `gsd-core/references/`、`agents/`、`templates/` 会被 `integrate-engines.sh` 重新整合覆盖。
注入目标项目本地层（`.planning/` + `.claude/skills|commands|agents`）则永不被覆盖，升级零摩擦。

## overlay 即"两仓优点合并层"

spec-kit 的方法论优点已被本 overlay 用 **gsd 原生形式**吸收，无需再装一套 spec-kit（避免方案 §16.4「整包并存两套框架」）：

| spec-kit 独有能力 | overlay 对应物（gsd 原生） |
|-------------------|---------------------------|
| `constitution`（项目宪章） | `claude-md/sdlc-conventions.md`（CLAUDE.md 工程铁律段） |
| `checklist`（质量清单） | `skills/sdlc-gates/`（8 条门禁规则） |
| `clarify`（结构化澄清） | `skills/.../requirement-matrix.md`（7 类必覆盖）+ gsd discuss-phase |
| `analyze`（一致性分析） | gsd plan-checker + `/sdlc-gates` 双门 |

gsd×spec-kit 经实测**文件级无冲突**（命名空间 `/gsd-*` vs `/speckit.*`，`.planning/` vs `.specify/`，
spec-kit 不写 settings.local.json）。需要 spec-kit 原命令的团队可 `SPECKIT_INSTALL=1 bash install.sh`，
默认不装以守单一工作流。
