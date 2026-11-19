#!/usr/bin/env bash
# local_ci.sh — 本地 CI（与 .github/workflows/ci.yml 的 jobs 对齐，含形式化证明）
# 用法：bash scripts/local_ci.sh [--quick]
#   --quick  跳过变异矩阵（慢项），其余与 CI 相同（prove 仍执行）
set -u
FAIL=0
cd "$(dirname "$0")/.." || exit 1   # 仓根（模块根）

step() { echo ""; echo "=== $1 ==="; }
run()  { echo "> $*"; "$@" || { echo "FAILED: $*"; FAIL=1; }; }

step "check --deny-warn --target all"
run moon check --deny-warn --target all

step "test 四目标（native / js / wasm / wasm-gc）"
for t in native js wasm wasm-gc; do
  run moon test --target $t
done

step "contract：mbti 漂移检查"
moon info >/dev/null 2>&1
git diff --exit-code --stat || { echo "FAILED: mbti drift（运行 moon info 并提交）"; FAIL=1; }

step "prove：moon prove 20 obligations（WSL 通道——Windows 本地有 \\\\? mkdir bug）"
WSL_DIR="${WSL_DIR:-/mnt/e/AA_WP/forMoonHankson/gbz185.mbt}"
if command -v wsl >/dev/null 2>&1; then
  wsl -e bash -c "cd '$WSL_DIR' && ~/.moon/bin/moon prove" || { echo "FAILED: moon prove"; FAIL=1; }
else
  echo "WARN: 未检测到 wsl——prove 无法执行（Windows 本地有平台 bug）；可用 WSL_DIR 指定"
fi

if [ "${1:-}" != "--quick" ]; then
  step "mutation：变异矩阵（慢，--quick 跳过）"
  run moon run scripts/mutation_test.mbtx
fi

echo ""
if [ "$FAIL" -ne 0 ]; then
  echo "LOCAL CI FAILED"
  exit 1
fi
echo "LOCAL CI OK"