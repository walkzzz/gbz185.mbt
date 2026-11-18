// GB/Z 185.6 AIP 基准测试（moon bench / @bench.T::bench；性能实测回填 GATE_REPORT 整改项 3）

///|
test (b : @bench.T) {
  let node = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a", "A", @identity.Active, true, [], [], [],
  )
  let proto = @aip.AipProtocol::new(node)
  let env = @aip.AipProtocol::dispatch(
    proto, @aip.Event, "urn:agent:group:g", ("x" : Json),
  )
  let reg = @registry.TokenRegistry::new()
  for i in 0..<200 {
    let bench_node = @discovery.AgentNode::from_frontmatter(
      "urn:agent:bench:\{i}", "N\{i}", @identity.Active, true, [], [], [],
    )
    let _ = @registry.TokenRegistry::register(reg, bench_node, AcceptAllBench::{})
  }

  b.bench(name="envelope_wire_roundtrip", fn() {
    let back = @aip.AipEnvelope::from_json(env.to_json()) catch { _ => panic() }
    b.keep(back)
  })

  b.bench(name="dispatch_pipeline", fn() {
    try {
      b.keep(
        @aip.AipProtocol::dispatch(
          proto, @aip.Heartbeat, "urn:agent:group:g", ("x" : Json),
        ),
      )
    } catch {
      _ => ()
    }
  })

  b.bench(name="registry_lookup", fn() {
    b.keep(@registry.TokenRegistry::lookup(reg, "urn:agent:bench:100"))
  })
}

///|
priv struct AcceptAllBench {}

///|
impl @registry.CAIVerifier for AcceptAllBench with fn verify(_self, _cai) {
  true
}
