// GB/Z 185.6 AIP 白盒测试（内部边界；json_string_array_opt 等已归 wire 包）

///|
test "wire constants pinned through aip facade" {
  assert_eq(envelope_version(), "1")
  assert_eq(protocol_name(), "aip")
}

///|
test "message from_wire rejects unknown values" {
  assert_true(MessageKind::from_wire("notify") is None)
  assert_true(MessageKind::from_wire("task_request") is Some(TaskRequest))
}

///|
test "outbox sequence starts at one" {
  let node = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.NoIdentity,
    true,
    [],
    [],
    [],
  )
  let proto = AipProtocol::new(node)
  AipProtocol::handle_register_response(proto, {
    accepted: true,
    aic: Some("1.2.156.185.2.1.99"),
    reason: None,
  })
  let env = AipProtocol::dispatch(
    proto,
    Event,
    "urn:agent:group:g",
    ("x" : Json),
  )
  assert_eq(env.seq, 1L)
}

///|
test "invariant holds across full protocol cycle" {
  let node = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.NoIdentity,
    true,
    ["skill"],
    [],
    [],
  )
  let proto = AipProtocol::new(node)
  assert_true(AipProtocol::invariant(proto))
  AipProtocol::handle_register_response(proto, {
    accepted: true,
    aic: Some("1.2.156.185.2.1.100"),
    reason: None,
  })
  assert_true(AipProtocol::invariant(proto))
  let peer = @discovery.AgentNode::from_frontmatter(
    "urn:agent:b",
    "B",
    @identity.Active,
    true,
    [],
    [],
    [],
  )
  let _ = AipProtocol::handle_discover_response(proto, { nodes: [peer], })
  let _ = AipProtocol::dispatch(proto, TaskRequest, "urn:agent:b", ("x" : Json))
  assert_true(AipProtocol::invariant(proto))
  assert_true(AipProtocol::peer_count(proto) == 1)
}
