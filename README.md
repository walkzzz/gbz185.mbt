# gbz185.mbt

MoonBit implementation of the **GB/Z 185-2026《人工智能 智能体互联》** national standard stack (Parts 1-7), extracted from the agentskills runtime port as an independent, reusable protocol asset.

## Stack

| Part | Package | Content |
| --- | --- | --- |
| GB/Z 185.1 | `arch.mbt` (root) | 总体架构：双模式（本地/互联）、全局模型、角色定义 |
| GB/Z 185.2 | `identity/` | AIC 身份码编码结构/唯一标识/CAI 凭证/identity_status |
| GB/Z 185.3 | `registry/` | ATR 注册/凭证/鉴权/生命周期/注销（CAIVerifier 注入） |
| GB/Z 185.4 | `capability/` | ACS 能力元数据/接口/输入输出/约束 |
| GB/Z 185.5 | `discovery/` | ADP 检索/匹配/discoverable 可见性过滤 |
| GB/Z 185.6 | `aip/` | **AIP** 报文信封/单调序号防重放/群组路由/FakeTransport |
| GB/Z 185.7 | `tooling/` | 工具描述 ToolDescriptor（单源）/调用流程/绑定 |

Plus: `wire/`（ProtocolError 特征 + JSON helpers）、`transport-async/`（W12）、`verify/`（proof_enabled 形式化）。

## Quality

- `moon check --deny-warn --target all`：四目标零警告
- `moon test`：47/47 全绿（黑盒/白盒/Fake/quickcheck 属性，seed 固定）
- Mutation testing：10/10 KILLED（见 agentskills 主仓 docs/TEST_REPORT.md 方法）
- `moon info`：全部包 .mbti 契约生成

## Usage

```bash
moon add walkzzz/gbz185.mbt
moon update
```

```moonbit
// 构造智能体节点（GB/Z 185.2/185.4/185.5 模型）
let node = @discovery.AgentNode::from_frontmatter(
  "urn:agent:walkzzz:node-1", "Demo", @identity.NoIdentity, true,
  ["skill:demo"], ["text"], ["text"],
)
let proto = @aip.AipProtocol::new(node)
// GB/Z 185.3 注册 → 激活
@registry.TokenRegistry::new() |> ignore
// GB/Z 185.6 交互：群组分发
let env = @aip.AipProtocol::dispatch(proto, @aip.Event, "urn:agent:group:ops", ("hello" : Json))
```

## License

MIT. Upstream reference: [UCToo/agentskills-runtime](https://atomgit.com/UCToo/agentskills-runtime) (Cangjie).
