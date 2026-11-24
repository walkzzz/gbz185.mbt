# GB/Z 185 协议栈测试报告（0.2.0）

> 日期：2026-11-24 · 负责人：walkzzz · 范围：walkzzz/gbz185.mbt（GB/Z 185.1-185.7 全栈，10 包）
> 工具：`moon check --deny-warn --target all` / `moon test --target {native,js,wasm,wasm-gc}` / `moon coverage report` / `moon bench` / `scripts/mutation_test.mbtx` / `node scripts/check_pages.mjs`

## 1. 测试矩阵

| 手段 | 文件 | 用例数 |
| --- | --- | --- |
| 黑盒契约（wire/aip/tooling 域） | `wire/wire_test.mbt`、`aip/aip_test.mbt`、`tooling/tooling_test.mbt` | 20 |
| 白盒边界 | `aip/aip_wbtest.mbt`、`arch_wbtest.mbt` | 8 |
| 包域单测（identity/capability/discovery/registry） | 各 `_test.mbt` | 16 |
| 新增能力（0.2.0） | `identity_extra_test`、`capability_extra_test`、`discovery_extra_test`、`registry_extra_test`、`tooling_extra_test`、`aip_extra_test` | 22 |
| 错误契约与编解码 | `wire_errors_test`、`aip_errors_codec_test`、`registry_errors_test`、`tooling_errors_test` | 12 |
| 证明函数可执行投影 | `verify/verify_cover_test.mbt` | 7 |
| Fake Transport | `aip/fake.mbt` + `fake_test.mbt` | 2 |
| 属性测试（quickcheck，seed 2026-2034） | `aip/aip_prop_test.mbt`、`aip/aip_extra_prop_test.mbt` | 9 |
| 小模型 mock 数据消费 | `discovery/mock_test.mbt`、`aip/mock_test.mbt` | 5 |
| ATR 深度实现 | `registry/registry_test.mbt` | 5 |
| 工具调用深度实现 | `tooling/tooling_test.mbt` | 6 |
| 示例/演示包 | `examples/echo_demo`、`playground` 测试 | 12 |
| **合计（native）** | | **124 / 124 全绿** |

js / wasm / wasm-gc：各 **117 / 117**（差额为 `transport_async` 的 native-only 用例）。

基准文件 `aip/aip_bench_test.mbt`（4 项）不计入 Total；`AipProtocol::invariant` 可执行不变量全周期保持。

## 2. 覆盖率（native 插桩点口径）

```
moon coverage clean
moon test --target native --enable-coverage --no-parallelize
moon coverage report -f full_summary <9 个核心包 trace>
```

| 包/文件 | 覆盖 |
| --- | --- |
| `arch.mbt` | 19/19 |
| `wire/errors.mbt` | 24/24 |
| `wire/helpers.mbt` | 80/89 |
| `identity/identity.mbt` | 41/42 |
| `capability/capability.mbt` | 27/27 |
| `discovery/discovery.mbt` | 25/26 |
| `registry/registry.mbt` | 159/175 |
| `aip/protocol.mbt` | 62/79 |
| `aip/codec.mbt` | 50/62 |
| `aip/route.mbt` | 64/70 |
| `aip/errors.mbt` | 41/41 |
| `aip/session.mbt` | 23/24 |
| `aip/envelope.mbt` | 16/16 |
| `aip/fake.mbt` | 4/4 |
| `tooling/tooling.mbt` | 97/105 |
| `verify/core.mbt` | 34/34 |
| mock 数据生成器 | 41/42 |
| **合计** | **811/883 = 91.8%** |

口径说明：分母为插桩点（非物理行）；排除 `transport_async`（Windows 下 moon coverage 对含连字符包名的路径拼接缺陷）、`playground`、`examples`。旧文档「94.8%（78/1503）」分母不可复现，已废弃。

## 3. 变异测试（19 点，全部 KILLED）

