// registry 错误分型测试（GB/Z 185.3 ATR 七变体的 code/message/to_json/Show 全覆盖）

///|
test "registry error variants expose unified contract" {
  let errors : Array[@registry.RegistryError] = [
    @registry.UnknownAgent("urn:agent:a"),
    @registry.AlreadyRegistered("urn:agent:a"),
    @registry.NotActive("urn:agent:a"),
    @registry.CredentialDenied("urn:agent:a"),
    @registry.InvalidAic("1.2"),
    @registry.CapacityExceeded(1024),
    @registry.CredentialExpired("urn:agent:a"),
  ]
  let codes : Array[String] = []
  for e in errors {
    codes.push(e.code())
    assert_eq(e.part(), "gbz185.3")
    assert_true(e.message().length() > 0)
    assert_true(e.to_string().length() > 0)
    assert_true(e.to_json().stringify().contains("gbz185.3"))
  }
  assert_eq(codes, [
    "ATR-2001", "ATR-2002", "ATR-2003", "ATR-2004", "ATR-2005", "ATR-2006", "ATR-2007",
  ])
}

///|
test "registry error json carries kind per variant" {
  let cases : Array[(@registry.RegistryError, String)] = [
    (@registry.UnknownAgent("u"), "unknown-agent"),
    (@registry.AlreadyRegistered("u"), "already-registered"),
    (@registry.NotActive("u"), "not-active"),
    (@registry.CredentialDenied("u"), "credential-denied"),
    (@registry.InvalidAic("a"), "invalid-aic"),
    (@registry.CapacityExceeded(3), "capacity-exceeded"),
    (@registry.CredentialExpired("u"), "credential-expired"),
  ]
  for pair in cases {
    let err = pair.0
    let kind = pair.1
    assert_true(err.to_json().stringify().contains(kind))
  }
}

///|
test "registry event variants are distinct" {
  let events : Array[@registry.RegistryEvent] = [
    @registry.Registered("urn:agent:a", "1.2.3"),
    @registry.Locked("urn:agent:a"),
    @registry.Revoked("urn:agent:a"),
    @registry.Unregistered("urn:agent:a"),
    @registry.CredentialRenewed("urn:agent:a"),
    @registry.AuthenticationDenied("urn:agent:a"),
  ]
  assert_eq(events.length(), 6)
  assert_false(events[0] == events[1])
}
