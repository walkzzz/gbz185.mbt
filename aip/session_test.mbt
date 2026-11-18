// GB/Z 185.6 AIP 会话黑盒测试（open/send/recv/close 生命周期 + 防重放 + 身份校验）

///|
test "session: open, send with per-session monotonic seq, receive" {
  let session = @aip.AipSession::open("sess-1", "urn:agent:a", "urn:agent:b")
  assert_true(session.is_active())
  let e1 = session.send(@aip.TaskRequest, ("q1" : Json)) catch { _ => panic() }
  let e2 = session.send(@aip.Event, ("q2" : Json)) catch { _ => panic() }
  let e3 = session.send(@aip.Heartbeat, Json::empty_object()) catch {
    _ => panic()
  }
  assert_eq(e1.seq, 1L)
  assert_eq(e2.seq, 2L)
  assert_eq(e3.seq, 3L)
  assert_eq(e1.recipient_urn, "urn:agent:b")
  assert_eq(session.message_count(), 0)
  // 对端回信（seq 独立空间）
  let reply = {
    ..e1,
    sender_urn: "urn:agent:b",
    recipient_urn: "urn:agent:a",
    seq: 1L,
  }
  let msg = session.recv(reply) catch { _ => panic() }
  assert_eq(msg.message_id, "sess-1#1")
  assert_eq(session.message_count(), 1)
  assert_eq(session.inbox_watermark(), 1L)
}

///|
test "session: recv rejects wrong peer and stale seq" {
  let session = @aip.AipSession::open("sess-2", "urn:agent:a", "urn:agent:b")
  let e1 = session.send(@aip.Event, ("x" : Json)) catch { _ => panic() }
  let _ = session.recv({
    ..e1,
    sender_urn: "urn:agent:b",
    recipient_urn: "urn:agent:a",
    seq: 1L,
  }) catch {
    _ => panic()
  }
  // 非 peer 发件人拒绝
  let mut wrong_peer = false
  try {
    let _ = session.recv({
      ..e1,
      sender_urn: "urn:agent:c",
      recipient_urn: "urn:agent:a",
      seq: 2L,
    })
    panic()
  } catch {
    @aip.Envelope(_) => wrong_peer = true
    _ => panic()
  }
  assert_true(wrong_peer)
  // 陈旧序号拒绝（防重放）
  let mut stale = false
  try {
    let _ = session.recv({
      ..e1,
      sender_urn: "urn:agent:b",
      recipient_urn: "urn:agent:a",
      seq: 1L,
    })
    panic()
  } catch {
    @aip.Envelope(_) => stale = true
    _ => panic()
  }
  assert_true(stale)
}

///|
test "session: close rejects send and recv (idempotent close)" {
  let session = @aip.AipSession::open("sess-3", "urn:agent:a", "urn:agent:b")
  session.close()
  session.close()
  let mut send_rejected = false
  try {
    let _ = session.send(@aip.Event, ("x" : Json))
    panic()
  } catch {
    @aip.Envelope(_) => send_rejected = true
    _ => panic()
  }
  assert_true(send_rejected)
  let mut recv_rejected = false
  try {
    let _ = session.recv({
      envelope_version: @aip.envelope_version(),
      sender_urn: "urn:agent:b",
      recipient_urn: "urn:agent:a",
      seq: 1L,
      timestamp: 0L,
      kind: @aip.Event,
      payload: ("x" : Json),
    })
    panic()
  } catch {
    @aip.Envelope(_) => recv_rejected = true
    _ => panic()
  }
  assert_true(recv_rejected)
}
