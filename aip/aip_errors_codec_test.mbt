// aip 错误分型与消息编解码补充测试（E3 全变体 + 四原语 wire 往返/非法分支）

///|
test "aip error variants expose code message domain" {
  let errors : Array[@aip.AipError] = [
    @aip.Discovery("d"),
    @aip.Registry("r"),
    @aip.Capability("c"),
    @aip.Dispatch("p"),
    @aip.Envelope("e"),
  ]
  let codes : Array[String] = []
  for e in errors {
    codes.push(e.code())
    assert_true(e.message().length() > 0)
    assert_true(e.to_string().length() > 0)
    assert_true(e.to_json().stringify().contains(e.part()))
    assert_true(e.error_domain().has_prefix("gbz185."))
  }
  assert_eq(codes, ["AIP-6001", "AIP-6002", "AIP-6003", "AIP-6004", "AIP-6005"])
}

///|
test "primitive messages round-trip through json" {
  let discover : @aip.DiscoverRequest = {
    requester_urn: "urn:agent:a",
    filter_capabilities: ["skill:demo"],
  }
  assert_eq(
    @aip.DiscoverRequest::from_json(discover.to_json()) catch {
      _ => panic()
    },
    discover,
  )
  let register : @aip.RegisterRequest = {
    node: @discovery.AgentNode::from_frontmatter(
      "urn:agent:a",
      "A",
      @identity.Active,
      true,
      [],
      [],
      [],
    ),
  }
  assert_eq(
    @aip.RegisterRequest::from_json(register.to_json()) catch {
      _ => panic()
    },
    register,
  )
  let resp : @aip.RegisterResponse = {
    accepted: true,
    aic: None,
    reason: Some("ok"),
  }
  assert_eq(
    @aip.RegisterResponse::from_json(resp.to_json()) catch {
      _ => panic()
    },
    resp,
  )
  let cap_req : @aip.CapabilityRequest = {
    requester_urn: "urn:agent:a",
    target_urn: "urn:agent:b",
  }
  assert_eq(
    @aip.CapabilityRequest::from_json(cap_req.to_json()) catch {
      _ => panic()
    },
    cap_req,
  )
}

///|
test "discover response rejects non-array nodes" {
  let mut got = false
  try {
    let _ = @aip.DiscoverResponse::from_json({ "nodes": 1.0 })
    panic()
  } catch {
    @wire.BadType(_, _) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "envelope from_json rejects bad protocol and missing payload" {
  let bad_protocol = try {
    let _ = @aip.AipEnvelope::from_json({
      "envelope_version": "1",
      "protocol": "other",
      "sender_urn": "a",
      "recipient_urn": "b",
      "seq": 1.0,
      "timestamp": 0.0,
      "kind": "event",
      "payload": {},
    })
    ""
  } catch {
    @wire.BadValue(field, _) => field
    _ => "unexpected"
  }
  assert_eq(bad_protocol, "protocol")

  let missing_payload = try {
    let _ = @aip.AipEnvelope::from_json({
      "envelope_version": "1",
      "protocol": "aip",
      "sender_urn": "a",
      "recipient_urn": "b",
      "seq": 1.0,
      "timestamp": 0.0,
      "kind": "event",
    })
    ""
  } catch {
    @wire.MissingField(field) => field
    _ => "unexpected"
  }
  assert_eq(missing_payload, "payload")
}
