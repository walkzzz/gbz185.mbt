// GB/Z 185-2026 AIP 最小演示：智能体节点 → 会话收发 → 群组扇出。
// GB/Z 185-2026 AIP minimal demo: agent node -> session send/recv -> group fanout.
// 运行 / Run: moon run examples/echo_demo

///|
fn main {
  // GB/Z 185.5：构造智能体节点（AGENTS.md frontmatter 字段映射）
  // GB/Z 185.5: build agent node (AGENTS.md frontmatter field mapping)
  let node = @discovery.AgentNode::from_frontmatter(
    "urn:agent:walkzzz:demo",
    "Demo Agent",
    @identity.Active,
    true,
    ["skill:demo"],
    ["text"],
    ["text"],
  )
  println("Agent: \{node.urn} (ACS caps=\{node.acs.capabilities.length()})")

  // GB/Z 185.6：打开会话（sans-I/O 演示——真实传输见 transport_async 包）
  // GB/Z 185.6: open session (sans-I/O demo — real transport lives in transport_async)
  let session = @aip.AipSession::open(
    "demo-session", "urn:agent:walkzzz:demo", "urn:agent:peer",
  )
  let env = session.send(@aip.TaskRequest, ("demo payload" : Json)) catch {
    _ => panic()
  }
  println("Sent: seq=\{env.seq} -> \{env.recipient_urn}")

  // 会话内接收（对端回执：身份反转 + 独立序号空间）
  // In-session receive (peer reply: swapped identity + independent seq space)
  let reply = {
    ..env,
    sender_urn: "urn:agent:peer",
    recipient_urn: "urn:agent:walkzzz:demo",
    seq: 1L,
  }
  let msg = session.recv(reply) catch { _ => panic() }
  println("Recv: \{msg.message_id} payload=\{msg.payload.stringify()}")

  // GB/Z 185.6：群组扇出（群组信封展开为逐成员信封）
  // GB/Z 185.6: group fanout (group envelope expands per member)
  let out = @aip.fanout(env, ["urn:agent:m1", "urn:agent:m2"][:])
  println("Fanout: \{out.length()} envelopes")

  // 形式化不变量断言（verify 包证明函数的运行时投影）
  // Formal invariant assertion (runtime projection of proven functions)
  println("Session messages: \{session.message_count()}")
}
