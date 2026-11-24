// 属性测试：能力匹配原语与 AIP 状态查询的可执行性质（quickcheck，seed 固定可复现）

///|
fn caps_for(n : Int32) -> Array[String] {
  let out : Array[String] = []
  let count = n.mod(4).abs()
  for i in 0..<count {
    out.push("c\{(n + i).mod(5).abs()}")
  }
  out
}

///|
test "property: covers iff missing is empty (capability duality)" {
  @quickcheck.check(
    fn(pair : (Int32, Int32)) -> Bool {
      let (a, b) = pair
      let acs : @capability.AgentCapabilitySet = {
        capabilities: caps_for(a),
        default_input_types: [],
        default_output_types: [],
        constraints: [],
      }
      let req = caps_for(b)
      acs.covers(req[:]) == (acs.missing(req[:]).length() == 0)
    },
    count=300,
    seed=2031,
  )
}

///|
test "property: covers_any iff some requirement is present" {
  @quickcheck.check(
    fn(pair : (Int32, Int32)) -> Bool {
      let (a, b) = pair
      let caps = caps_for(a)
      let acs : @capability.AgentCapabilitySet = {
        capabilities: caps,
        default_input_types: [],
        default_output_types: [],
        constraints: [],
      }
      let req = caps_for(b)
      let mut hit = false
      for r in req {
        for c in caps {
          if r == c {
            hit = true
          }
        }
      }
      acs.covers_any(req[:]) == hit
    },
    count=300,
    seed=2032,
  )
}

///|
test "property: outbox_seq equals dispatch count" {
  @quickcheck.check(
    fn(n : Int32) -> Bool {
      let count = (n & 7) + 1
      let proto = @aip.AipProtocol::new(
        @discovery.AgentNode::from_frontmatter(
          "urn:agent:a",
          "A",
          @identity.Active,
          true,
          [],
          [],
          [],
        ),
      )
      for _ in 0..<count {
        let _ = @aip.AipProtocol::dispatch(
          proto,
          @aip.Heartbeat,
          "urn:agent:group:g",
          Json::empty_object(),
        ) catch {
          _ => return false
        }
      }
      @aip.AipProtocol::outbox_seq(proto) == count.to_int64()
    },
    count=100,
    seed=2033,
  )
}

///|
test "property: message id is stable across receive" {
  @quickcheck.check(
    fn(seq : Int32) -> Bool {
      let s = (seq.mod(1000).abs() + 1).to_int64()
      let env : @aip.AipEnvelope = {
        envelope_version: @aip.envelope_version(),
        sender_urn: "urn:agent:b",
        recipient_urn: "urn:agent:a",
        seq: s,
        timestamp: 0L,
        kind: @aip.Event,
        payload: Json::empty_object(),
      }
      let proto = @aip.AipProtocol::new(
        @discovery.AgentNode::from_frontmatter(
          "urn:agent:a",
          "A",
          @identity.Active,
          true,
          [],
          [],
          [],
        ),
      )
      let msg = @aip.AipProtocol::receive(proto, env) catch {
        _ => return false
      }
      msg.message_id == env.message_id() &&
      msg.message_id == "urn:agent:b#\{s}" &&
      @aip.AipProtocol::inbox_watermark(proto, "urn:agent:b") == s
    },
    count=200,
    seed=2034,
  )
}
