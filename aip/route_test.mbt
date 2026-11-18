// GB/Z 185.6 AIP 路由黑盒测试（classify/路由表/resolve 三分支/群组扇出）

///|
test "route target classify: group / unicast / unknown" {
  assert_true(
    @aip.RouteTarget::classify("urn:agent:group:ops", @wire.group_urn_prefix())
    is @aip.Group(_),
  )
  assert_true(
    @aip.RouteTarget::classify("urn:agent:b", @wire.group_urn_prefix())
    is @aip.Unicast(_),
  )
  assert_true(
    @aip.RouteTarget::classify("mailto:x", @wire.group_urn_prefix())
    is @aip.Unknown,
  )
}

///|
test "route table: group membership join/leave idempotent" {
  let table = @aip.RouteTable::new()
  @aip.RouteTable::join(table, "urn:agent:group:ops", "urn:agent:a")
  @aip.RouteTable::join(table, "urn:agent:group:ops", "urn:agent:a")
  @aip.RouteTable::join(table, "urn:agent:group:ops", "urn:agent:b")
  assert_eq(@aip.RouteTable::members(table, "urn:agent:group:ops").length(), 2)
  assert_true(
    @aip.RouteTable::leave(table, "urn:agent:group:ops", "urn:agent:a"),
  )
  assert_false(
    @aip.RouteTable::leave(table, "urn:agent:group:ops", "urn:agent:a"),
  )
  assert_eq(@aip.RouteTable::members(table, "urn:agent:group:ops").length(), 1)
  assert_eq(@aip.RouteTable::group_count(table), 1)
}

///|
test "route resolve: fanout / direct / reject branches" {
  let table = @aip.RouteTable::new()
  @aip.RouteTable::join(table, "urn:agent:group:ops", "urn:agent:a")
  @aip.RouteTable::join(table, "urn:agent:group:ops", "urn:agent:b")
  @aip.RouteTable::add_peer(table, "urn:agent:c", "tcp://127.0.0.1:9000")
  match @aip.RouteTable::resolve(table, "urn:agent:group:ops") {
    @aip.Fanout(members) => assert_eq(members.length(), 2)
    _ => panic()
  }
  match @aip.RouteTable::resolve(table, "urn:agent:c") {
    @aip.Direct(urn) => assert_eq(urn, "urn:agent:c")
    _ => panic()
  }
  match @aip.RouteTable::resolve(table, "urn:agent:unknown") {
    @aip.Reject(_) => ()
    _ => panic()
  }
  match @aip.RouteTable::resolve(table, "urn:agent:group:empty") {
    @aip.Reject(_) => ()
    _ => panic()
  }
  match @aip.RouteTable::resolve(table, "mailto:x") {
    @aip.Reject(_) => ()
    _ => panic()
  }
}

///|
test "fanout: group envelope expands per member with fields preserved" {
  let base = @aip.AipEnvelope::from_json({
    "envelope_version": "1",
    "protocol": "aip",
    "sender_urn": "urn:agent:sender",
    "recipient_urn": "urn:agent:group:ops",
    "seq": 7.0,
    "timestamp": 0.0,
    "kind": "task_request",
    "payload": "p",
  }) catch {
    _ => panic()
  }
  let out = @aip.fanout(base, ["urn:agent:a", "urn:agent:b"][:])
  assert_eq(out.length(), 2)
  assert_eq(out[0].recipient_urn, "urn:agent:a")
  assert_eq(out[1].recipient_urn, "urn:agent:b")
  assert_eq(out[0].seq, 7L)
  assert_eq(out[1].sender_urn, "urn:agent:sender")
  // 扇出信封仍可 wire 往返
  for env in out {
    let back = @aip.AipEnvelope::from_json(env.to_json()) catch { _ => panic() }
    assert_eq(back, env)
  }
}
