# gbz185.mbt

<p align="left">
  <a href="https://github.com/walkzzz/gbz185.mbt/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/walkzzz/gbz185.mbt/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/walkzzz/gbz185.mbt/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <a href="https://mooncakes.io/docs/walkzzz/gbz185.mbt"><img alt="mooncakes" src="https://img.shields.io/badge/mooncakes-0.2.2-blueviolet"></a>
  <img alt="MoonBit" src="https://img.shields.io/badge/MoonBit-%E6%9C%88%E5%85%94-purple">
  <img alt="Tests" src="https://img.shields.io/badge/tests-124%20native%20%C2%B7%20117%C3%973-brightgreen">
  <img alt="Prove" src="https://img.shields.io/badge/moon%20prove-20%20obligations%20proved-blue">
  <img alt="Mutation" src="https://img.shields.io/badge/mutation-19%2F19%20KILLED-success">
  <img alt="Targets" src="https://img.shields.io/badge/targets-native%7Cjs%7Cwasm%7Cwasm--gc-orange">
  <img alt="Standard" src="https://img.shields.io/badge/GB%2FZ%20185--2026-%E6%99%BA%E8%83%BD%E4%BD%93%E4%BA%92%E8%81%94-red">
</p>

**简体中文（默认）** · [English](#english)

**目录**：[协议栈总览](#协议栈总览) · [安装](#安装) · [快速开始](#快速开始) · [API 速览](#api-速览) · [质量门禁](#质量门禁) · [能力与边界](#能力与边界) · [FAQ](#常见问题--faq) · [文档](#文档) · [许可证](#许可证)

---

MoonBit 实现的 **GB/Z 185-2026《人工智能 智能体互联》国家标准指导性技术文件协议栈**（第 1-7 部分），从 agentskills 运行时移植项目中抽取的独立、可复用协议资产。零第三方运行时依赖（核心包仅依赖 MoonBit 核心库），四目标编译（native/js/wasm/wasm-gc）。

## 协议栈总览

```
             GB/Z 185-2026 协议栈（自上而下调用）
 ──────────────────────────────────────────────────────
  GB/Z 185.7   tooling/      ToolDescriptor 单源模型 · ToolRegistry
  GB/Z 185.6   aip/          AIP 信封 · 会话 · 群组路由 · FakeTransport
  GB/Z 185.5   discovery/    ADP 发现 · AgentNode · match_nodes
  GB/Z 185.4   capability/   ACS 能力集 · covers 覆盖判断
  GB/Z 185.3   registry/     ATR 注册表 · 鉴权 · 生命周期 · 审计
  GB/Z 185.2   identity/     AIC 身份码逐字符校验
  GB/Z 185.1   (根包)        arch 双模式 · 全局模型 · 互联角色
 ──────────────────────────────────────────────────────
  公共层       wire/         ProtocolError 特征 · JSON 编解码
               transport_async/   TCP NDJSON · TLS 指纹钉扎
               verify/       moon prove 形式化验证（Z3）
```

| 部分 | 包 | 内容 | 状态 |
| --- | --- | --- | --- |
| GB/Z 185.1 | `arch.mbt`（根包） | 总体架构：双模式（本地/互联）、全局模型（agents/agent_skills/agent_messages/agent_tasks/sessions）、互联角色定义 | ✅ |
| GB/Z 185.2 | `identity/` | 身份码 **AIC**（Agent Identity Code）点分编码结构与校验、唯一标识、CAI 凭证引用、`identity_status`（none/active/locked/revoked） | ✅ |
| GB/Z 185.3 | `registry/` | 身份管理 **ATR**（Agent Token Registry）：注册（AIC 分配）、凭证、鉴权（CAIVerifier 注入）、生命周期（lock/revoke）、注销 | ✅ |
| GB/Z 185.4 | `capability/` | 智能体描述 **ACS**（Agent Capability Statement）：能力元数据、输入输出类型、约束（constraints）、匹配原语 | ✅ |
| GB/Z 185.5 | `discovery/` | 智能体发现 **ADP**（Agent Discovery Protocol）：检索、能力匹配、`discoverable` 可见性过滤 | ✅ |
| GB/Z 185.6 | `aip/` | 智能体交互 **AIP**（Agent Interconnection Protocol）：报文信封、单调序号防重放、群组 URN 路由、FakeTransport（sans-I/O） | ✅（MQ 分发与国密于 0.2.0） |
| GB/Z 185.7 | `tooling/` | 智能体工具调用：`ToolDescriptor` 单源模型、调用流程、绑定契约（ToolCallable） | ✅ |

公共层：`wire/`（**ProtocolError** 统一错误特征 + JSON 编解码工具 + 信封常量）、`transport_async/`（传输扩展：TCP NDJSON + TLS 对端指纹钉扎，MQ 分发于 0.2.0）、`verify/`（`proof_enabled` 形式化验证：**13 个验证函数 / 20 条证明义务经 moon prove 全部机器证明**——防重放链、钳制防护、ATR 状态机核、跨机组合、容量防护、JS 精度安全域）。

## 在线演示（浏览器内 AIP 编解码）

**<https://walkzzz.github.io/gbz185.mbt/>**（启用 Pages 后）—— 信封编码/校验、元数据、群组扇出、序号推进、AIP 完整流程、能力匹配、发现过滤、AIC 校验、路由解析与工具描述；全部由编译到 JavaScript 的同一份 MoonBit 实现实时完成（`playground/` 导出层 11 个函数，`docs/` 页面）。

- 本地预览：`node scripts/serve_pages.mjs` → <http://127.0.0.1:8080/>
- 启用 GitHub Pages（维护者一次性）：Settings → Pages → Source = *Deploy from a branch* → `main` / `/docs`（`docs/playground.js` 已入库，零构建）；或 Actions 模式并运行 `gh workflow run pages.yml -R walkzzz/gbz185.mbt`。

## 安装

```bash
moon add walkzzz/gbz185.mbt
moon update
```

## 快速开始

```moonbit
// GB/Z 185.5：构造智能体节点（AGENTS.md frontmatter 字段映射）
let node = @discovery.AgentNode::from_frontmatter(
  "urn:agent:walkzzz:node-1", "演示智能体", @identity.NoIdentity, true,
  ["skill:demo"], ["text"], ["text"],
)
let proto = @aip.AipProtocol::new(node)

// GB/Z 185.3：注册 → 身份激活（AIC 由注册表分配并校验）
// GB/Z 185.6：交互 —— 群组 URN 直通分发，单调序号防重放
let env = @aip.AipProtocol::dispatch(
  proto, @aip.Event, "urn:agent:group:ops", ("hello" : Json),
)
```

## API 速览

| 任务 | 入口 |
| --- | --- |
| 身份码校验（185.2） | `@identity.aic_validate` · `AgentIdentity::from_json` · `IdentityStatus::is_active` |
| 注册 / 鉴权 / 生命周期（185.3） | `@registry.TokenRegistry::register` → `authenticate` → `lock / revoke / renew` |
| 注册表查询 | `@registry.TokenRegistry::is_registered` · `urn_list` · `find_by_capability`（去重 + 长度剪枝） |
| 能力描述与覆盖判断（185.4） | `@capability.AgentCapabilitySet::covers` · `covers_any` · `missing` · `count` |
| 智能体发现与匹配（185.5） | `@discovery.AgentNode::from_frontmatter` · `AgentNode::matches` · `match_nodes` |
| 交互收发（185.6） | `@aip.AipProtocol::dispatch / receive` · `is_registered` · `outbox_seq` · `inbox_watermark` · `peer_urns` |
| 群组路由与扇出 | `@aip.RouteTable::add_group` · `resolve` · `is_member` · `fanout` |
| 信封 JSON 编解码 | `@aip.AipEnvelope::to_json / from_json` · `message_id`（`sender#seq` 单源） |
| 工具单源模型（185.7） | `@tooling.ToolDescriptor::validate` · `ToolRegistry::invoke_tool` · `is_registered` · `names` · `to_mcp_entry` |
| 统一错误契约 | `@wire.ProtocolError` 特征（全栈 suberror 分型） |
| 传输扩展 | `@transport_async.TcpChannel` · `TlsTcpChannel` · `ndjson_encode / ndjson_decode` |
| 形式化验证 | `@verify.clamp_i64 / next_seq / inbox_advance` |

## 质量门禁

| 门禁 | 结果 |
| --- | --- |
| `moon check --deny-warn --target all` | 四目标零警告 |
| `moon test --target native` | **124/124 全绿（2026-11-24 实测）**；js / wasm / wasm-gc 各 **117/117**（黑盒/白盒/Fake Transport/quickcheck 属性/小模型 mock 消费，seed 固定可复现） |
| 形式化验证 | `verify/` 包 `proof_enabled`——**moon prove 20 obligations proved（13 verified functions）**（Z3 4.8.12/WSL，2026-11-19；API 增强未改动证明函数） |
| 覆盖率 | **811/883 = 91.8%**（native 插桩点口径，2026-11-24；排除 transport_async/playground/examples） |
| 变异测试 | **19/19 KILLED**（击杀率 100%） |
| 基准实测 | dispatch 122.98ns / registry_lookup 81.13ns / envelope_roundtrip 1.56µs / find_by_capability 101.59µs（1000 节点 × 8 需求，2026-11-24） |
| 页面门禁 | `node scripts/check_pages.mjs` **159 项 PASS**（结构 / 移动端导航 / 钩子 / 12 导出 / URN·MCP 校验语义） |
| 统一错误契约 | `ProtocolError` 特征（part/code/message），全栈 suberror 分型 |

## 能力与边界

- **定位即库**：仅协议建模与交互状态机，不含协议端点服务、编码侧与 UI；服务端组装属上层应用。
- 协议核心 **sans-I/O**：不感知传输；传输扩展覆盖 TCP NDJSON 与 TLS（对端 SHA-256 指纹钉扎）。
- **不含**：MQ 分发、国密套件（SM2/SM3/SM4）互联安全层——0.2.0 路线图（见 CHANGELOG）。
- mTLS 双向客户端证书受 @tls API 限制，以对端证书 SHA-256 指纹钉扎等效实现（GAP-2）。
- Windows 本地 `moon prove` 受 moon 工具链 `\\?` mkdir 平台 bug 影响，证明验证走 WSL/CI（GAP-1）。
- **排序语义**：`urn_list` / `peer_urns` / `names` 使用 MoonBit 原生 `Compare`（shortlex：先长度后逐字符），等长 URN 时等价字典序；需要严格字典序请自定义比较（GAP-5）。
- **覆盖率口径**：native 插桩点 811/883 = 91.8%（2026-11-24），排除 `transport_async`/`playground`/`examples`；旧文档 94.8% 分母不可复现，已废弃（GAP-6）。
- 完整真话台账见 [docs/known-gaps.md](docs/known-gaps.md)；适用：需要 GB/Z 185-2026 协议建模的 MoonBit 智能体/多智能体项目。

## 常见问题 / FAQ

### AIP 信封序号为什么从 1 开始？

单调递增是 GB/Z 185.6 防重放契约——每信封序号严格大于该发送者历史最大序号，由 `verify/next_seq` 经 Z3 形式化证明（见 `docs/TEST_REPORT.md` §6）。

### 如何切换传输方式？

协议核心（`aip` 包）为 **sans-I/O** 设计，不感知传输。当前内置 `FakeTransport`（内存直连）与 `TcpChannel`/`TlsTcpChannel`（transport_async，TCP NDJSON/TLS trust 三模式）。mTLS 双向客户端证书受 @tls API 限制，以对端证书 SHA256 指纹钉扎等效实现。

### 群组消息序号会冲突吗？

不会——各对端 inbox 序号空间独立，群组扇出的同序号信封发往不同成员互不干扰（`aip/fanout`）。

### AIC 身份码是什么格式？

点分十进制数字段（OID 风格，≥2 段），本栈分配段前缀 `1.2.156.185.2.*`（示意段，正式分配以 ACPs 注册服务为准）。校验逻辑见 `identity/aic_validate`（逐字符状态机）。

### 国密套件（SM2/SM3/SM4）何时可用？

0.2.0 路线图（mooncry 原语已就绪，transport_async 集成中）；当前互联模式安全层为 TLS + 对端指纹钉扎。

## 文档

| 文档 | 内容 |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Agent 指南：门禁纪律 · Mock 模式 · wire 陷阱 · 变异基线 |
| [docs/architecture.md](docs/architecture.md) | 架构设计：十包边界 · 依赖方向 · 数据流 · 排序语义 |
| [docs/performance.md](docs/performance.md) | 性能报告：基准实测 · 复杂度 · 剪枝等价性 · 覆盖率口径 |
| [docs/comparison.md](docs/comparison.md) | 方案对比：手写协议 / 通用 RPC / 上游实现的差异 |
| [docs/assessment.md](docs/assessment.md) | 立项评估：11 维自评（92.6 / A）与风险清单 |
| [docs/proposal.md](docs/proposal.md) | 立项建议书：目标 · 范围 · 里程碑 · 验收口径 |
| [docs/migration.md](docs/migration.md) | 迁移指南：映射步骤 · 对齐检查表 · 常见坑 |
| [docs/security.md](docs/security.md) | 安全说明：威胁模型 · 信任边界 · 已知安全边界 |
| [docs/roadmap.md](docs/roadmap.md) | 路线图：0.2.0 收口与 0.3.0 候选 |
| [docs/TEST_REPORT.md](docs/TEST_REPORT.md) | 测试矩阵（124 用例）· 形式化验证（20 obligations）· 基准实测 |
| [docs/GATE_REPORT.md](docs/GATE_REPORT.md) | 质量门禁报告（95/100 优秀 PASS） |
| [docs/known-gaps.md](docs/known-gaps.md) | 真话台账：已知边界与缺口（诚实记录） |
| [CHANGELOG.md](CHANGELOG.md) | 版本变更（Keep a Changelog） |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 贡献指南 |
| [SECURITY.md](SECURITY.md) | 安全政策：漏洞报告渠道 · 防重放证明背书 |
| [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) | 第三方组件披露（Apache-2.0 等） |
| [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) | 行为准则（Contributor Covenant 2.1） |

## 许可证

MIT。上游参考：[UCToo/agentskills-runtime](https://atomgit.com/UCToo/agentskills-runtime)（仓颉实现）。

---

<a id="english"></a>

## English

MoonBit implementation of the **GB/Z 185-2026 "AI Agent Interconnection" national standard stack** (Parts 1-7), extracted from the agentskills runtime port as an independent, reusable protocol asset. Zero third-party runtime dependencies (core packages depend only on the MoonBit core library); compiles to four targets (native/js/wasm/wasm-gc).

### Stack

```
             GB/Z 185-2026 protocol stack (top-down calls)
 ──────────────────────────────────────────────────────
  GB/Z 185.7   tooling/      ToolDescriptor single source · ToolRegistry
  GB/Z 185.6   aip/          AIP envelope · session · group routing · FakeTransport
  GB/Z 185.5   discovery/    ADP discovery · AgentNode · match_nodes
  GB/Z 185.4   capability/   ACS capability set · covers
  GB/Z 185.3   registry/     ATR registry · auth · lifecycle · audit
  GB/Z 185.2   identity/     AIC per-character validation
  GB/Z 185.1   (root)        arch dual-mode · global model · interconnect roles
 ──────────────────────────────────────────────────────
  Common       wire/         ProtocolError trait · JSON codecs
               transport_async/   TCP NDJSON · TLS fingerprint pinning
               verify/       moon prove formal verification (Z3)
```

| Part | Package | Content | Status |
| --- | --- | --- | --- |
| GB/Z 185.1 | `arch.mbt` (root) | Overall architecture: dual mode (local/interconnect), global model, interconnect roles | ✅ |
| GB/Z 185.2 | `identity/` | **AIC** identity code structure/validation, CAI credential reference, `identity_status` | ✅ |
| GB/Z 185.3 | `registry/` | **ATR**: register (AIC assignment), credentials, authentication (CAIVerifier injection), lifecycle, unregister | ✅ |
| GB/Z 185.4 | `capability/` | **ACS**: capability metadata, input/output types, constraints, match primitive | ✅ |
| GB/Z 185.5 | `discovery/` | **ADP**: search, capability matching, `discoverable` visibility filtering | ✅ |
| GB/Z 185.6 | `aip/` | **AIP**: envelope, monotonic-sequence anti-replay, group URN routing, FakeTransport (sans-I/O) | ✅ (MQ & SM-suite at 0.2.0) |
| GB/Z 185.7 | `tooling/` | Tool invocation: `ToolDescriptor` single-source model, invocation flow, binding contract | ✅ |

Common layers: `wire/` (**ProtocolError** unified error trait + JSON helpers + envelope constants), `transport_async/` (transport extension: TCP NDJSON + TLS peer fingerprint pinning, MQ at 0.2.0), `verify/` (`proof_enabled` formal verification: **13 verified functions / 20 proof obligations all machine-proved** — anti-replay chain, clamp guard, ATR state-machine core, cross-machine composition, capacity guard, JS precision safe domain).

### Install

```bash
moon add walkzzz/gbz185.mbt
moon update
```

### Quick start

```moonbit
// GB/Z 185.5: build an agent node (AGENTS.md frontmatter mapping)
let node = @discovery.AgentNode::from_frontmatter(
  "urn:agent:walkzzz:node-1", "demo-agent", @identity.NoIdentity, true,
  ["skill:demo"], ["text"], ["text"],
)
let proto = @aip.AipProtocol::new(node)

// GB/Z 185.3: register -> activate (AIC assigned & validated by the registry)
// GB/Z 185.6: interact — group URN routing, monotonic-sequence anti-replay
let env = @aip.AipProtocol::dispatch(
  proto, @aip.Event, "urn:agent:group:ops", ("hello" : Json),
)
```

### API quick reference

| Task | Entry points |
| --- | --- |
| Identity code validation (185.2) | `@identity.aic_validate` · `AgentIdentity::from_json` · `IdentityStatus::is_active` |
| Register / auth / lifecycle (185.3) | `@registry.TokenRegistry::register` → `authenticate` → `lock / revoke / renew` |
| Registry queries | `@registry.TokenRegistry::is_registered` · `urn_list` · `find_by_capability` (dedup + length pruning) |
| Capability & coverage (185.4) | `@capability.AgentCapabilitySet::covers` · `covers_any` · `missing` · `count` |
| Discovery & matching (185.5) | `@discovery.AgentNode::from_frontmatter` · `AgentNode::matches` · `match_nodes` |
| Send / receive (185.6) | `@aip.AipProtocol::dispatch / receive` · `is_registered` · `outbox_seq` · `inbox_watermark` · `peer_urns` |
| Group routing & fanout | `@aip.RouteTable::add_group` · `resolve` · `is_member` · `fanout` |
| Envelope JSON codec | `@aip.AipEnvelope::to_json / from_json` · `message_id` (`sender#seq` single source) |
| Tool single source (185.7) | `@tooling.ToolDescriptor::validate` · `ToolRegistry::invoke_tool` · `is_registered` · `names` · `to_mcp_entry` |
| Unified error contract | `@wire.ProtocolError` trait (typed suberrors across the stack) |
| Transport extension | `@transport_async.TcpChannel` · `TlsTcpChannel` · `ndjson_encode / ndjson_decode` |
| Formal verification | `@verify.clamp_i64 / next_seq / inbox_advance` |

### Quality

| Gate | Result |
| --- | --- |
| `moon check --deny-warn --target all` | zero warnings on 4 targets |
| `moon test --target native` | **124/124 green (measured 2026-11-24)**; js / wasm / wasm-gc **117/117** each (blackbox/whitebox/Fake Transport/quickcheck properties/model-based mock consumption, fixed seeds) |
| Formal verification | `verify/` with `proof_enabled` — **moon prove 20 obligations proved (13 verified functions)** (Z3 4.8.12/WSL, 2026-11-19; API additions did not touch proof functions) |
| Coverage | **811/883 = 91.8%** (native instrumentation-point basis, 2026-11-24; transport_async/playground/examples excluded) |
| Mutation testing | **19/19 KILLED** (100% kill rate) |
| Benchmarks | dispatch 122.98ns / registry_lookup 81.13ns / envelope_roundtrip 1.56µs / find_by_capability 101.59µs (1000 nodes × 8 needs, 2026-11-24) |
| Pages gate | `node scripts/check_pages.mjs` **159 checks PASS** (structure / mobile nav / hooks / 12 exports / URN & MCP semantics) |
| Unified error contract | `ProtocolError` trait (part/code/message), typed suberrors across the stack |

### Capabilities & Boundaries

- **Library only**: protocol modeling and interaction state machines; no protocol endpoint services, encoding side, or UI — server assembly belongs to the host application.
- The protocol core is **sans-I/O**: transport-agnostic; the transport extension covers TCP NDJSON and TLS (peer SHA-256 fingerprint pinning).
- **Not included**: MQ fan-out, SM-suite (SM2/SM3/SM4) interconnect security — 0.2.0 roadmap (see CHANGELOG).
- mTLS mutual client certificates are limited by the @tls API; implemented equivalently via peer certificate SHA-256 fingerprint pinning (GAP-2).
- Windows-local `moon prove` is affected by a moon toolchain `\\?` mkdir platform bug; proof verification runs on WSL/CI (GAP-1).
- **Ordering semantics**: `urn_list` / `peer_urns` / `names` use MoonBit's native `Compare` (shortlex: length first); equal-length URNs are lexicographic. Use a custom comparator when strict lexicographic order is required (GAP-5).
- **Coverage basis**: native instrumentation points 811/883 = 91.8% (2026-11-24), excluding `transport_async`/`playground`/`examples`; the legacy 94.8% denominator is no longer reproducible and is retired (GAP-6).
- Full honest ledger: [docs/known-gaps.md](docs/known-gaps.md). Suitable for MoonBit agent / multi-agent projects that need GB/Z 185-2026 protocol modeling.

### FAQ

**Why do envelope sequence numbers start at 1?**
Monotonic increase is the GB/Z 185.6 anti-replay contract — each envelope's sequence must be strictly greater than the sender's historical max, formally proved by `verify/next_seq` via Z3 (see `docs/TEST_REPORT.md` §6).

**How do I switch transports?**
The protocol core (`aip`) is sans-I/O and transport-agnostic. Built-ins: `FakeTransport` (in-memory), `TcpChannel`/`TlsTcpChannel` (transport_async, TCP NDJSON / TLS with peer SHA256 fingerprint pinning).

**Do group-message sequences collide?**
No — each peer's inbox has an independent sequence space; same-sequence envelopes fanned out to different members never interfere (`aip/fanout`).

**What does an AIC look like?**
Dot-separated decimal fields (OID style, ≥ 2 segments); this stack allocates `1.2.156.185.2.*` (illustrative prefix; authoritative allocation belongs to the ACPs registry service). Validation: `identity/aic_validate` (per-character state machine).

**When will SM2/SM3/SM4 be available?**
0.2.0 roadmap (mooncry primitives ready, transport_async integration in progress); the current interconnect security layer is TLS + peer fingerprint pinning.

### License

MIT. Upstream reference: [UCToo/agentskills-runtime](https://atomgit.com/UCToo/agentskills-runtime) (Cangjie implementation).
