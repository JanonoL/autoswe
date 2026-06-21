# codegraph —— MCP 代码知识图索引层（影响分析 / 代码理解）

> 第四类集成（区别于 SDD 引擎 gsd/spec-kit、执行器 OpenHands）：**MCP 服务器 + 本地预索引代码图**。
> 不 vendor 源码（含 tree-sitter wasm + native 依赖），只锁定版本，消费时 `npx` 安装运行。

## 是什么 / 为什么开启

[@colbymchenry/codegraph](https://github.com/colbymchenry/codegraph)（MIT，Node≥20<25）把代码库预索引成
**符号 / 调用图 / 导入** 知识图，通过 MCP 暴露给 Claude Code，`codegraph_explore` 直接答、近零文件读取。

**对本方案的核心价值 = 精准影响分析（§9）**：
- 现成 CLI：`codegraph callers <符号>`、`codegraph impact <符号>`、`codegraph affected` —— 确定性调用图，
  把"改方法前找出所有调用方（跨模块/含接口/Feign 间接）"从 grep 猜升级为图查询。
- 20+ 语言含 **Java / TypeScript / JavaScript / Vue**，覆盖全栈 polyrepo。
- 附带 token/工具调用下降（Java OkHttp 实测省 54% token、50% 工具调用）。

## 集成方式（install.sh 默认开启，失败不致命）

```bash
# 写 MCP 配置进项目（.mcp.json + .claude/settings.json）
npx -y @colbymchenry/codegraph@<版本> install -t claude -l local -y
# 建本地索引（.codegraph/codegraph.db，SQLite FTS5；改文件自动同步）
npx -y @colbymchenry/codegraph@<版本> init
```

版本锁定见 `../../integrate-engines.sh` 的 `CODEGRAPH_VERSION` 与 `UPSTREAMS.md`。
跳过：装 ai-sdlc-kit 时设 `NO_CODEGRAPH=1`。

## 注入项目后多出什么

```
.mcp.json                     codegraph MCP 服务器配置（agent 自动调用）
.claude/settings.json         + codegraph 工具的 auto-allow 权限
.codegraph/codegraph.db       本地代码图索引（gitignore 之）
CLAUDE.md                     + codegraph 使用说明块（codegraph 自写）
```

## 与 gsd graphify 的区别

gsd 的 `graphify`/`gsd-codebase-mapper` 是 **LLM 驱动**分析、产物落 `.planning/`；
codegraph 是 **确定性预索引** + MCP 实时查询，调用图精确、省 token。二者互补：codegraph 供精准定位，
gsd agent 做语义理解与规划。
