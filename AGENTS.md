# gbz185.mbt Agent Guide

MoonBit 项目：**walkzzz/gbz185.mbt** —— GB/Z 185-2026《人工智能 智能体互联》协议栈（10 包：wire/arch 根包/identity/registry/capability/discovery/aip/tooling/transport_async/verify）。依赖：moonbitlang/async@0.22.9、cc06b/mooncry@0.95.0（仅 transport_async 使用）；核心包零 mooncakes 依赖。

## One-Line Summary

gbz185.mbt 是国标协议栈**库**（非应用）：wire 统一错误契约 + 七部分协议建模 + 传输扩展；协议核心 sans-I/O，鉴权（CAIVerifier）与工具绑定（ToolCallable/handler）全部 trait/闭包注入。

## Developer roles and trust boundary

- **核心开发者**（walkzzz）：拥有协议语义正确性、wire 契约、verify 证明函数与包边界（依赖方向 aip→discovery 单向等钉扎决策，见 ARCH §2.5）。
- **下游应用开发者**：组合各包（registry/capability/discovery/aip/tooling），实现 `CAIVerifier`/`ToolCallable` 注入；不触碰内部字段（priv 化）。
- **传输扩展开发者**：接入 `TcpChannel`/`TlsTcpChannel` 或自研 Transport；不经核心改协议语义。
- **最终用户**：信任测试矩阵与形式化证明（verify 3 goals proved：clamp_i64/next_seq/inbox_advance）。

## Commands（门禁纪律）

```bash
moon check --deny-warn --target all   # 四目标零警告（native/js/wasm/wasm-gc）
moon test --target native             # 124/124（seed 固定可复现）
moon test --target js                 # 117/117；wasm / wasm-gc 同（transport_async 为 native-only）
moon fmt                              # 格式化
moon info                             # 更新 .mbti 契约（git 入库，diff 必查）
moon bench --target native            # 4 项基准（dispatch / lookup / wire / 能力检索）
node scripts/check_pages.mjs          # 展示页自检（结构 / 移动端导航 / 钩子 / 11 导出 / AIP 语义，141 项）
```

覆盖率（Windows 下 `moon coverage report` 对 `transport-async` 连字符包名有路径拼接缺陷，故显式传核心 trace）：

```bash
moon coverage clean
moon test --target native --enable-coverage --no-parallelize
moon coverage report -f full_summary \
  _build/native/debug/test/gbz185.mbt.trace.source \
  _build/native/debug/test/wire/wire.trace.source \
  _build/native/debug/test/identity/identity.trace.source \
  _build/native/debug/test/registry/registry.trace.source \
  _build/native/debug/test/capability/capability.trace.source \
  _build/native/debug/test/discovery/discovery.trace.source \
  _build/native/debug/test/aip/aip.trace.source \
  _build/native/debug/test/tooling/tooling.trace.source \
  _build/native/debug/test/verify/verify.trace.source
# 目标：>= 811/883 = 91.8%
```

形式化验证走 WSL（Windows 本地 moon prove 有 `\\?` mkdir 平台 bug——EINVAL/EACCES，勿反复重试）：

```bash
wsl -e bash -c "cd /mnt/e/AA_WP/forMoonHankson/gbz185.mbt && ~/.moon/bin/moon prove"
```

## Mock Pattern

- 测试一律走 `FakeTransport`（内存直连 sans-I/O）或 seed 数据（`generate_dispatch_envelopes`/`generate_mutated_envelope`/`generate_mock_nodes`），不起真 socket。
- **MoonBit test 块不可调 async fn**（4149）——async E2E 只走 cmd main + shell 脚本模式。
- bench 文件必须在 `*_test.mbt` 模式内且 test 块无名（官方 API：`b.bench(name=..., fn(){...})` + `b.keep(...)`）。

## Rules

- wire 数字字段显式 `Json::number(x.to_double())`（**Int64 的 ToJson 序列化为字符串**——防 JS 精度丢失）；Option[X] 无 `.to_json()`，显式 match。
- 跨包实现 trait 需 `pub(open) trait`；`#derive(Eq, Debug)` 必配 `pub extend T with Eq::{equal, not_equal}` + `pub extend T with @moonbitlang/core/debug.Debug::{to_repr}`。
- 函数值字段调用必须括号：`(entry.handler)(inv)`。
- 注释纪律：中英双语 doc 只写非自明语义，禁止零价值注释。
- 文档即实现：任何协议语义变更先改 `docs/TEST_REPORT.md` 对应节，再动实现。
- 变异基线：`scripts/mutation_test.mbtx` 19 变异点全 KILLED（击杀率 100%）是回归红线；变异 old_sub 必须随实现演进同步更新（曾因签名重构出现 NOT-APPLIED）。
- 已知边界见 `docs/known-gaps.md`（真话台账），README 只写能力不写尚未兑现的承诺。
- 排序语义：MoonBit `Compare for String` 是 shortlex（长度优先）——不要假设 `sort()` 为字典序；新增确定性清单 API 须在 doc 中写明。
- 覆盖率口径：native 插桩点（`full_summary`），排除 transport_async/playground/examples；数字变更须同步 README / docs / TEST_REPORT 三处。
- 新增 API 纪律：每个公开函数至少一处黑盒断言 + 可被变异矩阵覆盖（当前 19 点全部有对应断言）。
