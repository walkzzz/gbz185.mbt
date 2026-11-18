// GB/Z 185.3 身份管理 ATR（Agent Token Registry）：注册/凭证/鉴权/生命周期/注销
// 内存实现（sans-I/O）；正式 ACPs 注册服务为外部系统（互联模式经 transport-async 接入）。
// 凭证校验为 CAIVerifier trait 注入点（核心零 mooncakes 依赖——skills-security 提供基于 mooncred 的绑定）。

///|
/// CAI 凭证校验注入点（GB/Z 185.3 鉴权）
/// pub(open)：允许黑盒测试与 skills-security 跨包实现
pub(open) trait CAIVerifier {
  fn verify(Self, String) -> Bool
}

///|
pub(all) suberror RegistryError {
  UnknownAgent(String)
  AlreadyRegistered(String)
  NotActive(String)
  CredentialDenied(String)
  InvalidAic(String)
}

///|
pub impl Show for RegistryError with fn output(self, logger) -> Unit {
  match self {
    UnknownAgent(urn) => logger.write_string("registry/unknown-agent: \{urn}")
    AlreadyRegistered(urn) =>
      logger.write_string("registry/already-registered: \{urn}")
    NotActive(urn) => logger.write_string("registry/not-active: \{urn}")
    CredentialDenied(urn) =>
      logger.write_string("registry/credential-denied: \{urn}")
    InvalidAic(aic) => logger.write_string("registry/invalid-aic: \{aic}")
  }
}

///|
pub impl ToJson for RegistryError with fn to_json(self) -> Json {
  match self {
    UnknownAgent(urn) =>
      { "part": "gbz185.3", "kind": "unknown-agent", "urn": urn }
    AlreadyRegistered(urn) =>
      { "part": "gbz185.3", "kind": "already-registered", "urn": urn }
    NotActive(urn) => { "part": "gbz185.3", "kind": "not-active", "urn": urn }
    CredentialDenied(urn) =>
      { "part": "gbz185.3", "kind": "credential-denied", "urn": urn }
    InvalidAic(aic) => { "part": "gbz185.3", "kind": "invalid-aic", "aic": aic }
  }
}

///|
pub impl @wire.ProtocolError for RegistryError with fn part(_self) -> String {
  "gbz185.3"
}

///|
pub impl @wire.ProtocolError for RegistryError with fn code(self) -> String {
  match self {
    UnknownAgent(_) => "ATR-2001"
    AlreadyRegistered(_) => "ATR-2002"
    NotActive(_) => "ATR-2003"
    CredentialDenied(_) => "ATR-2004"
    InvalidAic(_) => "ATR-2005"
  }
}

///|
pub impl @wire.ProtocolError for RegistryError with fn message(self) -> String {
  match self {
    UnknownAgent(urn) => "unknown agent \{urn}"
    AlreadyRegistered(urn) => "agent already registered \{urn}"
    NotActive(urn) => "agent not active \{urn}"
    CredentialDenied(urn) => "credential denied \{urn}"
    InvalidAic(aic) => "invalid AIC \{aic}"
  }
}

///|
/// ATR 内存注册表：urn → 节点快照 + 生命周期状态（生命周期与节点快照分离管理）
pub struct TokenRegistry {
  entries : Map[String, @discovery.AgentNode]
  lifecycle : Map[String, @identity.IdentityStatus]
  mut seq : Int32
}

///|
pub fn TokenRegistry::new() -> TokenRegistry {
  { entries: Map([]), lifecycle: Map([]), seq: 0, }
}

///|
pub fn TokenRegistry::count(self : TokenRegistry) -> Int32 {
  self.entries.length()
}

///|
pub fn TokenRegistry::lookup(
  self : TokenRegistry,
  urn : String,
) -> @discovery.AgentNode? {
  self.entries.get(urn)
}

///|
pub fn TokenRegistry::state(
  self : TokenRegistry,
  urn : String,
) -> @identity.IdentityStatus? {
  self.lifecycle.get(urn)
}

///|
/// 注册（GB/Z 185.3）：分配 AIC（clamp 序号防护，verify 包已证明）→ 状态 Active。
/// node.identity.cai_ref 存在时先过 CAIVerifier。
pub fn TokenRegistry::register(
  self : TokenRegistry,
  node : @discovery.AgentNode,
  verifier : &CAIVerifier,
) -> String raise RegistryError {
  if self.entries.get(node.urn) is Some(_) {
    raise AlreadyRegistered(node.urn)
  }
  match node.identity.cai_ref {
    Some(cai) => if !verifier.verify(cai) { raise CredentialDenied(node.urn) }
    None => ()
  }
  self.seq += 1
  let guarded = @verify.clamp_i64(self.seq.to_int64(), 1L, 999999L)
  let aic = "1.2.156.185.2.1.\{guarded}"
  if !@identity.aic_validate(aic) {
    raise InvalidAic(aic)
  }
  let registered_node = {
    ..node,
    identity: {
      ..node.identity,
      aic,
      identity_status: @identity.Active,
      registered_at: Some(0L),
    },
  }
  self.entries[node.urn] = registered_node
  self.lifecycle[node.urn] = @identity.Active
  aic
}

///|
pub fn TokenRegistry::lock(
  self : TokenRegistry,
  urn : String,
) -> Unit raise RegistryError {
  match self.lifecycle.get(urn) {
    Some(@identity.Active) => self.lifecycle[urn] = @identity.Locked
    Some(_) => raise NotActive(urn)
    None => raise UnknownAgent(urn)
  }
}

///|
pub fn TokenRegistry::revoke(
  self : TokenRegistry,
  urn : String,
) -> Unit raise RegistryError {
  match self.lifecycle.get(urn) {
    Some(_) => self.lifecycle[urn] = @identity.Revoked
    None => raise UnknownAgent(urn)
  }
}

///|
pub fn TokenRegistry::unregister(
  self : TokenRegistry,
  urn : String,
) -> Unit raise RegistryError {
  if self.entries.get(urn) is None {
    raise UnknownAgent(urn)
  }
  let _ = self.entries.remove(urn)
  let _ = self.lifecycle.remove(urn)
}

///|
/// 鉴权（GB/Z 185.3）：agent 须 Active；CAI 凭证校验经注入的 verifier（false = 凭证不通过）
pub fn TokenRegistry::authenticate(
  self : TokenRegistry,
  urn : String,
  cai_ref : String,
  verifier : &CAIVerifier,
) -> Bool raise RegistryError {
  match self.lifecycle.get(urn) {
    Some(@identity.Active) => verifier.verify(cai_ref)
    Some(_) => raise NotActive(urn)
    None => raise UnknownAgent(urn)
  }
}

///|
pub extend RegistryError with Show::{to_string, output}

///|
pub extend RegistryError with @moonbitlang/core/json.ToJson::{to_json}

///|
pub extend RegistryError with @wire.ProtocolError::{part, code, message}
