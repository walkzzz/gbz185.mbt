// FakeTransport 双实例互通测试（TC-F17-002 的本地模式版）

///|
test "fake transport: two instances exchange messages both ways" {
  let a = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.Active,
    true,
    [],
    [],
    [],
  )
  let b = @discovery.AgentNode::from_frontmatter(
    "urn:agent:b",
    "B",
    @identity.Active,
    true,
    ["skill:demo"],
    [],
    [],
  )
  let pa = @aip.AipProtocol::new(a)
  let pb = @aip.AipProtocol::new(b)
  let _ = @aip.AipProtocol::handle_discover_response(pa, { nodes: [b], })
  let msg = @aip.send_direct(pa, pb, @aip.TaskRequest, ("do" : Json)) catch {
    _ => panic()
  }
  assert_eq(msg.sender_urn, "urn:agent:a")
  assert_eq(msg.seq, 1L)
  assert_eq(msg.kind, @aip.TaskRequest)
  let _ = @aip.AipProtocol::handle_discover_response(pb, { nodes: [a], })
  let reply = @aip.send_direct(pb, pa, @aip.TaskResult, ("done" : Json)) catch {
    _ => panic()
  }
  assert_eq(reply.sender_urn, "urn:agent:b")
  assert_eq(reply.seq, 1L)
  assert_eq(reply.kind, @aip.TaskResult)
  assert_true(@aip.AipProtocol::invariant(pa))
  assert_true(@aip.AipProtocol::invariant(pb))
}

///|
test "fake transport: replay across direct channel rejected" {
  let a = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.Active,
    true,
    [],
    [],
    [],
  )
  let b = @discovery.AgentNode::from_frontmatter(
    "urn:agent:b",
    "B",
    @identity.Active,
    true,
    [],
    [],
    [],
  )
  let pa = @aip.AipProtocol::new(a)
  let pb = @aip.AipProtocol::new(b)
  let _ = @aip.AipProtocol::handle_discover_response(pa, { nodes: [b], })
  let first = @aip.AipProtocol::dispatch(
    pa,
    @aip.Event,
    "urn:agent:b",
    ("e1" : Json),
  )
  let msg = @aip.AipProtocol::receive(pb, first) catch { _ => panic() }
  assert_eq(msg.seq, 1L)
  // 中间人重放：同一信封（seq=1）二次投递 → 拒绝
  let mut rejected = false
  try {
    let _ = @aip.AipProtocol::receive(pb, first)
    panic()
  } catch {
    @aip.Envelope(_) => rejected = true
    _ => panic()
  }
  assert_true(rejected)
}
