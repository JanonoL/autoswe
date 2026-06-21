# UPSTREAMS —— 上游来源、锁定版本、整合方式

本聚合仓**只整合每个上游的精华**，不 vendor 整仓。整合由 `integrate-engines.sh` 可复现执行
（按 commit SHA 抓取锁定版 → 构建 → 按 KEEP 清单精选 → 原子覆盖 `engine/`）。下表是单一事实来源。

| 上游 | 仓库 | 锁定版本(commit) | 角色 | 整合方式 | 落点 |
|------|------|----------|------|----------|------|
| **gsd-core** | open-gsd/gsd-core | `0c9f86d`（next 线，v1.5.1-dev.0） | **主干引擎**（全生命周期：Discuss/Plan/Execute/Verify/Ship + 69 命令 + 34 子代理 + hooks） | 抓取→`npm ci + build`→精选运行所需子集（去 tests/docs/src源码/eslint/CI） | `engine/gsd-core/`（~8M，含预构建运行时） |
| **spec-kit** | github/spec-kit | `2dd1ca4`（main 线，v0.11.2.dev0） | **可选引擎**（备用 SDD 主干，免构建） | 抓取→精选 `specify` CLI 运行子集 | `engine/spec-kit/`（~1.8M） |
| **OpenHands** | All-Hands-AI/OpenHands | 镜像 tag `0.59` | **阶段4 编码执行器** | **不拷源码**，只锁定 Docker 镜像 tag | `executor/`（compose + .env） |
| **codegraph** | colbymchenry/codegraph | npm `@colbymchenry/codegraph@1.0.1` | **MCP 代码图索引层**（影响分析/代码理解） | **不拷源码**，只锁定 npm 版本，消费时 `npx` 装 | `mcp/codegraph/`（VERSION + 说明） |

> 版本锁定用 **commit SHA**（非分支名），避免上游漂移、保证每次整合结果一致。
> 追最新时显式覆盖：`GSD_REF=next bash integrate-engines.sh gsd-core`，验证 overlay 仍兼容后回填本表 SHA。

> 方法论本身（测试金字塔/双门/追溯/影响分析…）不来自上游，是我们自有资产，放 `overlay/`，
> 安装时注入目标项目本地（CLAUDE.md 段 + `.claude/skills` + `/sdlc-*` 命令 + config），**不进 `engine/`，永不被整合覆盖**。

## 整合 / 刷新（维护者）

全部走 `integrate-engines.sh`，版本在脚本头部（`GSD_REF` / `SPECKIT_REF` / `OPENHANDS_TAG`）：

```bash
bash integrate-engines.sh all          # 整合三者
bash integrate-engines.sh gsd-core     # 只重整合主干（会跑 npm build）
bash integrate-engines.sh spec-kit     # 只重整合可选引擎
bash integrate-engines.sh openhands    # 只同步镜像 tag 到 executor/.env.example
bash integrate-engines.sh codegraph    # 只锁定 npm 版本到 mcp/codegraph/VERSION

# 用本地已有 clone 加速（仍执行构建/精选）:
GSD_SRC=/d/workspace/gsd-core SPECKIT_SRC=/d/workspace/spec-kit bash integrate-engines.sh all
```

升级上游：改脚本头部锁定版本 → 重跑 → 复核 `overlay/`（方法论是否仍兼容新版 gsd 的 plan-checker/verifier 行为）→ 回填本表 commit。

## 为什么这样取舍

- gsd 的价值是**整套全生命周期编排**（命令+子代理+工作流+hooks），必须整合可运行引擎；运行时是构建产物，故聚合仓预构建一次、提交产物，消费者 `clone` 即用、无需 npm。
- spec-kit 体量小、免构建，作为可替换的备用主干保留。
- OpenHands 是**服务**，用镜像即可，拷 27M 源码是负担。
- 三者噪音（tests/docs/CI）一律剔除，符合「取精华、不整包」。
