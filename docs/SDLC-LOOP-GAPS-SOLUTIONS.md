# 三个缺口的开源解决方案 —— 让闭环真正闭合

> 承接 [`SDLC-LOOP-DESIGN.md`](./SDLC-LOOP-DESIGN.md) 第 7 章标注的三个缺口。本文给出**经实战验证的开源方案**，
> 并落到 ai-sdlc-kit 的具体注入点（`overlay/` 层、`/sdlc-*` 命令、`config`、MCP 层），不是泛泛罗列工具。
>
> 核心原则不变：**裁判用确定性工具、AI 不自评**；新增能力一律走 `overlay/` 注入，不改引擎、不被升级覆盖。

---

## 缺口一：双验证门的「裁判工具」⚠️ 半空 → 接入确定性扫描栈

### 问题本质
规则要求「跑项目实际命令收退出码」，但 SAST/压测/复杂度的**具体工具未内置**。要补的不是「再写规则」，而是**把一组开源扫描器的退出码接成门**。

### 推荐开源栈（按「拿来即用 + 退出码即裁判」排序）

| 维度 | 工具 | 为什么选它 / 裁判机制 |
|------|------|----------------------|
| **SAST** | [Semgrep](https://github.com/semgrep/semgrep) | 30+ 语言、3000+ 社区规则、50 万行秒级扫；`semgrep ci` **命中阻断级别即非零退出**——天然的门 |
| **SCA/依赖漏洞** | [OSV-Scanner](https://github.com/google/osv-scanner)（Google） | 基于 OSV.dev，多语言/锁文件/容器/SBOM；**发现漏洞返回退出码 1**，直接 fail CI |
| **密钥扫描** | [gitleaks](https://github.com/gitleaks/gitleaks) / [trufflehog](https://github.com/trufflesecurity/trufflehog) | 提交即扫密钥，命中非零退出 |
| **性能/压测** | [k6](https://github.com/grafana/k6)（Grafana） | 脚本即代码，`thresholds` 不达标**自动非零退出**——这就是「关键接口压测达基线」的确定性裁判 |
| **复杂度/重复率** | [lizard](https://github.com/terryyin/lizard)（圈复杂度）+ [jscpd](https://github.com/kucherenko/jscpd)（重复率） | 轻量、跨语言、可设阈值非零退出 |
| **质量门聚合(可选)** | [SonarQube CE](https://www.sonarsource.com/products/sonarqube/) | 经典 **Quality Gate**「达标/阻断」模型，多维度统一裁决 |
| **一站式编排(可选)** | [MegaLinter](https://github.com/oxsecurity/megalinter) | 单 CI Job 跑 100+ linter/扫描器（含 Semgrep/密钥扫描），统一 reporter + 失败策略 |
| **结果回 PR(可选)** | [reviewdog](https://github.com/reviewdog/reviewdog) | 把任意 linter 结果作为 PR 评论，任意代码托管平台通用 |

### 如何接入 ai-sdlc-kit（具体改动）

1. **新增 overlay 工具清单模板** `overlay/config/nfr-tools.template.json`，声明每个门对应的**实际命令**：
   ```jsonc
   {
     "functional": { "unit": "...", "integration": "...", "e2e": "..." },
     "security":   { "sast": "semgrep ci --config auto",
                     "sca":  "osv-scanner -r .",
                     "secret": "gitleaks detect --no-banner" },
     "performance":{ "load": "k6 run --quiet perf/smoke.js" },
     "maintainability": { "complexity": "lizard -C 15 src",
                          "duplication": "jscpd --threshold 5 src" }
   }
   ```
2. **install.sh** 把它合并进 `.planning/`，并写进 CLAUDE.md 的 `code_review_command` / config 门控键（gsd-verifier 已读这些）。
3. **改造 `/sdlc-gates` 命令**：从「描述性」升级为「执行器」——按上表逐条 `run → 收退出码 → 汇总绿红表」。任一非零即红 → 触发自愈封顶（门 6 已有的小闭环）。
4. **裁判纯确定性**：命令退出码是唯一事实，AI 只汇总不裁决——完全契合现有「AI 不自评」铁律。

### 最小可用组合（先跑起来）
`Semgrep + OSV-Scanner + gitleaks + k6` 四件套，全部退出码即裁判，零授权零费用。复杂度/SonarQube 后置。

> ⚠️ 现实校准：开源 SAST 约覆盖商业工具 60–70% 能力，跨文件过程间数据流是短板，且有误报。门要配**基线（baseline）**——只阻断「新增」问题，避免存量噪音卡死闭环。

---

## 缺口二：生产反馈闭环 ❌ 开环 → 接入「观测 → 告警 → 回流需求」三段

### 问题本质
发布后无生产数据回流，是「开发闭环」而非「**全生命周期**闭环」。要补的是把**生产信号变成新需求/新工单**，自动回到 Discuss 阶段。

### 推荐开源栈（分三段，逐段闭合）

**① 观测层（采集生产真相）**
| 工具 | 角色 |
|------|------|
| [OpenTelemetry](https://github.com/open-telemetry/opentelemetry-collector) | 厂商中立的 traces/metrics/logs 采集标准，Collector 转发到任意后端 |
| [Prometheus](https://github.com/prometheus/prometheus) + [Grafana](https://github.com/grafana/grafana) | 指标存储 + 仪表盘，progressive delivery 的默认指标后端 |

**② 错误→工单层（生产信号变需求，闭环关键）**
| 工具 | 角色 / 闭环机制 |
|------|----------------|
| [Sentry(自托管)](https://github.com/getsentry/sentry) | **原生 Alert Rule「Create a GitHub issue」**，可设「仅新 issue」防重复；**双向**：GH issue 关闭→Sentry 自动 resolve。这条就是「生产 → 需求」的自动回流 |
| [GlitchTip](https://glitchtip.com/) | 开源轻量 Sentry 替代，兼容 Sentry SDK；GH 集成较弱，但有 [mcp-glitchtip](https://github.com/coffebar/mcp-glitchtip) **MCP 服务器——让 gsd 代理直接查询生产错误**（与 codegraph 并列进 MCP 层） |

**③ SLO + 渐进发布层（让发布门 8 变成真·自动控制回路）**
| 工具 | 角色 / 闭环机制 |
|------|----------------|
| [Sloth](https://github.com/slok/sloth) / [Pyrra](https://github.com/pyrra-dev/pyrra) | 从 Prometheus 生成 SLO + 错误预算，**预算烧穿即告警**→ 进 backlog |
| [Flagger](https://github.com/fluxcd/flagger)（CNCF） 或 [Argo Rollouts](https://github.com/argoproj/argo-rollouts) | **金丝雀期间盯 Prometheus 指标，成功率/延迟跌破阈值自动回滚、达标自动放量**——把方法论门 8「渐进发布+回滚就绪+监控」从「清单」升级为**自动化控制环** |
| [Unleash](https://github.com/Unleash/unleash) / [Flipt](https://github.com/flipt-io/flipt) + [OpenFeature](https://openfeature.dev/) | 特性开关（门 8「一键关闭」），经 OpenFeature 中立标准接入避免锁定。注：Unleash OSS 版有 sunset 风波，强 OpenFeature 合规选 Flipt |
| [PostHog](https://github.com/PostHog/posthog) | 产品分析+开关+会话回放+问卷一体，**把用户行为/实验结果回流成产品需求**，闭合产品侧 |

### 如何接入 ai-sdlc-kit（具体改动）

1. **新增方法论门 #9「生产可观测性」** → `overlay/skills/sdlc-gates/rules/observability.md`：要求发布物必须带 OTel 埋点 + SLO 定义 + 告警→工单规则。
2. **新增命令 `/sdlc-observe`** → 生成/校验 OTel + SLO(Sloth) + Flagger 金丝雀分析模板，作为 Ship 阶段产物。
3. **MCP 层扩展**：把 `mcp-glitchtip`（或 Sentry MCP）接进 `.mcp.json`，与 codegraph 并列。这样 gsd 代理能**直接读生产错误**，影响分析时把「线上高频报错点」纳入。
4. **闭环回流**：Sentry/GlitchTip 的 GitHub issue → 打 gsd 可识别标签 → 触发 `/gsd-discuss-phase` 把它当新需求 → **环真正闭合到第 ⑩ 步**。
5. **发布门升级**：`/sdlc-release` 的「上线监控/回滚就绪」从勾选项变成**引用 Flagger Canary 资源 + Sloth SLO**的实体校验。

### 最小可用组合
`OpenTelemetry + Prometheus + Sentry(自托管，开 GitHub issue alert)`。先把「生产错误自动变 GitHub issue → gsd 当新需求」这一条最短回流打通，金丝雀/SLO/PostHog 后置。

---

## 缺口三：OpenHands 执行器游离 ⚠️ → 用「事件驱动 + headless」串进命令流

### 问题本质
executor 只是个 docker 服务，要手动喂任务。好消息：**串联机制 OpenHands 上游已经做好了**，我们只需接线，不用造轮子。

### 上游现成的三种接入方式（实战验证）

| 方式 | 命令 / 触发 | 适用 |
|------|------------|------|
| **Headless 脚本模式** | `openhands --headless -f instructions.md --json`（`--yolo`/`--always-approve` 全自动） | gsd 产出 PLAN.md 后，脚本把单个 plan 任务喂给 OpenHands 跑 → 出 PR |
| **GitHub Action 标签触发** | issue 打 `fix-me` 标签 或 评论 `@openhands-agent` → 自动起沙箱→改码→跑测→开 PR | 事件驱动，最贴合闭环 |
| **resolver 编程调用** | `python -m openhands_resolver.resolve_issue --repo OWNER/REPO --issue-number N` | 批量/定时解决工单 |

参考：[OpenHands GitHub Action 文档](https://docs.openhands.dev/openhands/usage/run-openhands/github-action) · [OpenHands-CLI](https://github.com/OpenHands/OpenHands-CLI)。
备选执行器：[SWE-agent](https://github.com/SWE-agent/SWE-agent)（普林斯顿，issue→PR）、[Aider](https://github.com/Aider-AI/aider)（可脚本化进 CI）。

### 如何接入 ai-sdlc-kit（具体改动）

1. **注入 OpenHands 仓库指令**：overlay 新增 `overlay/openhands/repo.md`，install.sh 落到目标项目 `.openhands/microagents/repo.md`——**内容镜像 CLAUDE.md 的 8 条铁律**，让 OpenHands 干活时遵守同一套门（关键：执行器换了，门不能松）。
2. **新增桥接脚本** `executor/bridge-gsd.sh`：
   ```
   gsd PLAN.md ──解析单任务──► openhands --headless -f task.md --yolo ──► PR
                                                                          │
                                                       PR 触发 /sdlc-gates 双门
   ```
   即 OpenHands 产出的 PR **必须过双验证门**才合并——把游离的执行器纳入现有质量闭环。
3. **事件驱动回流**：gsd 自愈超限（门 6）转人工的工单，自动打 `fix-me` 标签 → OpenHands Action 接手重试 → PR → 双门。形成「gsd 主干快、OpenHands 重型兜底」的分工。
4. **`.env` 复用**：现有 `executor/.env`（LLM 网关/模型）已就绪，桥接脚本直接复用，不重复配置。

### 最小可用组合
先打通 **GitHub Action `fix-me` 标签**这一条：把 gsd 转人工的工单自动贴标签 → OpenHands 出 PR → 现有 `/sdlc-gates` 把关。零新基础设施。

---

## 三缺口补齐后的闭环全景

```
                       ┌──────────────── 生产反馈回流（缺口二）─────────────────┐
                       │                                                      │
   需求 ──► Discuss ──► Plan ──► Execute ──► Verify ──► Ship ──► 生产运行       │
            ▲ 门4      ▲ 门5    │ ▲          │ 门2/3    │ 门8     │             │
            │          │(影响)  │ │          │          │         │             │
            │          │        │ └OpenHands │          │         ▼             │
            │          │        │  headless  │       Flagger   OTel+Prom        │
            │          │        │  桥接(缺口三)│      金丝雀自动  Sentry/GlitchTip │
            │          │        ▼            ▼       回滚(缺口二)  错误→GH issue   │
            │          │   ┌─ /sdlc-gates 双门（缺口一补裁判工具）─┐   │           │
            │          │   │ Semgrep/OSV/gitleaks/k6/lizard 退出码 │   │           │
            │          │   └─ 红→自愈≤3→超限转人工(打fix-me标签)───┘   │           │
            │          │                                              │           │
            │          └─ codegraph 调用图 + mcp-glitchtip 生产错误 ◄─┘           │
            │                                                                    │
            └──────────── GitHub issue 自动成为新需求（生产→需求，环闭合）◄────────┘
```

- **缺口一** 让中间的「验证门」从空壳变实弹（确定性裁判落地）；
- **缺口二** 让最右的「生产」第一次有数据/错误**回流成新需求**，把开发闭环升级为全生命周期闭环；
- **缺口三** 让「执行」多一条重型自动通道，且其产物同样过门。

三者补齐后，方案才真正满足你最初的目标：**人只在「定义需求/原型」和「批准发布」两端介入，其余全自动闭环、且演进与生产反馈都回得到环里**。

---

## 落地优先级建议（投入产出比排序）

| 优先级 | 动作 | 工作量 | 收益 |
|--------|------|--------|------|
| **P0** | 缺口一最小四件套（Semgrep+OSV+gitleaks+k6）接进 `/sdlc-gates` | 小 | 立刻让双门可信，质量闭环成立 |
| **P0** | 缺口三 `fix-me` 标签触发 OpenHands（上游现成） | 小 | 零基础设施，执行器即刻入环 |
| **P1** | 缺口二最短回流：OTel+Prometheus+Sentry「错误→GitHub issue→新需求」 | 中 | 首次打通「生产→需求」，闭环质变 |
| **P2** | Flagger/Argo 金丝雀自动回滚 + Sloth SLO | 中大 | 发布门从清单升级为自动控制环（需 K8s） |
| **P2** | PostHog 产品分析 + OpenFeature 开关回流 | 中 | 闭合产品侧反馈，数据驱动需求 |

---

## 来源

**缺口一（NFR 裁判工具）**
- [Semgrep](https://github.com/semgrep/semgrep) · [OSV-Scanner](https://github.com/google/osv-scanner) · [gitleaks](https://github.com/gitleaks/gitleaks) · [k6](https://github.com/grafana/k6) · [MegaLinter](https://github.com/oxsecurity/megalinter) · [reviewdog](https://github.com/reviewdog/reviewdog) · [开源 SAST 工具对比 2026](https://appsecsanta.com/sast-tools/open-source-sast-tools) · [static-analysis 工具清单](https://github.com/analysis-tools-dev/static-analysis)

**缺口二（生产反馈闭环）**
- [Argo Rollouts](https://github.com/argoproj/argo-rollouts) · [Flagger](https://github.com/fluxcd/flagger) · [Sentry 自动建 GitHub issue](https://sentry.io/changelog/2023-11-6-automatically-create-issues-for-jira-server-and-github/) · [GlitchTip](https://glitchtip.com/) · [mcp-glitchtip](https://github.com/coffebar/mcp-glitchtip) · [Unleash](https://github.com/Unleash/unleash) · [OpenFeature](https://openfeature.dev/) · [PostHog](https://posthog.com/feature-flags) · [Flagger 指标驱动回滚(AWS)](https://aws.amazon.com/blogs/opensource/performing-canary-deployments-and-metrics-driven-rollback-with-amazon-managed-service-for-prometheus-and-flagger/)

**缺口三（执行器串联）**
- [OpenHands GitHub Action](https://docs.openhands.dev/openhands/usage/run-openhands/github-action) · [OpenHands-CLI headless](https://github.com/OpenHands/OpenHands-CLI) · [openhands-resolver](https://pypi.org/project/openhands-resolver/) · [SWE-agent](https://github.com/SWE-agent/SWE-agent) · [Aider](https://github.com/Aider-AI/aider)

*文档基于 2026-06 调研。具体工具版本/集成方式以官方文档为准（OpenHands resolver 命令、Unleash OSS 状态、GlitchTip GH 集成成熟度建议部署前再核）。*
