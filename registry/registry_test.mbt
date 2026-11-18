// GB/Z 185.3 ATR 黑盒测试（注册/生命周期/注销/鉴权/CAIVerifier 注入）

///|
struct AcceptAll {}

///|
impl @registry.CAIVerifier for AcceptAll with fn verify(_self, _cai) {
  true
}

///|
struct DenyAll {}

///|
impl @registry.CAIVerifier for DenyAll with fn verify(_self, _cai) {
  false
}

///|
fn sample_node(urn : String) -> @discovery.AgentNode {
  @discovery.AgentNode::from_frontmatter(
    urn,
    urn,
    @identity.NoIdentity,
    true,
    ["skill:demo"],
    [],
    [],
  )
}

///|
test "register assigns valid AIC and activates lifecycle (GB/Z 185.3)" {
  let reg = @registry.TokenRegistry::new()
  let aic = @registry.TokenRegistry::register(reg, sample_node("urn:agent:a"), AcceptAll::{
  }) catch {
    _ => panic()
  }
  assert_true(@identity.aic_validate(aic))
  assert_eq(
    @registry.TokenRegistry::state(reg, "urn:agent:a"),
    Some(@identity.Active),
  )
  assert_eq(@registry.TokenRegistry::count(reg), 1)
}

///|
test "duplicate register rejected" {
  let reg = @registry.TokenRegistry::new()
  let _ = @registry.TokenRegistry::register(reg, sample_node("urn:agent:a"), AcceptAll::{
  }) catch {
    _ => panic()
  }
  let mut got = false
  try {
    let _ = @registry.TokenRegistry::register(reg, sample_node("urn:agent:a"), AcceptAll::{
    })
    panic()
  } catch {
    @registry.AlreadyRegistered(_) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "lifecycle lock then authenticate raises not-active" {
  let reg = @registry.TokenRegistry::new()
  let _ = @registry.TokenRegistry::register(reg, sample_node("urn:agent:a"), AcceptAll::{
  }) catch {
    _ => panic()
  }
  @registry.TokenRegistry::lock(reg, "urn:agent:a") catch {
    _ => panic()
  }
  assert_eq(
    @registry.TokenRegistry::state(reg, "urn:agent:a"),
    Some(@identity.Locked),
  )
  let mut got = false
  try {
    let _ = @registry.TokenRegistry::authenticate(
      reg,
      "urn:agent:a",
      "caicert-001",
      AcceptAll::{ },
    )
    panic()
  } catch {
    @registry.NotActive(_) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "authenticate reflects injected credential verdict" {
  let reg = @registry.TokenRegistry::new()
  let node = sample_node("urn:agent:a")
  let node_with_cai = {
    ..node,
    identity: { ..node.identity, cai_ref: Some("caicert-001"), },
  }
  let _ = @registry.TokenRegistry::register(reg, node_with_cai, AcceptAll::{ }) catch {
    _ => panic()
  }
  assert_true(
    @registry.TokenRegistry::authenticate(reg, "urn:agent:a", "caicert-001", AcceptAll::{
    }) catch {
      _ => panic()
    },
  )
  assert_false(
    @registry.TokenRegistry::authenticate(reg, "urn:agent:a", "caicert-001", DenyAll::{
    }) catch {
      _ => panic()
    },
  )
}

///|
test "revoke then unregister then unknown" {
  let reg = @registry.TokenRegistry::new()
  let _ = @registry.TokenRegistry::register(reg, sample_node("urn:agent:a"), AcceptAll::{
  }) catch {
    _ => panic()
  }
  @registry.TokenRegistry::revoke(reg, "urn:agent:a") catch {
    _ => panic()
  }
  assert_eq(
    @registry.TokenRegistry::state(reg, "urn:agent:a"),
    Some(@identity.Revoked),
  )
  @registry.TokenRegistry::unregister(reg, "urn:agent:a") catch {
    _ => panic()
  }
  assert_true(@registry.TokenRegistry::lookup(reg, "urn:agent:a") is None)
  let mut got = false
  try {
    @registry.TokenRegistry::unregister(reg, "urn:agent:a")
    panic()
  } catch {
    @registry.UnknownAgent(_) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "credential denied at register via CAIVerifier injection" {
  let reg = @registry.TokenRegistry::new()
  let node = sample_node("urn:agent:a")
  let node_with_cai = {
    ..node,
    identity: { ..node.identity, cai_ref: Some("caicert-001"), },
  }
  let mut got = false
  try {
    let _ = @registry.TokenRegistry::register(reg, node_with_cai, DenyAll::{ })
    panic()
  } catch {
    @registry.CredentialDenied(_) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "capacity guard rejects registration beyond max_entries" {
  let reg = @registry.TokenRegistry::new(max_entries=2)
  let _ = @registry.TokenRegistry::register(reg, sample_node("urn:agent:a"), AcceptAll::{
  }) catch {
    _ => panic()
  }
  let _ = @registry.TokenRegistry::register(reg, sample_node("urn:agent:b"), AcceptAll::{
  }) catch {
    _ => panic()
  }
  let mut got = false
  try {
    let _ = @registry.TokenRegistry::register(reg, sample_node("urn:agent:c"), AcceptAll::{
    })
    panic()
  } catch {
    @registry.CapacityExceeded(2) => got = true
    _ => panic()
  }
  assert_true(got)
  assert_eq(@registry.TokenRegistry::capacity(reg), 2)
}

///|
test "credential lifecycle: validity window and renewal (GB/Z 185.3)" {
  let reg = @registry.TokenRegistry::new()
  let node = sample_node("urn:agent:a")
  let node_with_cai = {
    ..node,
    identity: { ..node.identity, cai_ref: Some("caicert-001"), },
  }
  let aic = @registry.TokenRegistry::register_with_validity(
    reg,
    node_with_cai,
    AcceptAll::{ },
    now=1000L,
    validity=100L,
  ) catch {
    _ => panic()
  }
  assert_true(@identity.aic_validate(aic))
  assert_true(
    @registry.TokenRegistry::authenticate(
      reg,
      "urn:agent:a",
      "caicert-001",
      AcceptAll::{ },
      now=1050L,
    ) catch {
      _ => panic()
    },
  )
  let new_exp = @registry.TokenRegistry::renew(
    reg,
    "urn:agent:a",
    AcceptAll::{ },
    now=1050L,
    validity=200L,
  ) catch {
    _ => panic()
  }
  assert_eq(new_exp, 1250L)
  assert_true(
    @registry.TokenRegistry::authenticate(
      reg,
      "urn:agent:a",
      "caicert-001",
      AcceptAll::{ },
      now=1200L,
    ) catch {
      _ => panic()
    },
  )
  assert_false(
    @registry.TokenRegistry::authenticate(
      reg,
      "urn:agent:a",
      "caicert-001",
      AcceptAll::{ },
      now=1300L,
    ) catch {
      _ => panic()
    },
  )
  let mut exp_got = false
  try {
    let _ = @registry.TokenRegistry::renew(
      reg,
      "urn:agent:a",
      AcceptAll::{ },
      now=1300L,
      validity=100L,
    )
    panic()
  } catch {
    @registry.CredentialExpired(_) => exp_got = true
    _ => panic()
  }
  assert_true(exp_got)
}

///|
test "find_by_capability and list_active (GB/Z 185.4 ACS 联动)" {
  let reg = @registry.TokenRegistry::new()
  let _ = @registry.TokenRegistry::register(reg, sample_node("urn:agent:a"), AcceptAll::{
  }) catch {
    _ => panic()
  }
  let b = @discovery.AgentNode::from_frontmatter(
    "urn:agent:b",
    "B",
    @identity.Active,
    true,
    ["tool:net_fetch"],
    [],
    [],
  )
  let _ = @registry.TokenRegistry::register(reg, b, AcceptAll::{ }) catch {
    _ => panic()
  }
  let found = @registry.TokenRegistry::find_by_capability(
    reg,
    ["skill:demo"][:],
  )
  assert_eq(found.length(), 1)
  assert_eq(found[0].urn, "urn:agent:a")
  @registry.TokenRegistry::lock(reg, "urn:agent:a") catch {
    _ => panic()
  }
  assert_eq(
    @registry.TokenRegistry::find_by_capability(reg, ["skill:demo"][:]).length(),
    0,
  )
  assert_eq(@registry.TokenRegistry::list_active(reg).length(), 1)
}

///|
test "aic_of and ops observations (GB/Z 185.3 运维查询)" {
  let reg = @registry.TokenRegistry::new()
  let aic = @registry.TokenRegistry::register(reg, sample_node("urn:agent:a"), AcceptAll::{
  }) catch {
    _ => panic()
  }
  assert_eq(@registry.TokenRegistry::aic_of(reg, "urn:agent:a"), Some(aic))
  assert_true(
    @registry.TokenRegistry::registered_at_of(reg, "urn:agent:a") is Some(0L),
  )
  let _ = @registry.TokenRegistry::authenticate(
    reg,
    "urn:agent:a",
    "caicert-x",
    AcceptAll::{ },
    now=500L,
  ) catch {
    _ => panic()
  }
  assert_eq(
    @registry.TokenRegistry::last_seen_of(reg, "urn:agent:a"),
    Some(500L),
  )
}

///|
test "audit events record full lifecycle (GB/Z 185.3)" {
  let reg = @registry.TokenRegistry::new()
  let _ = @registry.TokenRegistry::register(reg, sample_node("urn:agent:a"), AcceptAll::{
  }) catch {
    _ => panic()
  }
  @registry.TokenRegistry::lock(reg, "urn:agent:a") catch {
    _ => panic()
  }
  @registry.TokenRegistry::revoke(reg, "urn:agent:a") catch {
    _ => panic()
  }
  @registry.TokenRegistry::unregister(reg, "urn:agent:a") catch {
    _ => panic()
  }
  let events = @registry.TokenRegistry::events(reg)
  assert_eq(events.length(), 4)
  assert_true(events[0] is @registry.Registered(_, _))
  assert_true(events[1] is @registry.Locked(_))
  assert_true(events[2] is @registry.Revoked(_))
  assert_true(events[3] is @registry.Unregistered(_))
  @registry.TokenRegistry::clear_events(reg)
  assert_eq(@registry.TokenRegistry::events(reg).length(), 0)
}
