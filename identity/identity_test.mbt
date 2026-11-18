// GB/Z 185.2 身份管理黑盒测试（AIC 编码结构 / wire 往返 / 状态 wire 映射）

///|
test "aic_validate accepts dotted numeric OIDs with >=2 segments" {
  assert_true(@identity.aic_validate("1.2.156.185.2.1.42"))
  assert_true(@identity.aic_validate("1.2"))
  assert_false(@identity.aic_validate("1"))
  assert_false(@identity.aic_validate(""))
  assert_false(@identity.aic_validate("1.2..3"))
  assert_false(@identity.aic_validate("1.2.x.3"))
  assert_false(@identity.aic_validate("1.2.3."))
  assert_true(@identity.aic_has_stack_prefix("1.2.156.185.2.1.42"))
  assert_false(@identity.aic_has_stack_prefix("1.2.999.1"))
}

///|
test "identity wire roundtrip preserves all fields" {
  let id = @identity.AgentIdentity::{
    aic: "1.2.156.185.2.1.42",
    identity_status: @identity.Active,
    cai_ref: Some("caicert-001"),
    registered_at: Some(100L),
  }
  let back = @identity.AgentIdentity::from_json(id.to_json()) catch {
    _ => panic()
  }
  assert_eq(back, id)
}

///|
test "identity wire roundtrip with None optionals" {
  let id = @identity.AgentIdentity::{
    aic: "",
    identity_status: @identity.NoIdentity,
    cai_ref: None,
    registered_at: None,
  }
  let back = @identity.AgentIdentity::from_json(id.to_json()) catch {
    _ => panic()
  }
  assert_eq(back, id)
}

///|
test "identity_status wire mapping includes unknown rejection" {
  assert_eq(@identity.IdentityStatus::to_wire(@identity.Active), "active")
  assert_true(@identity.IdentityStatus::from_wire("banned") is None)
  assert_true(
    @identity.IdentityStatus::from_wire("locked") is Some(@identity.Locked),
  )
}
