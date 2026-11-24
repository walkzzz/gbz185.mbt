// GB/Z 185.6 AIP 状态查询与消息标识单源测试（outbox/inbox/peer_urns/message_id/session getter）

///|
fn active_node(urn : String) -> @discovery.AgentNode {
  @discovery.AgentNode::from_frontmatter(
    urn,
    urn,
    @identity.Active,
    true,
    [],
    [],
    [],
  )
}

///|
test "protocol exposes outbox seq and replay watermark" {
  let proto = @aip.AipProtocol::new(active_node("urn:agent:a"))
  assert_eq(proto.outbox_seq(), 0L)
  assert_eq(proto.inbox_watermark("urn:agent:b"), 0L)
  let env = proto.dispatch(@aip.Event, "urn:agent:group:g", ("x" : Json)) catch {
    _ => panic()
  }
  assert_eq(proto.outbox_seq(), 1L)
  let receiver = @aip.AipProtocol::new(active_node("urn:agent:b"))
  let incoming = { ..env, recipient_urn: "urn:agent:b", seq: 7L, }
  let _ = receiver.receive(incoming) catch { _ => panic() }
  assert_eq(receiver.inbox_watermark("urn:agent:a"), 7L)
}

///|
test "peer_urns is sorted and is_registered follows identity" {
  let proto = @aip.AipProtocol::new(active_node("urn:agent:a"))
  let b = active_node("urn:agent:b")
  let c = active_node("urn:agent:c")
  let _ = proto.handle_discover_response({ nodes: [c, b], })
  assert_eq(proto.peer_urns(), ["urn:agent:b", "urn:agent:c"])
  assert_true(proto.is_registered())
  let pending = @aip.AipProtocol::new(
    @discovery.AgentNode::from_frontmatter(
      "urn:agent:p",
      "P",
      @identity.NoIdentity,
      true,
      [],
      [],
      [],
    ),
  )
  assert_false(pending.is_registered())
}

///|
test "envelope message id is the single source used by receive" {
  let env : @aip.AipEnvelope = {
    envelope_version: @aip.envelope_version(),
    sender_urn: "urn:agent:b",
    recipient_urn: "urn:agent:a",
    seq: 9L,
    timestamp: 0L,
    kind: @aip.Event,
    payload: Json::empty_object(),
  }
  assert_eq(env.message_id(), "urn:agent:b#9")
  let proto = @aip.AipProtocol::new(active_node("urn:agent:a"))
  let msg = proto.receive(env) catch { _ => panic() }
  assert_eq(msg.message_id, env.message_id())
}

///|
test "session getters and closed session rejection" {
  let session = @aip.AipSession::open("s-1", "urn:agent:a", "urn:agent:b")
  assert_eq(session.session_id(), "s-1")
  assert_eq(session.local_urn(), "urn:agent:a")
  assert_eq(session.remote_urn(), "urn:agent:b")
  assert_eq(session.outbox_seq(), 0L)
  let env = session.send(@aip.Heartbeat, Json::empty_object()) catch {
    _ => panic()
  }
  assert_eq(env.seq, 1L)
  assert_eq(session.outbox_seq(), 1L)
  session.close()
  assert_false(session.is_active())
  let mut got = false
  try {
    let _ = session.send(@aip.Heartbeat, Json::empty_object())
    panic()
  } catch {
    @aip.Envelope(_) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "route table is_member reflects membership" {
  let table = @aip.RouteTable::new()
  table.add_group("urn:agent:group:ops")
  table.join("urn:agent:group:ops", "urn:agent:a")
  assert_true(table.is_member("urn:agent:group:ops", "urn:agent:a"))
  assert_false(table.is_member("urn:agent:group:ops", "urn:agent:b"))
  assert_false(table.is_member("urn:agent:group:missing", "urn:agent:a"))
  let _ = table.leave("urn:agent:group:ops", "urn:agent:a")
  assert_false(table.is_member("urn:agent:group:ops", "urn:agent:a"))
}
