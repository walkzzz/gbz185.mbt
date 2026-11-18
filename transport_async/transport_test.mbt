// transport-async 黑盒测试：NDJSON 帧编解码纯逻辑（TCP 往返 E2E 用 scripts/transport_e2e.mbtx）

///|
test "ndjson frame roundtrip preserves envelope" {
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
  let env = @aip.AipProtocol::dispatch(
    proto,
    @aip.Event,
    "urn:agent:group:g",
    ("x" : Json),
  )
  let frame = @transport_async.ndjson_encode(env)
  // 帧以换行结尾
  assert_true(frame.has_suffix("\n"))
  // 解码往返
  let back = @transport_async.ndjson_decode(frame) catch { _ => panic() }
  assert_eq(back, env)
}

///|
test "ndjson decode: without trailing newline also accepted" {
  let frame = "{\"envelope_version\":\"1\",\"protocol\":\"aip\",\"sender_urn\":\"urn:agent:b\",\"recipient_urn\":\"urn:agent:a\",\"seq\":1.0,\"timestamp\":0.0,\"kind\":\"event\",\"payload\":\"p\"}"
  let back = @transport_async.ndjson_decode(frame) catch { _ => panic() }
  assert_eq(back.sender_urn, "urn:agent:b")
  assert_eq(back.seq, 1L)
}

///|
test "ndjson decode: invalid json raises frame-invalid" {
  let mut got = false
  try {
    let _ = @transport_async.ndjson_decode("not-a-json\n")
    panic()
  } catch {
    @transport_async.FrameInvalid(_) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "ndjson decode: wrong protocol raises frame-invalid" {
  let frame = "{\"envelope_version\":\"1\",\"protocol\":\"smtp\",\"sender_urn\":\"urn:agent:b\",\"recipient_urn\":\"urn:agent:a\",\"seq\":1.0,\"timestamp\":0.0,\"kind\":\"event\",\"payload\":\"p\"}"
  let mut got = false
  try {
    let _ = @transport_async.ndjson_decode(frame)
    panic()
  } catch {
    @transport_async.FrameInvalid(_) => got = true
    _ => panic()
  }
  assert_true(got)
}
