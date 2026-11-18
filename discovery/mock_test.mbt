// 小模型 mock 数据消费测试（fake LLM simulation：每次 seed 不同 → 不同 mock 数据）
// 注意：信封变异测试在 aip/mock_test.mbt（AipEnvelope 属 aip 包，GB/Z 185.6 域）

///|
test "mock generator produces distinct nodes per seed" {
  let a = @discovery.generate_mock_nodes(1, 3)
  let b = @discovery.generate_mock_nodes(2, 3)
  assert_eq(a.length(), 3)
  assert_eq(b.length(), 3)
  assert_false(a[0] == b[0])
  assert_false(a[1] == b[1])
}

///|
test "mock nodes survive wire roundtrip" {
  let nodes = @discovery.generate_mock_nodes(42, 8)
  for n in nodes {
    let back = @discovery.AgentNode::from_json(n.to_json()) catch { _ => panic() }
    assert_eq(back, n)
  }
}

///|
test "mock nodes feed match_nodes with capability filter" {
  let nodes = @discovery.generate_mock_nodes(7, 10)
  let matched = @discovery.match_nodes(nodes[:], ["skill:demo"], require_discoverable=false)
  for m in matched {
    assert_true(m.acs.covers(["skill:demo"]))
  }
  // discoverable 过滤同样生效
  let visible = @discovery.match_nodes(nodes[:], [])
  for m in visible {
    assert_true(m.discoverable)
  }
}
