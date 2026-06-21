# ai-sdlc-kit —— AI 软件工程全生命周期闭环聚合仓

把三个外部开源项目的**精华**整合成一个仓库，一键**应用到任意项目**，并强制注入一套
《AI 自动化开发闭环方案》��法论。以 **gsd-core 为全生命周期主干**。

| 用途 | 命令 |
|------|------|
| 应用到任意项目（新/老/别人的） | `bash ai-sdlc-kit/install.sh <项目路径>` |
| 维护者整合/升级上游 | `bash ai-sdlc-kit/integrate-engines.sh all` |

设计原则：**取精华，不整包**。三个上游整仓 ~100M，其中 99% 是 tests/docs/CI 噪音；只整合真正需要的引擎与运行能力。

---

## 整合了什么（精华）

| 上游 | 角色 | 取的精华 | 落点 |
|------|------|----------|------|
| [gsd-core](https://github.com/open-gsd/gsd-core) | **全生命周期主干** | 69 命令 + 34 子代理 + 工作流 + 模板 + references + hooks + 预构建运行时 | `engine/gsd-core/` |
| [spec-kit](https://github.com/github/spec-kit) | 可选备用主干 | 可运行的 `specify` CLI（免构建） | `engine/spec-kit/` |
| [OpenHands](https://github.com/All-Hands-AI/OpenHands) | 阶段4 编码执行器 | 仅 Docker 镜像（无源码） | `executor/` |
| [codegraph](https://github.com/colbymchenry/codegraph) | MCP 代码图索引层（影响分析/代码理解） | 仅 npm 版本（无源码，npx 运行） | `mcp/codegraph/` |

锁定版本与整合方式见 [`UPSTREAMS.md`](./UPSTREAMS.md)。

**方法论是自有资产**（非上游），放 `overlay/`，安装时注入目标项目本地，永不被上游整合覆盖。

---

## 仓库结构

```
ai-sdlc-kit/
├── engine/
│   ├── gsd-core/          主干引擎（预构建，clone 即用，无需 npm）
│   └── spec-kit/          可选备用引擎
├── overlay/               AI-SDLC 方法论注入层（gsd 消费形式）
│   ├── claude-md/         CLAUDE.md 工程铁律段（planner/verifier 强制读）
│   ├── skills/sdlc-gates/ 8 条门禁规则（plan-checker 自动扫描）
│   ├── commands/          /sdlc-impact /gates /trace /release
│   ├── config/            gsd config 推荐覆盖值（开启门控）
│   └── README.md          注入点 → gsd 源码消费证据
├── executor/              OpenHands 阶段4：docker-compose + 锁定镜像 tag
├── integrate-engines.sh   维护者：可复现整合上游（克隆→构建→精选）
├── install.sh             消费者：gsd 主干 + 方法论装入项目
├── uninstall.sh           卸载注入项
├── UPSTREAMS.md           上游来源/锁定版本/整合方式
└── README.md
```

---

## 应用到别的项目（消费者）

前置：`node`（gsd 安装器 + codegraph 需要，**≥20 <25**；gsd 引擎已预构建，无需 npm 构建）。

```bash
git clone <本仓> ai-sdlc-kit          # 自包含
bash ai-sdlc-kit/install.sh /path/to/你的项目     # 老项目
# 或新项目： mkdir proj && cd proj && git init && bash /path/to/ai-sdlc-kit/install.sh .
# 可选：SPECKIT_INSTALL=1 也装 spec-kit 原命令；NO_CODEGRAPH=1 跳过 codegraph
```

`install.sh` 五步（**不做 git 提交**）：① gsd 主干装入 `.claude/` ② 注入 `sdlc-gates` skill
③ 注入 `/sdlc-*` 命令 ④ 追加 CLAUDE.md 铁律段 + config 推荐值 + .gitignore 排除工具运行时
⑤ 配置 codegraph MCP 并建索引。装完 `git status` 查看，不满意 `git checkout` 撤销。
卸载：`bash ai-sdlc-kit/uninstall.sh /你的项目`。

### 注入后目标项目多出什么

```
CLAUDE.md                         + AI-SDLC 工程铁律段（8 条，planner/verifier 强制遵守）
.claude/commands/gsd/*            69 个 gsd 全生命周期命令
.claude/commands/sdlc-*.md        4 个方法论命令
.claude/agents/*                  34 个 gsd 子代理
.claude/skills/sdlc-gates/        8 条门禁规则（plan-checker 自动加载）
.claude/gsd-core/, hooks/         gsd 运行时 + 上下文纪律 hooks
.mcp.json                         codegraph MCP 服务器（agent 自动调用调用图）
.codegraph/                       本地代码图索引（SQLite，自动 gitignore）
.gitignore                        + 排除可重新生成的工具运行时（保索引干净）
.planning/sdlc-config-overrides.json  待合并进 gsd config 的门控开关
```

---

## 全生命周期命令流（安装后）

```
/gsd-new-project        初始化项目（生成 .planning/，随后合并 config 覆盖值）
/gsd-discuss-phase      Discuss：固化实现决策
/gsd-plan-phase         Plan：plan-checker 自动校验 sdlc-gates 规则
/sdlc-impact            （演进时）改动前影响分析门
/gsd-execute-phase      Execute：并行波次执行
/sdlc-gates             双验证门：功能门 + 非功能门（确定性裁判）
/gsd-verify-work        Verify：verifier 遵守 CLAUDE.md 铁律
/sdlc-trace             维护追溯矩阵
/sdlc-release           发布安全清单 + 人工裁决
/gsd-ship               Ship：PR + 归档
（阶段4 可选）executor/ OpenHands 自主执行器，受限重试/封顶
```

8 条方法论 → 注入点映射见 [`overlay/README.md`](./overlay/README.md)。

---

## 维护者：整合 / 升级上游

```bash
bash integrate-engines.sh all          # 克隆锁定版→构建→精选→覆盖 engine/
GSD_SRC=/d/workspace/gsd-core bash integrate-engines.sh gsd-core   # 用本地 clone 加速
```

升级：改 `integrate-engines.sh` 头部锁定版本 → 重跑 → 复核 overlay 兼容性 → 回填 UPSTREAMS.md。
方法论升级：改 `overlay/**`，消费者重跑 `install.sh` 即更新。

---

## 发布到 GitHub（一次性，git 操作请手动执行）

```bash
cd ai-sdlc-kit
git init && git add -A && git commit -m "feat: ai-sdlc-kit 全生命周期闭环聚合仓（gsd 主干 + 方法论注入）"
git remote add origin <你的仓库> && git push -u origin main
```