| ID | 变异 | 文件 | 结果 |
| --- | --- | --- | --- |
| M01 | outbox 步长翻倍（`next_seq` 调两次） | aip/protocol | KILLED |
| M02 | 防重放比较放宽（`incoming - 1`） | aip/protocol | KILLED |
| M03 | 群组 URN 前缀变异 | aip/protocol | KILLED |
| M04 | ATR 客户端接受位取反 | aip/protocol | KILLED |
| M05 | 收件人校验取反 | aip/protocol | KILLED |
| M06 | 自环校验取反 | aip/protocol | KILLED |
| M07 | 身份 wire 值变异 | identity | KILLED |
| M08 | AIC 单段校验宽松化 | identity | KILLED |
| M09 | 信封版本校验取反 | aip/codec | KILLED |
| M10 | ATR 鉴权短路恒真 | registry | KILLED |
| M11 | ADP 可见性过滤失效（`AgentNode::matches`） | discovery | KILLED |
| M12 | 工具绑定构造器替换 | tooling | KILLED |
| M13 | ACS 覆盖判定/缺失诊断短路 | capability | KILLED |
| M14 | `IdentityStatus::is_active` 判定反转 | identity | KILLED |
| M15 | 消息标识分隔符变异（`#` → `:`） | aip/envelope | KILLED |
| M16 | 水位读取与接收基线归零 | aip/protocol | KILLED |
| M17 | 能力长度剪枝丢弃等长候选 | registry | KILLED |
| M18 | `ToolRegistry::is_registered` 取反 | tooling | KILLED |
| M19 | `RouteTable::is_member` 恒 false | aip/route | KILLED |

**结果：killed=19 / survived=0（击杀率 100%）**；基线恢复后 124/124 绿。

变异维护规则：`old_sub` 必须随实现演进同步更新——0.2.0 中 M01/M02/M10 因早期重构曾失效（NOT-APPLIED），已改写并复验。

## 4. 基准（native release，2026-11-24）

| 基准 | 实测（mean ± σ） | 采样 |
| --- | --- | --- |
| `dispatch_pipeline` | **122.98 ns ± 8.13 ns** | 10 × 100000 |
| `registry_lookup` | **81.13 ns ± 7.61 ns** | 10 × 100000 |
| `envelope_wire_roundtrip` | **1.56 µs ± 103.95 ns** | 10 × 66594 |
| `registry_find_by_capability_1000x8` | **101.59 µs ± 16.57 µs** | 10 × 1190 |

能力检索基准数据集：1000 节点（200 个 8 能力 / 800 个 4 能力），需求 8 项，结果恒为 200（测试内断言）。未采集剪枝前后对比，故不宣称加速倍数。

## 5. 形式化验证（moon prove）

| 项 | 结果 |
| --- | --- |
| 环境 | WSL Ubuntu + Z3 4.8.12 |
| 目标 | **20 obligations proved / 13 verified functions**（2026-11-19） |
| 核心 | `clamp_i64`（三分支完整刻画）、`next_seq`（严格递增）、`inbox_advance`（裁决恒等于 `incoming > last`）——三者均在实现中真实调用 |
| 组合 | `clamp_keeps_above`、`replay_chain`、`dispatch_seq_admitted_by_peer`（发送推进 × 接收准入闭合） |
| 状态机核 | `activation_after2` / `dispatch_allowed` / `inbox_update` / `after_register` / `gen_seq` 系（model-based oracle） |
| 精度 | `in_js_safe_domain` / `safe_domain_no_overflow`（2^53 安全域） |
| 边界 | `aic_alloc_guard`（段内钳制恒等） |

0.2.0 的 11 项新 API 未改动任何证明函数与其调用点，证明结论继续有效。

## 6. 页面与演示

- `node scripts/check_pages.mjs`：**131 项 PASS**（结构 / 旧钩子保留 / 新钩子 / 11 导出 / AIP 编解码与匹配语义 / 版本与口径）。
- `playground` 导出 11 个非 raise 函数：`aip_make_envelope`、`aip_validate`、`aip_fanout_count`、`aip_next_seq`、`aip_envelope_meta`、`aip_protocol_flow`、`capability_report`、`discovery_match`、`identity_aic_check`、`route_resolve`、`tool_descriptor_check`。

## 7. 结论

- 124/124（native）与 117/117（js/wasm/wasm-gc）全绿；四目标 `--deny-warn` 零警告。
- 覆盖率 91.8%（811/883 插桩点，口径可复算）；变异 19/19 KILLED；20 条证明义务机器可查。
- 0.2.0 为纯增量版本（11 项新 API + 等价优化），无破坏性变更；详见 [migration.md](migration.md)。
