// GB/Z 185.4 ACS 匹配原语扩充测试（count / missing / covers_any 与 covers 的对偶关系）

///|
fn acs_of(caps : Array[String]) -> @capability.AgentCapabilitySet {
  {
    capabilities: caps,
    default_input_types: [],
    default_output_types: [],
    constraints: [],
  }
}

///|
test "capability count reports entry length" {
  assert_eq(@capability.AgentCapabilitySet::empty().count(), 0)
  assert_eq(acs_of(["a", "b", "c"]).count(), 3)
}

///|
test "missing preserves input order and removes duplicates" {
  let acs = acs_of(["skill:demo", "tool:file_read"])
  let missing = acs.missing(["tool:net_fetch", "skill:demo", "tool:net_fetch"])
  assert_eq(missing.length(), 1)
  assert_eq(missing[0], "tool:net_fetch")
  assert_eq(acs.missing([]).length(), 0)
}

///|
test "covers and missing are dual for the same requirement" {
  let acs = acs_of(["a", "b"])
  let cases : Array[Array[String]] = [
    [],
    ["a"],
    ["a", "b"],
    ["a", "c"],
    ["c", "d"],
    ["a", "a", "b"],
  ]
  for req in cases {
    assert_eq(acs.covers(req[:]), acs.missing(req[:]).length() == 0)
  }
}

///|
test "covers_any matches at least one requirement" {
  let acs = acs_of(["skill:demo"])
  assert_true(acs.covers_any(["tool:net_fetch", "skill:demo"]))
  assert_false(acs.covers_any(["tool:net_fetch"]))
  assert_false(acs.covers_any([]))
  assert_false(@capability.AgentCapabilitySet::empty().covers_any(["a"]))
}
