#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
# ai-sdlc-kit 一键安装器（消费者用）—— gsd-core 主干
#   把 gsd 全生命周期引擎 + AI-SDLC 方法论装进你自己的项目。
#
# 用法:
#   bash install.sh [目标项目路径]           # 默认当前目录
#   GSD_ENGINE=/外部/gsd bash install.sh     # 覆盖默认引擎
#
# 自包含: gsd 引擎已随本仓 (engine/gsd-core) 预构建分发，无需 npm/构建。
# 幂等: 重复运行安全。不做任何 git 提交。装完请自行 `git status` 查看新增文件。
# ════════════════════════════════════════════════════════════════════
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY="$KIT_DIR/overlay"
TARGET="${1:-$(pwd)}"
GSD_ENGINE="${GSD_ENGINE:-$KIT_DIR/engine/gsd-core}"

echo "════════════════════════════════════════════════"
echo " ai-sdlc-kit 安装（gsd 主干）"
echo "   聚合仓   : $KIT_DIR"
echo "   目标项目 : $TARGET"
echo "   引擎     : $GSD_ENGINE"
echo "════════════════════════════════════════════════"

# ── 前置检查 ──────────────────────────────────────────────────────
[ -f "$GSD_ENGINE/bin/install.js" ] || { echo "❌ 未找到 gsd 引擎: $GSD_ENGINE（请先 bash integrate-engines.sh gsd-core）"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ 缺少 node（gsd 安装器需要）"; exit 1; }
[ -d "$TARGET" ] || { echo "❌ 目标项目不存在: $TARGET"; exit 1; }

# ── 0) 可选：装 spec-kit 原命令（SPECKIT_INSTALL=1）。默认不装——其方法论优点已由 overlay
#       合并进 gsd 主干（constitution→CLAUDE.md 段、checklist→sdlc-gates、clarify→需求矩阵），
#       默认只跑 gsd 单一工作流以守方案 §16.4「不整包并存」。与 gsd 无文件冲突，需要时可开。
if [ "${SPECKIT_INSTALL:-}" = "1" ]; then
  SPEC_KIT="${SPEC_KIT:-$KIT_DIR/engine/spec-kit}"
  if command -v uvx >/dev/null 2>&1 && [ -f "$SPEC_KIT/pyproject.toml" ]; then
    echo "▶ [可选] 安装 spec-kit 原命令（/speckit.*，与 /gsd-* 共存）"
    ( cd "$TARGET" && uvx --from "$SPEC_KIT" specify init --here --integration claude --script sh --force --ignore-agent-tools ) \
      || echo "  ⚠ spec-kit 安装失败，不影响 gsd 主干"
  else
    echo "  ⚠ SPECKIT_INSTALL=1 但缺 uvx 或 engine/spec-kit，跳过"
  fi
fi

# ── 1) gsd 主干安装（命令/agent/运行时/hook → 目标 .claude/）──────
echo "▶ [1/5] 安装 gsd 主干引擎"
( cd "$TARGET" && node "$GSD_ENGINE/bin/install.js" --local --claude )

# ── 2) 注入 AI-SDLC 方法论 skill（plan-checker 自动扫描）─────────
echo "▶ [2/5] 注入方法论 skill: sdlc-gates"
mkdir -p "$TARGET/.claude/skills"
cp -rf "$OVERLAY/skills/sdlc-gates" "$TARGET/.claude/skills/"

# ── 3) 注入自定义命令（与 /gsd 共存）─────────────────────────────
echo "▶ [3/5] 注入命令: /sdlc-impact /sdlc-gates /sdlc-trace /sdlc-release"
mkdir -p "$TARGET/.claude/commands"
cp -f "$OVERLAY/commands/"sdlc-*.md "$TARGET/.claude/commands/"
[ -d "$OVERLAY/agents" ] && ls "$OVERLAY/agents/"*.md >/dev/null 2>&1 && {
  mkdir -p "$TARGET/.claude/agents"; cp -f "$OVERLAY/agents/"*.md "$TARGET/.claude/agents/"; }

# ── 4) 注入 CLAUDE.md 方法论铁律段（planner/verifier 强制读）─────
echo "▶ [4/5] 注入 CLAUDE.md 工程铁律段 + config 推荐值"
CLAUDE_MD="$TARGET/CLAUDE.md"
if grep -q 'AI-SDLC:conventions-start' "$CLAUDE_MD" 2>/dev/null; then
  echo "  ↺ CLAUDE.md 已含 AI-SDLC 段，跳过（如需更新请手动替换标记段）"
else
  { [ -f "$CLAUDE_MD" ] && echo ""; cat "$OVERLAY/claude-md/sdlc-conventions.md"; } >> "$CLAUDE_MD"
  echo "  ✓ 已追加工程铁律段到 CLAUDE.md"
fi
# config 覆盖值：.planning 由 /gsd-new-project 生成，这里放模板供其后合并
mkdir -p "$TARGET/.planning"
cp -f "$OVERLAY/config/sdlc-config-overrides.json" "$TARGET/.planning/sdlc-config-overrides.json"

# ── 4.5) .gitignore 排除可重新生成的工具运行时（不入库；并让 codegraph 索引只覆盖真实源码）──
#   这些目录由 install.sh / gsd 重新生成，文件仍在磁盘供运行，仅不提交、不污染代码图索引。
#   .planning/ 不排除（gsd 视其为应入库的项目记忆）。
GI="$TARGET/.gitignore"
if ! grep -q 'ai-sdlc-kit: 工具运行时' "$GI" 2>/dev/null; then
  { [ -f "$GI" ] && echo ""
    echo "# ai-sdlc-kit: 工具运行时（可重新生成；不入库、不被 codegraph 索引）"
    echo ".claude/gsd-core/"
    echo ".claude/scripts/"
    echo ".claude/hooks/"
    echo ".codegraph/"
  } >> "$GI"
  echo "  ✓ 已向 .gitignore 追加工具运行时排除（保索引干净）"
fi

# ── 5) 配置 codegraph MCP 代码图（影响分析/代码理解，默认开；NO_CODEGRAPH=1 跳过，失败不致命）──
# 注：前置检查已保证 node 存在；codegraph 需 Node≥20<25，版本不符时下方 npx 会自行报错并走失败分支。
if [ "${NO_CODEGRAPH:-}" = "1" ]; then
  echo "▶ [5/5] 跳过 codegraph（NO_CODEGRAPH=1）"
else
  CG_VER="$(cat "$KIT_DIR/mcp/codegraph/VERSION" 2>/dev/null || echo 1.0.1)"
  echo "▶ [5/5] 配置 codegraph 代码知识图（@$CG_VER，建索引可能耗时数十秒）"
  CG="npx -y @colbymchenry/codegraph@$CG_VER"
  if ( cd "$TARGET" && $CG install -t claude -l local -y && $CG init ); then
    echo "  ✓ codegraph MCP 已配置并建索引（.codegraph/）；/sdlc-impact 将用调用图精确定位调用方"
  else
    echo "  ⚠ codegraph 配置失败（网络/npm/Node 版本需≥20<25），不影响其余安装；可稍后手动："
    echo "    cd \"$TARGET\" && $CG install -t claude -l local -y && $CG init"
  fi
fi

echo "════════════════════════════════════════════════"
echo "✅ 安装完成。下一步："
echo "   1) git status                # 查看新增文件"
echo "   2) /gsd-new-project          # gsd 初始化项目（生成 .planning/）"
echo "      之后把 .planning/sdlc-config-overrides.json 的键合并进 .planning/config.json"
echo "   3) 全生命周期命令流："
echo "      /gsd-new-project → /gsd-discuss-phase → /gsd-plan-phase →"
echo "      /sdlc-impact(演进时) → /gsd-execute-phase → /sdlc-gates →"
echo "      /gsd-verify-work → /sdlc-trace → /sdlc-release → /gsd-ship"
echo "   方法论已注入: CLAUDE.md 铁律段 + .claude/skills/sdlc-gates + /sdlc-* 命令"
echo "   代码图: codegraph MCP 已接（/sdlc-impact 用 codegraph callers/impact 精确定位调用方）"
echo "════════════════════════════════════════════════"
