// GB/Z 185.6 AIP 基准测试（moon bench / @bench.T::bench；性能实测回填 GATE_REPORT 整改项 3）

///|
test (b : @bench.T) {
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
  let reg = @registry.TokenRegistry::new()
  for i in 0..<200 {
    let bench_node = @discovery.AgentNode::from_frontmatter(
      "urn:agent:bench:\{i}",
      "N\{i}",
      @identity.Active,
      true,
      [],
      [],
      [],
    )
    let _ = @registry.TokenRegistry::register(reg, bench_node, AcceptAllBench::{
    })
  }

  b.bench(name="envelope_wire_roundtrip", fn() {
    let back = @aip.AipEnvelope::from_json(env.to_json()) catch { _ => panic() }
    b.keep(back)
  })

  b.bench(name="dispatch_pipeline", fn() {
    b.keep(
      @aip.AipProtocol::dispatch(
        proto,
        @aip.Heartbeat,
        "urn:agent:group:g",
        ("x" : Json),
      ),
    ) catch {
      _ => ()
    }
  })

  b.bench(name="registry_lookup", fn() {
    b.keep(@registry.TokenRegistry::lookup(reg, "urn:agent:bench:100"))
  })

  // GB/Z 185.3 能力检索基准：1000 节点（800 个 4 能力 + 200 个 8 能力），需求 8 项 →
  // 长度剪枝对 800 个候选直接跳过 covers 扫描；结果恒为 200。
  let reg_big = @registry.TokenRegistry::new(max_entries=2000)
  for i in 0..<1000 {
    let caps : Array[String] = []
    let width = if i % 5 == 0 { 8 } else { 4 }
    for j in 0..<width {
      caps.push("cap:\{j}")
    }
    let pool_node = @discovery.AgentNode::from_frontmatter(
      "urn:agent:pool:\{i}",
      "P\{i}",
      @identity.Active,
      true,
      caps,
      [],
      [],
    )
    let _ = @registry.TokenRegistry::register(reg_big, pool_node, AcceptAllBench::{
    }) catch {
      _ => ""
    }
  }
  let need : Array[String] = [
    "cap:0", "cap:1", "cap:2", "cap:3", "cap:4", "cap:5", "cap:6", "cap:7",
  ]
  let matches_before = @registry.TokenRegistry::find_by_capability(
    reg_big,
    need[:],
  ).length()

  b.bench(name="registry_find_by_capability_1000x8", fn() {
    b.keep(
      @registry.TokenRegistry::find_by_capability(reg_big, need[:]).length(),
    )
  })
  assert_eq(matches_before, 200)
}

///|
priv struct AcceptAllBench {}

///|
impl @registry.CAIVerifier for AcceptAllBench with fn verify(_self, _cai) {
  true
}
