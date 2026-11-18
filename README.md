# gbz185.mbt

<p align="left">
  <a href="https://github.com/walkzzz/gbz185.mbt/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <img alt="MoonBit" src="https://img.shields.io/badge/MoonBit-%E6%9C%88%E5%85%94-purple">
  <img alt="Tests" src="https://img.shields.io/badge/tests-47%2F47%20passing-brightgreen">
  <img alt="Targets" src="https://img.shields.io/badge/targets-native%7Cjs%7Cwasm%7Cwasm--gc-orange">
  <img alt="Standard" src="https://img.shields.io/badge/GB%2FZ%20185--2026-%E6%99%BA%E8%83%BD%E4%BD%93%E4%BA%92%E8%81%94-red">
</p>

**简体中文（默认）** · [English](#english)

---

MoonBit 实现的 **GB/Z 185-2026《人工智能 智能体互联》国家标准指导性技术文件协议栈**（第 1-7 部分），从 agentskills 运行时移植项目中抽取的独立、可复用协议资产。零第三方运行时依赖（核心包仅依赖 MoonBit 核心库），四目标编译（native/js/wasm/wasm-gc）。

## 国标协议栈

| 部分 | 包 | 内容 | 状态 |
| --- | --- | --- | --- |
| GB/Z 185.1 | `arch.mbt`（根包） | 总体架构：双模式（本地/互联）、全局模型（agents/agent_skills/agent_messages/agent_tasks/sessions）、互联角色定义 | ✅ |
| GB/Z 185.2 | `identity/` | 身份码 **AIC**（Agent Identity Code）点分编码结构与校验、唯一标识、CAI 凭证引用、`identity_status`（none/active/locked/revoked） | ✅ |
| GB/Z 185.3 | `registry/` | 身份管理 **ATR**（Agent Token Registry）：注册（AIC 分配）、凭证、鉴权（CAIVerifier 注入）、生命周期（lock/revoke）、注销 | ✅ |
| GB/Z 185.4 | `capability/` | 智能体描述 **ACS**（Agent Capability Statement）：能力元数据、输入输出类型、约束（constraints）、匹配原语 | ✅ |
| GB/Z 185.5 | `discovery/` | 智能体发现 **ADP**（Agent Discovery Protocol）：检索、能力匹配、`discoverable` 可见性过滤 | ✅ |
| GB/Z 185.6 | `aip/` | 智能体交互 **AIP**（Agent Interconnection Protocol）：报文信封、单调序号防重放、群组 URN 路由、FakeTransport（sans-I/O） | ✅ 核心完成，transport-async 于 W12 |
| GB/Z 185.7 | `tooling/` | 智能体工具调用：`ToolDescriptor` 单源模型、调用流程、绑定契约（ToolCallable） | ✅ 模型完成 |

公共层：`wire/`（**ProtocolError** 统一错误特征 + JSON 编解码工具 + 信封常量）、`transport-async/`（传输扩展，W12：@socket/@tls/MQ）、`verify/`（`proof_enabled` 形式化验证，证明义务由 SMT 机器可查）。

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

## 质量门禁

| 门禁 | 结果 |
| --- | --- |
| `moon check --deny-warn --target all` | 四目标零警告 |
| `moon test` | 47/47 全绿（黑盒/白盒/Fake Transport/quickcheck 属性，seed 固定可复现） |
| 形式化验证 | `verify/` 包 `proof_enabled`（moon prove / Why3 + SMT） |
| 统一错误契约 | `ProtocolError` 特征（part/code/message），全栈 suberror 分型 |

适用场景：需要 GB/Z 185-2026 协议建模的 MoonBit 智能体/多智能体项目。
不适用：需要 HTTP/TLS/MQ 传输层的生产部署（`transport-async/` 于 W12 提供，当前为协议核心 sans-I/O）。

## 许可证

MIT。上游参考：[UCToo/agentskills-runtime](https://atomgit.com/UCToo/agentskills-runtime)（仓颉实现）。

---

<a id="english"></a>

## English

MoonBit implementation of the **GB/Z 185-2026 "AI Agent Interconnection" national standard stack** (Parts 1-7), extracted from the agentskills runtime port as an independent, reusable protocol asset. Zero third-party runtime dependencies (core packages depend only on the MoonBit core library); compiles to four targets (native/js/wasm/wasm-gc).

### Stack

| Part | Package | Content | Status |
| --- | --- | --- | --- |
| GB/Z 185.1 | `arch.mbt` (root) | Overall architecture: dual mode (local/interconnect), global model, interconnect roles | ✅ |
| GB/Z 185.2 | `identity/` | **AIC** identity code structure/validation, CAI credential reference, `identity_status` | ✅ |
| GB/Z 185.3 | `registry/` | **ATR**: register (AIC assignment), credentials, authentication (CAIVerifier injection), lifecycle, unregister | ✅ |
| GB/Z 185.4 | `capability/` | **ACS**: capability metadata, input/output types, constraints, match primitive | ✅ |
| GB/Z 185.5 | `discovery/` | **ADP**: search, capability matching, `discoverable` visibility filtering | ✅ |
| GB/Z 185.6 | `aip/` | **AIP**: envelope, monotonic-sequence anti-replay, group URN routing, FakeTransport (sans-I/O) | ✅ core done, transport-async at W12 |
| GB/Z 185.7 | `tooling/` | Tool invocation: `ToolDescriptor` single-source model, invocation flow, binding contract | ✅ model done |

Common layers: `wire/` (**ProtocolError** unified error trait + JSON helpers + envelope constants), `transport-async/` (W12: @socket/@tls/MQ), `verify/` (`proof_enabled` formal verification, machine-checkable proof obligations).

### Install

```bash
moon add walkzzz/gbz185.mbt
moon update
```

### Quality

| Gate | Result |
| --- | --- |
| `moon check --deny-warn --target all` | zero warnings on 4 targets |
| `moon test` | 47/47 green (blackbox/whitebox/Fake/quickcheck properties, fixed seeds) |
| Formal verification | `verify/` with `proof_enabled` (moon prove / Why3 + SMT) |
| Unified error contract | `ProtocolError` trait (part/code/message), typed suberrors across the stack |

### License

MIT. Upstream reference: [UCToo/agentskills-runtime](https://atomgit.com/UCToo/agentskills-runtime) (Cangjie implementation).
