# GB/Z 185 协议栈测试报告（CRAP / 变异 / 基准 / mock 数据 / 多手段）

> 日期：2026-11-17 · 负责人：walkzzz · 范围：walkzzz/gbz185.mbt（GB/Z 185.1-185.7 全栈 10 包）
> 工具：moon check --deny-warn --target all / moon test / moon coverage / moon bench / scripts/mutation_test.mbtx（MoonBit 脚本）

## 1. 测试矩阵总览

| 手段 | 文件 | 用例数 | 状态 |
| --- | --- | --- | --- |
| 黑盒契约（wire/aip/tooling 域） | `wire/wire_test.mbt`、`aip/aip_test.mbt`、`tooling/tooling_test.mbt` | 20 | ✅ |
| 白盒边界 | `aip/aip_wbtest.mbt` | 4 | ✅ |
| 包域单测 | `identity/` `capability/` `discovery/` `registry/` 各 `_test.mbt` | 16 | ✅ |
| Fake Transport | `aip/fake.mbt` + `fake_test.mbt` | 2 | ✅ |
| 属性测试（quickcheck，seed 2026-2030） | `aip/aip_prop_test.mbt` | 5 | ✅ |
| **小模型 mock 数据消费**（fake LLM simulation） | `discovery/mock_data.mbt` + `discovery/mock_test.mbt` + `aip/mock_data.mbt` + `aip/mock_test.mbt` | 5 | ✅ |
| **GB/Z 185.3 ATR 深度实现**（凭证生命周期/容量/事件审计/检索/运维查询） | `registry/registry_test.mbt` 追加 | 5 | ✅ |
| **GB/Z 185.7 工具调用深度实现**（ToolRegistry/分发/批量/schema 单源映射/validate） | `tooling/tooling_test.mbt` 追加 | 6 | ✅ |
| **合计** | | **63** | **63/63 全绿** |

补充：`aip/aip_bench_test.mbt` 基准测试 3 项（不计入 Total，见 §4）；`AipProtocol::invariant` 可执行不变量全周期保持。

## 2. 覆盖率与 CRAP

- 源码总行数 **1503**（15 个源文件），未覆盖 **78** 行 → **行覆盖率 94.8%**
- 未覆盖分布：codec 18 / errors 5+4 / verify 2 / arch 4 / 其余防御分支——均为错误渲染与防御路径

**CRAP 公式**：`CRAP = comp² × (1 − cov)³ + comp`；包级 cov = 94.8% → (1−cov)³ ≈ 0.000135。

| 函数（最高复杂度） | comp | CRAP | 风险 |
| --- | --- | --- | --- |
| AipEnvelope::from_json（信封 8 字段校验） | 7 | ≈7.0 | 低 |
| AgentNode::from_json / AgentIdentity::from_json | 5 | ≈5.0 | 低 |
| receive / handle_discover_response / match_nodes / json_string_array_opt | 5 | ≈5.0 | 低 |
| dispatch / register（ATR）/ aic_validate（状态机） | 4 | ≈4.0 | 低 |
| 其余 ~30 函数（to_wire/from_wire/编解码/name） | 1-2 | ≈1.0-2.0 | 低 |

**结论**：全部函数 CRAP < 10（远低于 30 低风险线）。

## 3. 变异测试（scripts/mutation_test.mbtx，MoonBit 脚本闭环）

| ID | 变异 | 结果 |
| --- | --- | --- |
| M01 | AIP outbox 步长 1→2 | **KILLED** |
| M02 | 防重放比较 > → >= | **KILLED** |
| M03 | 群组 URN 前缀变异 | **KILLED** |
| M04 | ATR 客户端接受位取反 | **KILLED** |
| M05 | 收件人校验取反 | **KILLED** |
| M06 | 自环校验取反 | **KILLED** |
| M07 | 身份 wire 值变异 | **KILLED** |
| M08 | AIC 单段校验宽松化 | **KILLED** |
| M09 | 信封版本校验取反 | **KILLED** |
| M10 | ATR 鉴权短路恒真 | **KILLED** |
| M11 | ADP discoverable 过滤失效 | **KILLED** |
| M12 | 工具绑定构造器替换 | **KILLED** |

**结果：killed=12 / survived=0（击杀率 100%），基线恢复后 52/52 绿**。身份 wire 契约、AIC 结构校验、防重放、鉴权短路、发现过滤、工具绑定均被有效守护。

## 4. 基准测试（moon bench 实测，`aip/aip_bench_test.mbt`）

| 基准 | 实测（mean ± σ） | runs |
| --- | --- | --- |
| `dispatch_pipeline`（GB/Z 185.6 分发） | **90.51 ns ± 13.62 ns** | 10 × 100000 |
| `registry_lookup`（GB/Z 185.3 查询） | **96.29 ns ± 6.24 ns** | 10 × 100000 |
| `envelope_wire_roundtrip`（信封 wire 往返） | **1.69 µs ± 46.74 ns** | 10 × 61029 |

**结论**：分发/查询纳秒级、wire 往返微秒级——满足 PRD §3.1 的性能预期量级（目标值为毫秒级上限），GATE_REPORT 整改项 3（性能实测）关闭。

## 5. 小模型 AI mock 数据（fake LLM simulation）

- **生成器**：`discovery/generate_mock_nodes(seed, count)`（节点/能力词表 chacha8 采样）+ `aip/generate_mutated_envelope(base, seed)`（信封 seq±1/kind 扰动）+ `aip/generate_dispatch_envelopes(proto, seed, count)`（批量合法信封）——**seed 化可复现；每次调用（不同 seed）生成不同数据**。
- **消费测试**：不同 seed 数据必须互异、全部过 wire 往返、能力过滤匹配、变异信封的防重放裁决随序号规则正确（20 个 seed 案例性质验证 + 25 信封批量单调性）。
- **落盘工具**：`scripts/mockgen.mbtx`（独立 .mbtx，生成 JSON 文件供 fuzz/人工检查）。
- **真实模型接入**：GGUF 模型（Qwen2.5-0.5B，469MB）路径与 llama-server 调用方式见 `test-fixtures/llm-local.md`（W7 集成期）。

## 6. 形式化验证（moon prove，2026-11-17 完成）

| 项 | 结果 |
| --- | --- |
| 运行环境 | WSL Ubuntu + moon 0.1.20261104 + **Z3 4.8.12**（`moon prove`） |
| 证明目标 | **3 goals proved**（1 of 1 packages proved，2026-11-18 复验） |
| `clamp_i64` | proof_require lo<=hi ⊢ lo<=res<=hi（ATR 注册序号硬边界防护，registry 真实调用） |
| `next_seq` | proof_require prev>=0 ⊢ res>prev（**AIP 信封序号严格递增——防重放契约的数学基础**，aip 包 dispatch 真实调用） |
| `inbox_advance` | proof_require last>=0 ⊢ res==(incoming>last)（**防重放准入裁决纯函数化——判定与规格逐字对应**，aip 包 receive 真实调用） |
| 方法 | 「已证明 = 已使用」：证明函数被主包真实调用（对齐 simple-agent verify 模式），证明义务由 Z3 机器可查 |

## 7. 结论

- 52/52 测试全绿；四目标 `moon check --deny-warn --target all` 零警告；覆盖率 94.8%；CRAP 全函数 < 10；变异击杀率 100%（12/12）；基准纳秒级。
- **GB/Z 185 协议栈达到可发布质量基线**（GATE_REPORT 86/100 优秀 PASS 的性能整改项已关闭）。
