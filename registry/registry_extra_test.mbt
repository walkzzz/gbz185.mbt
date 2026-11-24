// GB/Z 185.3 ATR 查询与能力检索剪枝测试（is_registered / urn_list / find_by_capability 等价性）

///|
fn reg_node(urn : String, caps : Array[String]) -> @discovery.AgentNode {
  @discovery.AgentNode::from_frontmatter(
    urn,
    urn,
    @identity.NoIdentity,
    true,
    caps,
    [],
    [],
  )
}

///|
test "is_registered follows lifecycle" {
  let reg = @registry.TokenRegistry::new()
  assert_false(reg.is_registered("urn:agent:a"))
  let _ = reg.register(reg_node("urn:agent:a", ["skill:demo"]), AcceptAll::{ }) catch {
    _ => panic()
  }
  assert_true(reg.is_registered("urn:agent:a"))
  reg.unregister("urn:agent:a") catch {
    _ => panic()
  }
  assert_false(reg.is_registered("urn:agent:a"))
}

///|
test "urn_list is lexicographically sorted" {
  let reg = @registry.TokenRegistry::new()
  for urn in ["urn:agent:c", "urn:agent:a", "urn:agent:b"] {
    let _ = reg.register(reg_node(urn, []), AcceptAll::{ }) catch {
      _ => panic()
    }
  }
  assert_eq(reg.urn_list(), ["urn:agent:a", "urn:agent:b", "urn:agent:c"])
}

///|
test "find_by_capability dedups requirements without changing results" {
  let reg = @registry.TokenRegistry::new()
  let _ = reg.register(reg_node("urn:agent:a", ["skill:demo"]), AcceptAll::{ }) catch {
    _ => panic()
  }
  let once = reg.find_by_capability(["skill:demo"][:])
  let twice = reg.find_by_capability(["skill:demo", "skill:demo"][:])
  assert_eq(once, twice)
  assert_eq(once.length(), 1)
}

///|
test "length pruning keeps equal-size and superset candidates" {
  let reg = @registry.TokenRegistry::new()
  let _ = reg.register(reg_node("urn:agent:exact", ["a", "b"]), AcceptAll::{ }) catch {
    _ => panic()
  }
  let _ = reg.register(reg_node("urn:agent:extra", ["a", "b", "c"]), AcceptAll::{
  }) catch {
    _ => panic()
  }
  let _ = reg.register(reg_node("urn:agent:short", ["a"]), AcceptAll::{ }) catch {
    _ => panic()
  }
  let found = reg.find_by_capability(["a", "b"][:])
  let urns : Array[String] = []
  for n in found {
    urns.push(n.urn)
  }
  urns.sort()
  assert_eq(urns, ["urn:agent:exact", "urn:agent:extra"])
  assert_eq(reg.find_by_capability([]).length(), 3)
}
