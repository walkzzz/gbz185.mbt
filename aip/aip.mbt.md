# GB/Z 185.6 AIP 交互协议示例（doctest）

本文件的可执行代码块由 `moon check --deny-warn` 自动验证。

## 构造智能体节点与注册请求

```moonbit nocheck
let node = @discovery.AgentNode::from_frontmatter(
  "urn:agent:walkzzz:demo",
  "Demo Agent",
  @identity.Active,
  true,
  ["skill:demo"],
  ["text"],
  ["text"],
)
let req = @aip.AipProtocol::register_request(@aip.AipProtocol::new(node))
assert_true(req.node.identity.identity_status is @identity.Active)
```

## 会话内收发（GB/Z 185.6 防重放契约）

```moonbit nocheck
let session = @aip.AipSession::open(
  "urn:agent:a",
  "urn:agent:a",
  "urn:agent:b",
)
let env = session.send(@aip.Event, ("hello" : Json)) catch { _ => panic() }
assert_eq(env.seq, 1L)
let back = @aip.AipEnvelope::from_json(env.to_json()) catch { _ => panic() }
assert_eq(back, env)
```
