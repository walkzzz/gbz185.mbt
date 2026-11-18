// AIP 协议属性测试（quickcheck，seed 固定可复现；形式化性质的可执行投影补充）

///|
test "property: MessageKind wire roundtrip for arbitrary index" {
  @quickcheck.check(
    fn(i : Int32) -> Bool {
      let kinds = [
        @aip.TaskRequest,
        @aip.TaskResult,
        @aip.Event,
        @aip.Heartbeat,
      ]
      let kind = kinds[i & 3]
      match @aip.MessageKind::from_wire(kind.to_wire()) {
        Some(k) => k == kind
        None => false
      }
    },
    count=200,
    seed=2026,
  )
}

///|
test "property: IdentityStatus wire roundtrip for arbitrary index" {
  @quickcheck.check(
    fn(i : Int32) -> Bool {
      let statuses = [
        @identity.NoIdentity,
        @identity.Active,
        @identity.Locked,
        @identity.Revoked,
      ]
      let status = statuses[i & 3]
      match @identity.IdentityStatus::from_wire(status.to_wire()) {
        Some(s) => s == status
        None => false
      }
    },
    count=200,
    seed=2027,
  )
}

///|
test "property: dispatch sequence is strictly monotonic" {
  @quickcheck.check(
    fn(n : Int32) -> Bool {
      let count = (n & 15) + 1
      let node = @discovery.AgentNode::from_frontmatter(
        "urn:agent:a",
        "A",
        @identity.Active,
        true,
        [],
        [],
        [],
      )
      let proto = @aip.AipProtocol::new(node)
      let mut prev = 0L
      for _ in 0..<count {
        let env = @aip.AipProtocol::dispatch(
          proto,
          @aip.Heartbeat,
          "urn:agent:group:g",
          ("x" : Json),
        ) catch {
          _ => return false
        }
        if env.seq <= prev {
          return false
        }
        prev = env.seq
      }
      true
    },
    count=100,
    seed=2028,
  )
}

///|
test "property: replay verdict follows seq ordering" {
  @quickcheck.check(
    fn(pair : (Int32, Int32)) -> Bool {
      let (x, y) = pair
      let first_seq = (x.mod(100).abs() + 1).to_int64()
      let second_seq = (y.mod(100).abs() + 1).to_int64()
      let node = @discovery.AgentNode::from_frontmatter(
        "urn:agent:a",
        "A",
        @identity.Active,
        true,
        [],
        [],
        [],
      )
      let proto = @aip.AipProtocol::new(node)
      let env1 = @aip.AipEnvelope::from_json({
        "envelope_version": "1",
        "protocol": "aip",
        "sender_urn": "urn:agent:b",
        "recipient_urn": "urn:agent:a",
        "seq": Json::number(first_seq.to_double()),
        "timestamp": Json::number(0.0),
        "kind": "event",
        "payload": "p1",
      }) catch {
        _ => return false
      }
      let r1 : Result[@aip.AipMessage, @aip.AipError] = Ok(
        @aip.AipProtocol::receive(proto, env1),
      ) catch {
        err => Err(err)
      }
      let first_ok = match r1 {
        Ok(m) => m.seq == first_seq
        Err(_) => false
      }
      if !first_ok {
        return false
      }
      let env2 = { ..env1, seq: second_seq, }
      let r2 : Result[@aip.AipMessage, @aip.AipError] = Ok(
        @aip.AipProtocol::receive(proto, env2),
      ) catch {
        err => Err(err)
      }
      match r2 {
        Ok(m) => second_seq > first_seq && m.seq == second_seq
        Err(_) => second_seq <= first_seq
      }
    },
    count=200,
    seed=2029,
  )
}

///|
test "property: envelope wire roundtrip preserves numeric payload" {
  @quickcheck.check(
    fn(n : Int32) -> Bool {
      let node = @discovery.AgentNode::from_frontmatter(
        "urn:agent:a",
        "A",
        @identity.Active,
        true,
        [],
        [],
        [],
      )
      let proto = @aip.AipProtocol::new(node)
      let payload : Json = Json(n.to_double())
      let env = @aip.AipProtocol::dispatch(
        proto,
        @aip.Event,
        "urn:agent:group:g",
        payload,
      ) catch {
        _ => return false
      }
      let back = @aip.AipEnvelope::from_json(env.to_json()) catch {
        _ => return false
      }
      back == env
    },
    count=100,
    seed=2030,
  )
}
