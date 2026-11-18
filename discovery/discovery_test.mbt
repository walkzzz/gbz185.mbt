// GB/Z 185.5 ADP 黑盒测试（wire 往返 / discoverable 过滤 / 能力匹配）

///|
test "agent node wire roundtrip with nested identity/acs" {
  let node = @discovery.AgentNode::from_frontmatter(
    "urn:agent:walkzzz:node-1",
    "Node One",
    @identity.Active,
    true,
    ["skill:demo"],
    ["text"],
    ["text"],
  )
  let back = @discovery.AgentNode::from_json(node.to_json()) catch {
    _ => panic()
  }
  assert_eq(back, node)
}

///|
test "match_nodes filters hidden and non-matching nodes" {
  let a = @discovery.AgentNode::from_frontmatter(
    "urn:agent:a",
    "A",
    @identity.Active,
    true,
    ["skill:demo"],
    [],
    [],
  )
  let b = @discovery.AgentNode::from_frontmatter(
    "urn:agent:b",
    "B",
    @identity.Active,
    true,
    ["tool:file_read"],
    [],
    [],
  )
  let hidden = @discovery.AgentNode::from_frontmatter(
    "urn:agent:c",
    "C",
    @identity.Active,
    false,
    ["skill:demo"],
    [],
    [],
  )
  let matched = @discovery.match_nodes([a, b, hidden][:], ["skill:demo"])
  assert_eq(matched.length(), 1)
  assert_eq(matched[0].urn, "urn:agent:a")
  // 不过滤能力 → 全部可发现节点
  let all = @discovery.match_nodes([a, b, hidden][:], [])
  assert_eq(all.length(), 2)
  // 关闭 discoverable 过滤 → 隐藏节点也返回
  let all_no_filter = @discovery.match_nodes(
    [a, b, hidden][:],
    [],
    require_discoverable=false,
  )
  assert_eq(all_no_filter.length(), 3)
}
