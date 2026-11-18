// GB/Z 185.4 ACS 黑盒测试（wire 往返 / constraints 缺省 / covers 匹配原语）

///|
test "capability wire roundtrip preserves constraints" {
  let acs = @capability.AgentCapabilitySet::{
    capabilities: ["skill:demo", "tool:file_read"],
    default_input_types: ["text"],
    default_output_types: ["text", "json"],
    constraints: ["max_tokens<=1024"],
  }
  let back = @capability.AgentCapabilitySet::from_json(acs.to_json()) catch {
    _ => panic()
  }
  assert_eq(back, acs)
}

///|
test "from_json defaults absent arrays to empty (incl. constraints)" {
  let acs = @capability.AgentCapabilitySet::from_json(Json::empty_object()) catch {
    _ => panic()
  }
  assert_eq(acs.capabilities.length(), 0)
  assert_eq(acs.constraints.length(), 0)
}

///|
test "covers requires full capability intersection" {
  let acs = @capability.AgentCapabilitySet::from_json({
    "capabilities": ["skill:demo", "tool:file_read"],
  }) catch {
    _ => panic()
  }
  assert_true(acs.covers(["skill:demo"]))
  assert_true(acs.covers([]))
  assert_false(acs.covers(["skill:demo", "tool:net_fetch"]))
}

///|
test "bad element type raises wire error" {
  let mut got = false
  try {
    let _ = @capability.AgentCapabilitySet::from_json({ "capabilities": [1.0] })
    panic()
  } catch {
    @wire.BadType(_, _) => got = true
    _ => panic()
  }
  assert_true(got)
}
