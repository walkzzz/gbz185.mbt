// GB/Z 185.2 身份状态谓词黑盒测试（is_active 的四状态真值表）

///|
test "identity_status is_active is true only for Active" {
  assert_true(@identity.IdentityStatus::to_wire(@identity.Active).length() > 0)
  assert_true(@identity.Active.is_active())
  assert_false(@identity.NoIdentity.is_active())
  assert_false(@identity.Locked.is_active())
  assert_false(@identity.Revoked.is_active())
}

///|
test "agent identity is_active projects its status" {
  let active : @identity.AgentIdentity = {
    aic: "1.2.156.185.2.1.1",
    identity_status: @identity.Active,
    cai_ref: None,
    registered_at: Some(10L),
  }
  let locked = { ..active, identity_status: @identity.Locked, }
  assert_true(active.is_active())
  assert_false(locked.is_active())
}
