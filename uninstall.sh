#!/usr/bin/env bash
# ai-sdlc-kit 卸载器（gsd 主干）：移除 gsd 安装产物与注入的方法论
set -euo pipefail
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GSD_ENGINE="${GSD_ENGINE:-$KIT_DIR/engine/gsd-core}"
TARGET="${1:-$(pwd)}"
cd "$TARGET"
echo "▶ 卸载 gsd 主干"
node "$GSD_ENGINE/bin/install.js" --uninstall --local 2>/dev/null || echo "  ⚠ gsd 卸载器未生效，可手动删 .claude/gsd-core 等"
echo "▶ 移除 AI-SDLC 注入"
rm -rf "$TARGET/.claude/skills/sdlc-gates"
rm -f "$TARGET/.claude/commands/"sdlc-*.md
rm -f "$TARGET/.planning/sdlc-config-overrides.json"
echo "▶ 移除 codegraph（MCP 配置 + 索引，失败忽略）"
if command -v node >/dev/null 2>&1; then
  CG_VER="$(cat "$KIT_DIR/mcp/codegraph/VERSION" 2>/dev/null || echo 1.0.1)"
  ( cd "$TARGET" && npx -y "@colbymchenry/codegraph@$CG_VER" uninit --force ) 2>/dev/null || true
  ( cd "$TARGET" && npx -y "@colbymchenry/codegraph@$CG_VER" uninstall -t claude -y ) 2>/dev/null || true
  rm -rf "$TARGET/.codegraph"
fi
echo "  ℹ 以下需按需手动清理（自动移除有风险，故保留）："
echo "    - CLAUDE.md 的 <!-- AI-SDLC:conventions-start..end --> 段"
echo "    - .gitignore 的「# ai-sdlc-kit: 工具运行时」段"
echo "    - 若曾用 SPECKIT_INSTALL=1：.specify/ 与 .claude/skills/speckit-* （用 uvx specify 卸载或手删）"
echo "✅ 已卸载 ai-sdlc-kit 注入项"
