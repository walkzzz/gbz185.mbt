# 架构设计（gbz185.mbt 0.2.0）

> 范围：`walkzzz/gbz185.mbt` —— GB/Z 185-2026《人工智能 智能体互联》第 1-7 部分协议栈。
> 本文描述包边界、依赖方向、关键决策与数据流；数字口径见 [TEST_REPORT.md](TEST_REPORT.md)。

## 1. 包分层

```
            GB/Z 185 协议栈（上层调用下层，依赖单向）
 ────────────────────────────────────────────────────────────────
  185.7  tooling/         ToolDescriptor 单源模型 · ToolRegistry · 调用日志
  185.6  aip/             AipEnvelope · AipProtocol · AipSession · RouteTable · fanout
  185.5  discovery/       AgentNode · AgentNode::matches · match_nodes
  185.4  capability/      AgentCapabilitySet · covers / covers_any / missing
  185.3  registry/        TokenRegistry · CAIVerifier 注入 · 生命周期 · 审计
  185.2  identity/        AIC 校验 · IdentityStatus · AgentIdentity
  185.1  arch.mbt（根包）  双模式 · 全局模型 · 互联角色
 ────────────────────────────────────────────────────────────────
  公共层  wire/            ProtocolError 特征 · JSON helpers · 常量
          verify/          moon prove 证明函数（Z3）
          transport_async/ TCP NDJSON · TLS 指纹钉扎（native-only 扩展）
```

依赖方向固定：`aip → discovery → capability → identity → wire`；`registry → discovery`；`tooling → wire`；`transport_async → aip + wire`。**不存在反向依赖**，因此核心包可在 js / wasm / wasm-gc / native 四目标编译。

## 2. 关键设计决策

| 决策 | 说明 | 代价 / 边界 |
| --- | --- | --- |
| **sans-I/O 核心** | 协议核心不感知时钟与网络；时间戳、传输由调用方注入 | 调用方须自备时钟与 I/O |
| **wire 统一错误契约** | `ProtocolError`（part / code / message）由各包 suberror 实现 | 新增包须实现三方法 |
| **trait/闭包注入** | `CAIVerifier`（凭证校验）、`ToolCallable`（工具实现）均为 `pub(open)` 注入点 | 核心零 mooncakes 依赖 |
| **Int64 数字字段显式 `Json::number`** | 避免 Int64 默认序列化为字符串造成 JS 端类型漂移 | 反序列化统一走 `json_int64_field` |
| **消息标识单源** | `AipEnvelope::message_id` 定义 `sender#seq`；接收侧 `AipMessage` 复用 | 禁止在别处拼接 ID |
| **mbti 契约入库** | `moon info` 生成 `.mbti` 并提交，CI 检查漂移 | 任何公开签名变更须同提交 |

## 3. 核心数据流

### 3.1 注册（185.3 客户端面）

`AipProtocol::register_request` → 外部注册中心 → `AipProtocol::handle_register_response`
→ 身份置为 `Active` 并写入 AIC（`is_registered()` 由 `IdentityStatus::is_active` 投影）。

### 3.2 发现（185.5 客户端面）

`AipProtocol::discover_request` → `DiscoverResponse` → `handle_discover_response`
（跳过自身与不可发现节点；同 URN 内容变化才计数）→ `peer_urns()` 给出稳定清单。

### 3.3 交互（185.6）

`dispatch`：`is_registered` 门槛 → 群组 URN 直通 / 单播须已发现 → `verify.next_seq` 推进序号 → 信封。
`receive`：版本 / 收件人 / 自环 / `verify.inbox_advance` 防重放 → `AipMessage`（`message_id` 取 `env.message_id()`）。
`fanout`：成员列表展开为逐成员信封，各对端序号空间独立。

### 3.4 能力与发现匹配（185.4 / 185.5）

`AgentCapabilitySet::covers` 为全量覆盖；`covers_any` 为任一匹配；`missing` 返回缺失项（保持顺序、去重）。
`AgentNode::matches` 是发现过滤的原子判定（可见性 + 覆盖），`match_nodes` 逐节点复用，保证单点/批量语义一致。

## 4. 排序语义（重要）

MoonBit 的 `Compare for String` 是 **shortlex（先长度、后逐字符）**。因此：

- `TokenRegistry::urn_list`、`AipProtocol::peer_urns`、`ToolRegistry::names` 返回 **shortlex 确定性顺序**；
- 本栈 URN 等长时等价于字典序；
- 若下游需要严格字典序，请自行 `sort_by` 逐字符比较，不要假设 `sort()` 是字典序。

## 5. 不变量

- `AipProtocol::invariant`：`outbox_seq >= 0` 且自身 URN 具有 `urn:agent:` 前缀。
- 防重放：同一发送者的序号严格递增（Z3 证明 `next_seq` / `inbox_advance`，并被真实调用）。
- 注册容量：`register` 在 `count >= max_entries` 时拒绝（`verify.register_within_capacity`）。
- 能力检索剪枝：候选能力条目数 < 去重需求数时必然不覆盖（严格等价优化，见 [performance.md](performance.md)）。

## 6. 包边界与不做的部分

- `aip` 只做「群组地址扇出」协议语义，组内编排属上层应用。
- `tooling` 只提供单源描述与调用流程；具体工具实现由 `ToolCallable` / 闭包注入。
- `transport_async` 为扩展包，`supported_targets = "native"`；核心不依赖它。
- 不含协议端点服务、编码侧 UI、MQ 与国密套件（见 [known-gaps.md](known-gaps.md)）。
