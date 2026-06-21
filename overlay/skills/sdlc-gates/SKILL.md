---
name: sdlc-gates
description: AI-SDLC 全生命周期工程门禁规则。gsd 的 plan-checker/verifier 在规划与验证阶段加载这些规则，确保计划与产出满足测试金字塔、双验证门、测试独立性、影响分析、自愈封顶、可追溯链与发布安全。
---

# SDLC Gates —— 全生命周期工程门禁

本 skill 是 AI-SDLC 方法论的机器可读规则集。gsd 子代理（gsd-plan-checker 扫描 `.claude/skills/`，
gsd-planner / gsd-verifier 读 CLAUDE.md）据此校验计划与产出。

## 规则索引（rules/）

| 规则 | 文件 | 作用阶段 |
|------|------|----------|
| 测试金字塔 | rules/test-pyramid.md | Plan / Verify |
| 双验证门 | rules/dual-verification.md | Verify |
| 测试独立于实现 | rules/test-independence.md | Plan / Execute |
| 需求质量矩阵 | rules/requirement-matrix.md | Discuss / Plan |
| 影响分析门 | rules/impact-analysis.md | Plan（演进） |
| 自愈循环封顶 | rules/self-healing-cap.md | Execute / Verify |
| 可追溯链 | rules/traceability.md | 全程 |
| 发布安全 | rules/progressive-release.md | Ship |

## 使用方式

- 规划阶段：计划必须显式说明各项门如何满足（测试分层、双门命令、影响集、追溯）。
- 验证阶段：两门皆绿才放行；任一红走自愈（≤3 次、有进展），超限转人工。
- 裁判是确定性工具，AI 不自评。
