// GB/Z 185.5 ADP 原子匹配测试（AgentNode::matches 与 match_nodes 的一致性）

///|
fn node_of(
  urn : String,
  caps : Array[String],
  discoverable : Bool,
) -> @discovery.AgentNode {
  @discovery.AgentNode::from_frontmatter(
    urn,
    urn,
    @identity.Active,
    discoverable,
    caps,
    [],
    [],
  )
}

///|
test "node matches applies visibility and coverage filters" {
  let visible = node_of("urn:agent:a", ["skill:demo"], true)
  let hidden = node_of("urn:agent:b", ["skill:demo"], false)
  assert_true(visible.matches(["skill:demo"]))
  assert_true(visible.matches([]))
  assert_false(visible.matches(["tool:net_fetch"]))
  assert_false(hidden.matches([]))
  assert_true(hidden.matches([], require_discoverable=false))
}

///|
test "match_nodes equals filtering by AgentNode::matches" {
  let nodes = [
    node_of("urn:agent:a", ["skill:demo"], true),
    node_of("urn:agent:b", ["tool:file_read"], true),
    node_of("urn:agent:c", ["skill:demo"], false),
  ]
  let filter = ["skill:demo"]
  let from_nodes = @discovery.match_nodes(nodes[:], filter)
  let by_atom : Array[@discovery.AgentNode] = []
  for n in nodes {
    if n.matches(filter) {
      by_atom.push(n)
    }
  }
  assert_eq(from_nodes, by_atom)
  assert_eq(from_nodes.length(), 1)
}
