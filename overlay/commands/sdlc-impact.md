---
description: 改动前影响分析门 —— 定位所有调用方并评估改动安全性（演进场景）
---

# /sdlc-impact —— 影响分析门

在修改任何既有接口/方法/字段**之前**强制运行，防止破坏存量调用方。与 gsd 规划流程配合使用。

输入：要修改的接口/方法/字段名，或当前 phase 目录。

## 步骤
1. **优先用 codegraph 调用图精确定位调用方**（若项目已接 codegraph MCP / 有 `.codegraph/`）：
   - MCP：用 `codegraph_explore` 查目标符号的 callers/调用链。
   - 或 CLI：`codegraph callers <符号>`、`codegraph impact <符号>`、`codegraph affected`。
   - 这是确定性调用图，跨模块/含接口/Feign 间接调用都能定位，优于 grep 猜测。
2. **回退**：无 codegraph 时用全量代码搜索（grep）跨所有模块找引用。
3. 逐调用方评估：依赖什么行为？本次改动是否破坏？
4. 选最安全策略：优先高层(Service)改动而非底层共享方法；优先新增而非改签名；改签名须向后兼容。
5. 标记回归保护集：受影响模块必须重跑的既有测试。

## 产物
写入 `.planning/` 当前 phase 的 IMPACT.md：调用方清单、逐个安全结论、选定策略与理由、回归测试清单。
任一调用方可能被破坏且无安全策略 → 停止改动，升级人工。
