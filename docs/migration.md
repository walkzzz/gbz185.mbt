# 迁移指南（迁入 gbz185.mbt 0.2.0）

> 适用：从「手写 JSON 协议 / 自定义 RPC / 上游仓颉运行时」迁到本库的项目。

## 1. 迁移步骤

### 1.1 依赖与包选择

```bash
moon add walkzzz/gbz185.mbt@0.2.0
moon update
```

按需引入包（不要引入不需要的分部）：

| 需求 | 包 |
| --- | --- |
| 身份码校验 | `identity` |
| 注册/鉴权/生命周期 | `registry` |
| 能力描述与匹配 | `capability` |
| 发现过滤 | `discovery` |
| 信封/会话/路由/扇出 | `aip` |
| 工具描述与调用 | `tooling` |
| 错误契约与 JSON helpers | `wire` |
| TCP/TLS 传输 | `transport_async`（native-only） |

### 1.2 把自有协议映射到 wire 模型

1. 身份：把自有 ID 映射为 AIC（`aic_validate` 校验），状态写入 `IdentityStatus`；
2. 注册：实现 `CAIVerifier`（凭证校验），用 `TokenRegistry::register` 取回 AIC；
3. 能力：把技能/工具清单写入 `AgentCapabilitySet::capabilities`；
4. 发现：用 `AgentNode::from_frontmatter` 构造节点，`match_nodes` 过滤；
5. 交互：`AipProtocol::dispatch` / `receive` 替换自有收发；
6. 工具：用 `ToolDescriptor` 单源替换自有工具描述，`ToolRegistry` 记录调用。

### 1.3 传输接入

协议核心 sans-I/O。若已有 TCP 通道：

- 直接复用 `transport_async::ndjson_encode` / `ndjson_decode` 做帧编解码；
- 或自定义 Transport：`receive` 的输入就是 `AipEnvelope`，无需适配核心。

### 1.4 行为对齐检查表

| 检查项 | 期望 |
| --- | --- |
| 序号推进 | 每次 `dispatch` 严格 +1（`outbox_seq()` 可观测） |
| 防重放 | 重复/倒退序号被 `receive` 拒绝（`inbox_watermark()` 可观测） |
| 群组扇出 | 成员数 = 信封数；各成员 recipient 正确替换 |
| 消息标识 | `AipEnvelope::message_id() == "sender#seq"`，与 `AipMessage.message_id` 一致 |
| 能力匹配 | `covers(req) == (missing(req).length() == 0)` |
| 发现过滤 | `match_nodes` 与逐节点 `matches` 结果一致 |
| 排序 | `urn_list` / `peer_urns` / `names` 为 shortlex（见 §3） |

## 2. 常见坑

1. **Int64 与 JSON 数字**：信封 `seq` / `timestamp` 必须用 `Json::number(x.to_double())`；直接用 `Json(x)` 会得到字符串，JS 端 `from_json` 将拒绝。
2. **`Option[X]` 没有 `.to_json()`**：可选字段须显式 `match`（空值写 `Json::null()`）。
3. **跨包实现 trait 需要 `pub(open)`**：自定义 `CAIVerifier` / `ToolCallable` 时不要改核心包可见性。
4. **async 测试限制**：MoonBit 测试块不可调用 async 函数；`transport_async` 的 E2E 走 `cmd main` + shell 脚本。
5. **.mbti 契约**：升级后先 `moon info` 并检查 `pkg.generated.mbti` diff，再改代码。
6. **排序不是字典序**：MoonBit `String` 的 `Compare` 为 shortlex；需要严格字典序请自定义比较。

## 3. 从旧版 0.1.0 升级（0.1.0 → 0.2.0）

- 新增 API（无破坏）：`IdentityStatus::is_active`、`AgentIdentity::is_active`、
  `AgentCapabilitySet::count/covers_any/missing`、`AgentNode::matches`、
  `TokenRegistry::is_registered/urn_list`、`AipProtocol::is_registered/outbox_seq/inbox_watermark/peer_urns`、
  `AipEnvelope::message_id`、`AipSession::session_id/local_urn/remote_urn/outbox_seq`、
  `RouteTable::is_member`、`ToolRegistry::is_registered/names`。
- 行为优化（语义等价）：`find_by_capability` 需求去重 + 长度剪枝。
- 口径修正：覆盖率统一为插桩点口径（91.8%），旧「94.8%」不再引用。

## 4. 0.2.1（演示层语义修正）

- `playground` 的 `aip_make_envelope` / `aip_validate` / `aip_fanout_count` 增加取值语义：
  空 sender/recipient、`seq ≤ 0`、`timestamp < 0` 被拒绝；扇出 0 成员返回 **-2**。
- 库核心契约（`aip` 包）**未变**；仅演示层包装更严格。若下游直接复用演示层函数，需按新语义处理返回值与错误信息。

## 5. 回滚策略

0.2.x 不存在删除或改名；如需回滚只需将依赖钉回 `0.1.0`。`playground` 与 `docs/` 不参与库 API，不影响下游编译。
