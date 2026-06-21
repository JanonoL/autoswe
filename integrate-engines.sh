#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
# integrate-engines.sh —— 可复现的引擎整合脚本
#   把 4 个上游的"精华"按固定规则整合进本仓，每次结果一致，不靠人工拷贝：
#     gsd-core  → engine/gsd-core    抓分支→npm ci+build→按 KEEP 精选→原子覆盖
#     spec-kit  → engine/spec-kit    抓分支→按 KEEP 精选→原子覆盖（免构建）
#     openhands → executor/.env.example  仅锁定 Docker 镜像 tag（无源码）
#     codegraph → mcp/codegraph/VERSION  仅锁定 npm 版本（无源码）
#
# 用法:
#   bash integrate-engines.sh all          # 整合全部 4 个
#   bash integrate-engines.sh gsd-core     # 单独：gsd-core | spec-kit | openhands | codegraph
#
# 用本地已有 clone（跳过联网，弱网/代理首选）:
#   GSD_SRC=/d/workspace/gsd-core SPECKIT_SRC=/d/workspace/spec-kit bash integrate-engines.sh all
#
# 版本：默认抓 *_REF 分支并用 *_PIN 全 SHA 校验（漂移告警）；追最新用 GSD_REF=next 覆盖。
#   openhands/codegraph 版本：OPENHANDS_TAG=… / CODEGRAPH_VERSION=… 覆盖。
#
# 前置: git；gsd 还需 node+npm（构建运行时）。openhands/codegraph 仅写版本文件，无前置。
# ════════════════════════════════════════════════════════════════════
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
KIT_DIR="$(pwd)"
CACHE="$KIT_DIR/.cache"          # 克隆缓存（已 .gitignore）

# ── 上游来源、抓取分支、锁定 SHA ────────────────────────────────────
# 传输走分支浅抓（--depth1 --branch，代理下可靠）；抓后用 *_PIN 全 SHA 校验锁定版本，漂移即告警。
# 按任意 SHA 直抓在弱网/代理下易超时损坏，故不用；追最新用 GSD_REF=<branch> GSD_PIN= 覆盖。
GSD_REPO="https://github.com/open-gsd/gsd-core.git"
GSD_REF="${GSD_REF:-next}"
GSD_PIN="${GSD_PIN:-0c9f86d49517ea94f343f805596d5618ae927411}"
SPECKIT_REPO="https://github.com/github/spec-kit.git"
SPECKIT_REF="${SPECKIT_REF:-main}"
SPECKIT_PIN="${SPECKIT_PIN:-2dd1ca4fb6ce9b36ea5d912c48a73c763e506d33}"
# OpenHands 是阶段4 执行器，以 Docker 镜像运行（无源码整合），此处只统一锁定镜像 tag。
OPENHANDS_TAG="${OPENHANDS_TAG:-0.59}"
# codegraph 是 MCP 代码知识图索引层（影响分析/代码理解），npm 包运行（无源码整合），只锁定版本。
CODEGRAPH_VERSION="${CODEGRAPH_VERSION:-1.0.1}"

# ── 精选清单（整合"取哪些"的唯一事实来源，写死保证每次一致）────────
# gsd-core 引擎：运行/安装所需（去 tests/docs/src源码/eslint/CI 噪音；scripts 必需，运行时 require 它）
GSD_KEEP=(bin commands agents gsd-core hooks assets scripts .claude-plugin
          package.json GEMINI.md gemini-extension.json LICENSE)
# spec-kit 引擎：可运行的 specify CLI（与 pyproject force-include 对齐）
SPECKIT_KEEP=(pyproject.toml LICENSE src templates scripts
              workflows/speckit presets/lean
              extensions/git extensions/agent-context extensions/bug)

log(){ echo "  $*"; }

# 获取源码：优先用 *_SRC 指定的本地 clone；否则按分支浅抓到缓存，再用 pin SHA 校验。
obtain_src() {
  local name="$1" repo="$2" ref="$3" pin="$4" srcvar="$5"
  local override="${!srcvar:-}"
  if [ -n "$override" ]; then
    [ -d "$override" ] || { echo "❌ $srcvar=$override 不存在"; exit 1; }
    echo "$override"; return
  fi
  local dir="$CACHE/$name"
  mkdir -p "$CACHE"
  if [ ! -d "$dir/.git" ]; then
    git init -q "$dir" >&2
    git -C "$dir" remote add origin "$repo" >&2 2>&1 || true
  fi
  log "抓取 $name @ 分支 $ref（浅克隆）" >&2
  local ok=0 i
  for i in 1 2 3; do
    if git -C "$dir" fetch -q --depth 1 origin "$ref" >&2; then ok=1; break; fi
    echo "  ⚠ 第 $i 次抓取失败（弱网/代理抖动），重试…" >&2; sleep 3
  done
  [ "$ok" = 1 ] || { echo "❌ 抓取 $name @ $ref 失败 3 次（梯子/代理可能在损坏 git 传输；可改用 ${srcvar}=/本地clone 离线整合）" >&2; exit 1; }
  git -C "$dir" checkout -q -f FETCH_HEAD >&2 \
    || { echo "❌ checkout $name 失败" >&2; exit 1; }
  # 锁定校验：抓到的 HEAD 应等于 pin SHA，漂移则告警（不中断，但提示回填）
  if [ -n "$pin" ]; then
    local got; got="$(git -C "$dir" rev-parse HEAD 2>/dev/null)"
    if [ "$got" != "$pin" ]; then
      echo "  ⚠ $name 上游已漂移：分支 $ref 现为 ${got:0:10}，锁定为 ${pin:0:10}" >&2
      echo "    （整合的是当前分支 HEAD；如需固定旧版请人工 deepen-fetch 该 SHA，并回填 UPSTREAMS.md）" >&2
    else
      log "✓ $name 版本校验通过（${pin:0:10}）" >&2
    fi
  fi
  echo "$dir"
}

