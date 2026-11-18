// GB/Z 185.6 AIP 域：信封变异模糊测试（小模型 fake 数据消费；数据由 aip/mock_data.mbt 生成）
// 性质：变异信封的 receive 裁决——接收 ⇔ seq 严格大于该 sender 已收最大序号（防重放契约）。

///|
test "mutated envelopes: accept only strictly increasing seq" {
  let node = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a", "A", @identity.Active, true, [], [], [],
  )
  let proto = @aip.AipProtocol::new(node)
  let base : @aip.AipEnvelope = {
    envelope_version: @aip.envelope_version(),
    sender_urn: "urn:agent:b",
    recipient_urn: "urn:agent:a",
    seq: 5L,
    timestamp: 0L,
    kind: @aip.Event,
    payload: ("x" : Json),
  }
  let mut inbox_b = 0L
  for seed in 0..<20 {
    let mutated = @aip.generate_mutated_envelope(base, seed)
    let with_sender = { ..mutated, sender_urn: "urn:agent:b" }
    let verdict : Result[@aip.AipMessage, @aip.AipError] = try {
      Ok(@aip.AipProtocol::receive(proto, with_sender))
    } catch {
      err => Err(err)
    }
    match verdict {
      Ok(_) => {
        assert_true(with_sender.seq > inbox_b)
        inbox_b = with_sender.seq
      }
      Err(_) => assert_true(with_sender.seq <= inbox_b)
    }
  }
}

///|
test "mock dispatch envelopes are all deliverable (seed 化批量)" {
  let node = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a", "A", @identity.Active, true, [], [], [],
  )
  let proto = @aip.AipProtocol::new(node)
  let envs = @aip.generate_dispatch_envelopes(proto, 99, 25)
  assert_eq(envs.length(), 25)
  // 序号严格单调（每个信封递增）
  for i in 1..<envs.length() {
    assert_true(envs[i].seq > envs[i - 1].seq)
  }
  // 全部可 wire 往返
  for env in envs {
    let back = @aip.AipEnvelope::from_json(env.to_json()) catch { _ => panic() }
    assert_eq(back, env)
  }
}
