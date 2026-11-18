# gbz185.mbt

<p align="left">
  <a href="https://github.com/walkzzz/gbz185.mbt/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <img alt="MoonBit" src="https://img.shields.io/badge/MoonBit-%E6%9C%88%E5%85%94-purple">
  <img alt="Tests" src="https://img.shields.io/badge/tests-77%2F77%20passing-brightgreen">
  <img alt="Targets" src="https://img.shields.io/badge/targets-native%7Cjs%7Cwasm%7Cwasm--gc-orange">
  <img alt="Standard" src="https://img.shields.io/badge/GB%2FZ%20185--2026-%E6%99%BA%E8%83%BD%E4%BD%93%E4%BA%92%E8%81%94-red">
</p>

**简体中文（默认）** · [English](#english)

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

公共层：`wire/`（**ProtocolError** 统一错误特征 + JSON 编解码工具 + 信封常量）、`transport_async/`（传输扩展：TCP NDJSON + TLS 对端指纹钉扎，MQ 分发于 0.2.0）、`verify/`（`proof_enabled` 形式化验证：`clamp_i64` / `next_seq` / `inbox_advance` 三命题经 moon prove 证明，证明义务由 SMT 机器可查）。

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
| 身份码校验（185.2） | `@identity.aic_validate` · `AgentIdentity::from_json` |
| 注册 / 鉴权 / 生命周期（185.3） | `@registry.TokenRegistry::register` → `authenticate` → `lock / revoke / renew` |
| 能力描述与覆盖判断（185.4） | `@capability.AgentCapabilitySet::covers` |
| 智能体发现与匹配（185.5） | `@discovery.AgentNode::from_frontmatter` · `match_nodes` |
| 交互收发（185.6） | `@aip.AipProtocol::dispatch / receive` · `AipSession::send / recv` |
| 群组路由与扇出 | `@aip.RouteTable::add_group` · `fanout` |
| 信封 JSON 编解码 | `@aip.AipEnvelope::to_json / from_json` |
| 工具单源模型（185.7） | `@tooling.ToolDescriptor::validate` · `ToolRegistry::invoke_tool` · `to_mcp_entry` |
| 统一错误契约 | `@wire.ProtocolError` 特征（全栈 suberror 分型） |
| 传输扩展 | `@transport_async.TcpChannel` · `TlsTcpChannel` · `ndjson_encode / ndjson_decode` |
| 形式化验证 | `@verify.clamp_i64 / next_seq / inbox_advance` |

## 质量门禁

| 门禁 | 结果 |
| --- | --- |
| `moon check --deny-warn --target all` | 四目标零警告 |
| `moon test --target native` | **77/77 全绿（2026-11-18 实测）**（黑盒/白盒/Fake Transport/quickcheck 属性/小模型 mock 消费，seed 固定可复现） |
| 形式化验证 | `verify/` 包 `proof_enabled`——**moon prove 3 goals proved**（Z3 4.8.12/WSL） |
| 覆盖率 | 94.8%；CRAP 全函数 < 10 |
| 变异测试 | 12/12 KILLED（击杀率 100%） |
| 基准实测 | dispatch 90.51ns / registry_lookup 96.29ns / envelope_roundtrip 1.69µs |
| 统一错误契约 | `ProtocolError` 特征（part/code/message），全栈 suberror 分型 |

## 能力与边界

- **定位即库**：仅协议建模与交互状态机，不含协议端点服务、编码侧与 UI；服务端组装属上层应用。
- 协议核心 **sans-I/O**：不感知传输；传输扩展覆盖 TCP NDJSON 与 TLS（对端 SHA-256 指纹钉扎）。
- **不含**：MQ 分发、国密套件（SM2/SM3/SM4）互联安全层——0.2.0 路线图（见 CHANGELOG）。
- mTLS 双向客户端证书受 @tls API 限制，以对端证书 SHA-256 指纹钉扎等效实现（GAP-2）。
- Windows 本地 `moon prove` 受 moon 工具链 `\\?` mkdir 平台 bug 影响，证明验证走 WSL/CI（GAP-1）。
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

Common layers: `wire/` (**ProtocolError** unified error trait + JSON helpers + envelope constants), `transport_async/` (transport extension: TCP NDJSON + TLS peer fingerprint pinning, MQ at 0.2.0), `verify/` (`proof_enabled` formal verification: `clamp_i64` / `next_seq` / `inbox_advance` proved via moon prove, machine-checkable SMT obligations).

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
| Identity code validation (185.2) | `@identity.aic_validate` · `AgentIdentity::from_json` |
| Register / auth / lifecycle (185.3) | `@registry.TokenRegistry::register` → `authenticate` → `lock / revoke / renew` |
| Capability & coverage (185.4) | `@capability.AgentCapabilitySet::covers` |
| Discovery & matching (185.5) | `@discovery.AgentNode::from_frontmatter` · `match_nodes` |
| Send / receive (185.6) | `@aip.AipProtocol::dispatch / receive` · `AipSession::send / recv` |
| Group routing & fanout | `@aip.RouteTable::add_group` · `fanout` |
| Envelope JSON codec | `@aip.AipEnvelope::to_json / from_json` |
| Tool single source (185.7) | `@tooling.ToolDescriptor::validate` · `ToolRegistry::invoke_tool` · `to_mcp_entry` |
| Unified error contract | `@wire.ProtocolError` trait (typed suberrors across the stack) |
| Transport extension | `@transport_async.TcpChannel` · `TlsTcpChannel` · `ndjson_encode / ndjson_decode` |
| Formal verification | `@verify.clamp_i64 / next_seq / inbox_advance` |

### Quality

| Gate | Result |
| --- | --- |
| `moon check --deny-warn --target all` | zero warnings on 4 targets |
| `moon test --target native` | **77/77 green (measured 2026-11-18)** (blackbox/whitebox/Fake Transport/quickcheck properties/model-based mock consumption, fixed seeds) |
| Formal verification | `verify/` with `proof_enabled` — **moon prove 3 goals proved** (Z3 4.8.12/WSL) |
| Coverage | 94.8%; CRAP < 10 on all functions |
| Mutation testing | 12/12 KILLED (100% kill rate) |
| Benchmarks | dispatch 90.51ns / registry_lookup 96.29ns / envelope_roundtrip 1.69µs |
| Unified error contract | `ProtocolError` trait (part/code/message), typed suberrors across the stack |

### Capabilities & Boundaries

- **Library only**: protocol modeling and interaction state machines; no protocol endpoint services, encoding side, or UI — server assembly belongs to the host application.
- The protocol core is **sans-I/O**: transport-agnostic; the transport extension covers TCP NDJSON and TLS (peer SHA-256 fingerprint pinning).
- **Not included**: MQ fan-out, SM-suite (SM2/SM3/SM4) interconnect security — 0.2.0 roadmap (see CHANGELOG).
- mTLS mutual client certificates are limited by the @tls API; implemented equivalently via peer certificate SHA-256 fingerprint pinning (GAP-2).
- Windows-local `moon prove` is affected by a moon toolchain `\\?` mkdir platform bug; proof verification runs on WSL/CI (GAP-1).
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
