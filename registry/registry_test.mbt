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