# 按 KEEP 清单精选拷入 engine/<name>。先拷到临时目录，全成功才原子替换（中途失败不留半成品）。
prune_copy() {
  local src="$1" dst="$2"; shift 2; local keep=("$@")
  local tmp="$dst.tmp.$$"
  rm -rf "$tmp"; mkdir -p "$tmp"
  for p in "${keep[@]}"; do
    if [ -e "$src/$p" ]; then
      mkdir -p "$tmp/$(dirname "$p")"
      cp -r "$src/$p" "$tmp/$p" || { rm -rf "$tmp"; echo "❌ 拷贝失败: $p（$dst 未改动）"; return 1; }
    else
      log "⚠ 上游缺 $p（结构可能变更，需复核 KEEP 清单）"
    fi
  done
  rm -rf "$dst"; mv "$tmp" "$dst"
}

integrate_gsd() {
  echo "▶ 整合 gsd-core（主干引擎）"
  local src; src="$(obtain_src gsd-core "$GSD_REPO" "$GSD_REF" "$GSD_PIN" GSD_SRC)"
  echo "  源: $src"
  echo "  构建运行时（npm ci + npm run build）…"
  # npm ci 按 package-lock 精确装依赖（可复现）；构建错误不吞，便于排查。
  if [ -f "$src/package-lock.json" ]; then
    ( cd "$src" && npm ci --silent ) || { echo "❌ npm ci 失败"; exit 1; }
  else
    ( cd "$src" && npm install --silent ) || { echo "❌ npm install 失败"; exit 1; }
  fi
  ( cd "$src" && npm run build >/dev/null 2>&1 ) || { echo "❌ gsd 构建失败（去掉 >/dev/null 重跑看错误）"; exit 1; }
  [ "$(ls "$src/gsd-core/bin/lib"/*.cjs 2>/dev/null | wc -l)" -gt 50 ] \
    || { echo "❌ 运行时 lib 未生成，构建异常"; exit 1; }
  prune_copy "$src" "$KIT_DIR/engine/gsd-core" "${GSD_KEEP[@]}"
  echo "  ✅ engine/gsd-core 就绪（$(du -sh "$KIT_DIR/engine/gsd-core"|cut -f1)）"
}

integrate_speckit() {
  echo "▶ 整合 spec-kit（可选引擎，免构建）"
  local src; src="$(obtain_src spec-kit "$SPECKIT_REPO" "$SPECKIT_REF" "$SPECKIT_PIN" SPECKIT_SRC)"
  echo "  源: $src"
  prune_copy "$src" "$KIT_DIR/engine/spec-kit" "${SPECKIT_KEEP[@]}"
  echo "  ✅ engine/spec-kit 就绪（$(du -sh "$KIT_DIR/engine/spec-kit"|cut -f1)）"
}

# OpenHands：不整合源码，只把锁定的镜像 tag 同步进 executor/.env.example（单一版本事实来源）
integrate_openhands() {
  echo "▶ 整合 OpenHands（阶段4 执行器，仅锁定镜像 tag=$OPENHANDS_TAG）"
  local env="$KIT_DIR/executor/.env.example"
  [ -f "$env" ] || { echo "  ⚠ 缺 $env，跳过"; return; }
  # 覆盖 OPENHANDS_TAG 行，保持其余不变
  if grep -q '^OPENHANDS_TAG=' "$env"; then
    local tmp; tmp="$(mktemp)"
    sed "s/^OPENHANDS_TAG=.*/OPENHANDS_TAG=$OPENHANDS_TAG/" "$env" > "$tmp" && mv "$tmp" "$env"
  else
    printf 'OPENHANDS_TAG=%s\n' "$OPENHANDS_TAG" >> "$env"
  fi
  echo "  ✅ executor/.env.example 锁定 OPENHANDS_TAG=$OPENHANDS_TAG"
}

# codegraph：不整合源码，只把锁定版本写进 mcp/codegraph/VERSION（install.sh 据此 npx 安装）
integrate_codegraph() {
  echo "▶ 整合 codegraph（MCP 代码图索引层，仅锁定版本=$CODEGRAPH_VERSION）"
  local f="$KIT_DIR/mcp/codegraph/VERSION"
  mkdir -p "$KIT_DIR/mcp/codegraph"
  printf '%s\n' "$CODEGRAPH_VERSION" > "$f"
  echo "  ✅ mcp/codegraph/VERSION 锁定 $CODEGRAPH_VERSION"
}

case "${1:-all}" in
  gsd-core)  integrate_gsd ;;
  spec-kit)  integrate_speckit ;;
  openhands) integrate_openhands ;;
  codegraph) integrate_codegraph ;;
  all)       integrate_gsd; integrate_speckit; integrate_openhands; integrate_codegraph ;;
  *) echo "用法: bash integrate-engines.sh {all|gsd-core|spec-kit|openhands|codegraph}"; exit 1 ;;
esac

echo "════════════════════════════════════════════════"
echo "✅ 整合完成。验证："
echo "   gsd      : node engine/gsd-core/bin/install.js --help"
echo "   spec-kit : uvx --from engine/spec-kit specify check"
echo "   openhands: grep OPENHANDS_TAG executor/.env.example"
echo "   锁定版本与 KEEP 清单见本脚本头部 / UPSTREAMS.md"
echo "════════════════════════════════════════════════"
