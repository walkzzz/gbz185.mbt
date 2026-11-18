// GB/Z 185.6 AIP 黑盒测试（注册/发现/交互/防重放/错误分型；对齐 TCA TC-F17-001~005）

///|
test "envelope json wire roundtrip (TC-F17-003)" {
  let a = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.Active,
    true,
    [],
    [],
    [],
  )
  let pa = @aip.AipProtocol::new(a)
  let payload : Json = { "body": "hello" }
  let env = @aip.AipProtocol::dispatch(
    pa,
    @aip.Event,
    "urn:agent:group:g",
    payload,
  ) catch {
    err => {
      println("dispatch failed: \{err}")
      panic()
    }
  }
  let back = @aip.AipEnvelope::from_json(env.to_json()) catch {
    err => {
      println("from_json failed: \{err}")
      panic()
    }
  }
  assert_eq(back, env)
}

///|
test "atr register flow (GB/Z 185.3)" {
  let node = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.NoIdentity,
    true,
    [],
    [],
    [],
  )
  let proto = @aip.AipProtocol::new(node)
  let req = @aip.AipProtocol::register_request(proto)
  assert_true(req.node.identity.identity_status is @identity.NoIdentity)
  @aip.AipProtocol::handle_register_response(proto, {
    accepted: true,
    aic: Some("1.2.156.185.2.1.42"),
    reason: None,
  }) catch {
    _ => panic()
  }
  assert_true(
    @aip.AipProtocol::identity(proto).identity_status is @identity.Active,
  )
  assert_eq(@aip.AipProtocol::identity(proto).aic, "1.2.156.185.2.1.42")
}

///|
test "atr reject raises registry error" {
  let node = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.NoIdentity,
    true,
    [],
    [],
    [],
  )
  let proto = @aip.AipProtocol::new(node)
  let mut got = false
  try {
    @aip.AipProtocol::handle_register_response(proto, {
      accepted: false,
      aic: None,
      reason: Some("denied"),
    })
    panic()
  } catch {
    @aip.Registry(_) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "adp discover registers discoverable peers (GB/Z 185.5)" {
  let a = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.Active,
    true,
    [],
    [],
    [],
  )
  let proto = @aip.AipProtocol::new(a)
  let b = @discovery.AgentNode::from_frontmatter(
    "urn:agent:b",
    "B",
    @identity.Active,
    true,
    ["skill:demo"],
    [],
    [],
  )
  let hidden = @discovery.AgentNode::from_frontmatter(
    "urn:agent:c",
    "C",
    @identity.Active,
    false,
    ["skill:demo"],
    [],
    [],
  )
  let added = @aip.AipProtocol::handle_discover_response(proto, {
    nodes: [b, hidden],
  })
  assert_eq(added, 1)
  assert_true(@aip.AipProtocol::peer(proto, "urn:agent:b") is Some(_))
  assert_true(@aip.AipProtocol::peer(proto, "urn:agent:c") is None)
  assert_eq(@aip.AipProtocol::peer_count(proto), 1)
}

///|
test "aip dispatch and receive with replay rejection (GB/Z 185.6)" {
  let a = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.Active,
    true,
    [],
    [],
    [],
  )
  let pa = @aip.AipProtocol::new(a)
  let b = @discovery.AgentNode::from_frontmatter(
    "urn:agent:b",
    "B",
    @identity.Active,
    true,
    [],
    [],
    [],
  )
  let pb = @aip.AipProtocol::new(b)
  let _ = @aip.AipProtocol::handle_discover_response(pa, { nodes: [b], })
  let env = @aip.AipProtocol::dispatch(
    pa,
    @aip.TaskRequest,
    "urn:agent:b",
    ("ping" : Json),
  ) catch {
    _ => panic()
  }
  assert_eq(env.seq, 1L)
  let msg = @aip.AipProtocol::receive(pb, env) catch { _ => panic() }
  assert_eq(msg.sender_urn, "urn:agent:a")
  let env2 = { ..env, seq: 2L, payload: ("pong" : Json), }
  let msg2 = @aip.AipProtocol::receive(pb, env2) catch { _ => panic() }
  assert_eq(msg2.seq, 2L)
  let mut rejected = false
  try {
    let _ = @aip.AipProtocol::receive(pb, env2)
    panic()
  } catch {
    @aip.Envelope(_) => rejected = true
    _ => panic()
  }
  assert_true(rejected)
}

///|
test "dispatch requires active identity" {
  let node = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.NoIdentity,
    true,
    [],
    [],
    [],
  )
  let proto = @aip.AipProtocol::new(node)
  let mut got = false
  try {
    let _ = @aip.AipProtocol::dispatch(
      proto,
      @aip.Event,
      "urn:agent:group:g",
      ("x" : Json),
    )
    panic()
  } catch {
    @aip.Registry(_) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "unknown unicast recipient rejected" {
  let a = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.Active,
    true,
    [],
    [],
    [],
  )
  let proto = @aip.AipProtocol::new(a)
  let mut got = false
  try {
    let _ = @aip.AipProtocol::dispatch(
      proto,
      @aip.Event,
      "urn:agent:unknown",
      ("x" : Json),
    )
    panic()
  } catch {
    @aip.Dispatch(_) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "envelope version and protocol checks" {
  let a = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.Active,
    true,
    [],
    [],
    [],
  )
  let pa = @aip.AipProtocol::new(a)
  let env = @aip.AipProtocol::dispatch(
    pa,
    @aip.Heartbeat,
    "urn:agent:group:g",
    Json::empty_object(),
  ) catch {
    _ => panic()
  }
  let bad_version = { ..env, envelope_version: "9", }
  let b = @discovery.AgentNode::from_frontmatter(
    "urn:agent:b",
    "B",
    @identity.Active,
    true,
    [],
    [],
    [],
  )
  let pb = @aip.AipProtocol::new(b)
  let mut got = false
  try {
    let _ = @aip.AipProtocol::receive(pb, bad_version)
    panic()
  } catch {
    @aip.Envelope(_) => got = true
    _ => panic()
  }
  assert_true(got)
  let mut decode_rejected = false
  try {
    let _ = @aip.AipEnvelope::from_json(bad_version.to_json())
    panic()
  } catch {
    @wire.BadValue(_, _) => decode_rejected = true
    _ => panic()
  }
  assert_true(decode_rejected)
}

///|
test "aip error domain and protocol contract" {
  let err : @aip.AipError = @aip.Envelope("bad")
  assert_eq(err.error_domain(), "gbz185.6")
  let err2 : @aip.AipError = @aip.Discovery("missing")
  assert_eq(err2.error_domain(), "gbz185.5")
  // ProtocolError 统一契约（特征系统）
  assert_eq(err.part(), "gbz185.6")
  assert_eq(err.code(), "AIP-6005")
  let err3 : @aip.AipError = @aip.Dispatch("no peer")
  assert_eq(err3.code(), "AIP-6004")
}
