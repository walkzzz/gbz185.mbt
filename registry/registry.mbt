// GB/Z 185.3 身份管理 ATR（Agent Token Registry）：注册/凭证/鉴权/生命周期/注销
// 生产级内存实现（sans-I/O）：凭证生命周期（有效期+续期）、容量防护、事件审计、
// 能力检索、last_seen 活跃追踪；正式 ACPs 注册服务为外部系统（互联模式经 transport-async 接入）。
// Credential verification is injected via CAIVerifier (zero mooncakes deps in the core; skills-security binds mooncred).

///|
/// CAI 凭证校验注入点（GB/Z 185.3 鉴权）
/// CAI credential verification injection point (pub(open): bound by skills-security with mooncred).
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
  CapacityExceeded(Int32)
  CredentialExpired(String)
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
    CapacityExceeded(n) =>
      logger.write_string("registry/capacity-exceeded: \{n}")
    CredentialExpired(urn) =>
      logger.write_string("registry/credential-expired: \{urn}")
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
    CapacityExceeded(n) =>
      { "part": "gbz185.3", "kind": "capacity-exceeded", "count": n }
    CredentialExpired(urn) =>
      { "part": "gbz185.3", "kind": "credential-expired", "urn": urn }
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
    CapacityExceeded(_) => "ATR-2006"
    CredentialExpired(_) => "ATR-2007"
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
    CapacityExceeded(n) => "registry capacity exceeded (\{n} entries)"
    CredentialExpired(urn) => "credential expired \{urn}"
  }
}

///|
pub extend RegistryError with Show::{to_string, output}

///|
pub extend RegistryError with @moonbitlang/core/json.ToJson::{to_json}

///|
pub extend RegistryError with @wire.ProtocolError::{part, code, message}

///|
/// ATR 审计事件（GB/Z 185.3 生命周期动作的机器可查记录）
#derive(Eq, Debug)
pub(all) enum RegistryEvent {
  Registered(String, String)
  Locked(String)
  Revoked(String)
  Unregistered(String)
  CredentialRenewed(String)
  AuthenticationDenied(String)
}

///|
pub extend RegistryEvent with Eq::{equal, not_equal}

///|
pub extend RegistryEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 注册表条目（内部）：节点快照 + 生命周期状态 + 凭证生命周期 + 活跃追踪
priv struct Entry {
  node : @discovery.AgentNode
  mut state : @identity.IdentityStatus
  cai_ref : String?
  mut expires_at : Int64?
  registered_at : Int64
  mut last_seen : Int64
}

///|
/// ATR 内存注册表：urn → 条目 + 审计事件 + 容量防护（字段私有，经方法访问）
pub struct TokenRegistry {
  priv entries : Map[String, Entry]
  priv events : Array[RegistryEvent]
  priv mut seq : Int32
  priv max_entries : Int32
}

///|
/// 构造：max_entries 容量防护（默认 1024，防资源耗尽）
pub fn TokenRegistry::new(max_entries~ : Int32 = 1024) -> TokenRegistry {
  { entries: Map([]), events: [], seq: 0, max_entries, }
}

///|
pub fn TokenRegistry::count(self : TokenRegistry) -> Int32 {
  self.entries.length()
}

///|
pub fn TokenRegistry::capacity(self : TokenRegistry) -> Int32 {
  self.max_entries
}

///|
pub fn TokenRegistry::lookup(
  self : TokenRegistry,
  urn : String,
) -> @discovery.AgentNode? {
  match self.entries.get(urn) {
    Some(e) => Some(e.node)
    None => None
  }
}

///|
pub fn TokenRegistry::state(
  self : TokenRegistry,
  urn : String,
) -> @identity.IdentityStatus? {
  match self.entries.get(urn) {
    Some(e) => Some(e.state)
    None => None
  }
}

///|
/// 运维观测：注册时间查询（GB/Z 185.3 生命周期；OMD 巡检用）
pub fn TokenRegistry::registered_at_of(
  self : TokenRegistry,
  urn : String,
) -> Int64? {
  match self.entries.get(urn) {
    Some(e) => Some(e.registered_at)
    None => None
  }
}

///|
/// 运维观测：最后活跃时间查询（authenticate/renew 成功时更新）
pub fn TokenRegistry::last_seen_of(
  self : TokenRegistry,
  urn : String,
) -> Int64? {
  match self.entries.get(urn) {
    Some(e) => Some(e.last_seen)
    None => None
  }
}

///|
pub fn TokenRegistry::aic_of(self : TokenRegistry, urn : String) -> String? {
  match self.entries.get(urn) {
    Some(e) => Some(e.node.identity.aic)
    None => None
  }
}

///|
/// 审计事件快照（GB/Z 185.3 生命周期动作记录；clear_events 后重置）
pub fn TokenRegistry::events(self : TokenRegistry) -> Array[RegistryEvent] {
  let out : Array[RegistryEvent] = []
  for e in self.events {
    out.push(e)
  }
  out
}

///|
pub fn TokenRegistry::clear_events(self : TokenRegistry) -> Unit {
  self.events.clear()
}

///|
/// 活跃智能体目录（仅 state == Active 的节点快照）
pub fn TokenRegistry::list_active(
  self : TokenRegistry,
) -> Array[@discovery.AgentNode] {
  let out : Array[@discovery.AgentNode] = []
  for _urn, e in self.entries {
    if e.state is @identity.Active {
      out.push(e.node)
    }
  }
  out
}

///|
/// 按能力检索（GB/Z 185.4 ACS 匹配联动；仅 Active 智能体）
pub fn TokenRegistry::find_by_capability(
  self : TokenRegistry,
  caps : ArrayView[String],
) -> Array[@discovery.AgentNode] {
  let out : Array[@discovery.AgentNode] = []
  for _urn, e in self.entries {
    if e.state is @identity.Active && e.node.acs.covers(caps) {
      out.push(e.node)
    }
  }
  out
}

///|
/// 注册（GB/Z 185.3）：分配 AIC（clamp 序号防护，verify 包已证明）→ 状态 Active。
/// node.identity.cai_ref 存在时先过 CAIVerifier。
pub fn TokenRegistry::register(
  self : TokenRegistry,
  node : @discovery.AgentNode,
  verifier : &CAIVerifier,
) -> String raise RegistryError {
  self.register_with_validity(node, verifier, now=0L, validity=0L)
}

///|
/// 带有效期注册：expires_at = now + validity（validity <= 0 表示永不过期）
pub fn TokenRegistry::register_with_validity(
  self : TokenRegistry,
  node : @discovery.AgentNode,
  verifier : &CAIVerifier,
  now~ : Int64 = 0L,
  validity~ : Int64 = 0L,
) -> String raise RegistryError {
  if self.entries.get(node.urn) is Some(_) {
    raise AlreadyRegistered(node.urn)
  }
  if self.entries.length() >= self.max_entries {
    raise CapacityExceeded(self.entries.length())
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
  let expires = if validity > 0L { Some(now + validity) } else { None }
  let registered_node = {
    ..node,
    identity: {
      ..node.identity,
      aic,
      identity_status: @identity.Active,
      registered_at: Some(now),
    },
  }
  self.entries[node.urn] = {
    node: registered_node,
    state: @identity.Active,
    cai_ref: node.identity.cai_ref,
    expires_at: expires,
    registered_at: now,
    last_seen: now,
  }
  self.events.push(Registered(node.urn, aic))
  aic
}

///|
pub fn TokenRegistry::lock(
  self : TokenRegistry,
  urn : String,
) -> Unit raise RegistryError {
  match self.entries.get(urn) {
    Some(e) =>
      if e.state is @identity.Active {
        e.state = @identity.Locked
        self.events.push(Locked(urn))
      } else {
        raise NotActive(urn)
      }
    None => raise UnknownAgent(urn)
  }
}

///|
pub fn TokenRegistry::revoke(
  self : TokenRegistry,
  urn : String,
) -> Unit raise RegistryError {
  match self.entries.get(urn) {
    Some(e) => {
      e.state = @identity.Revoked
      self.events.push(Revoked(urn))
    }
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
  self.events.push(Unregistered(urn))
}

///|
/// 凭证续期（GB/Z 185.3 生命周期）：expires_at = now + validity（须 Active 且凭证未过期）
pub fn TokenRegistry::renew(
  self : TokenRegistry,
  urn : String,
  verifier : &CAIVerifier,
  now~ : Int64 = 0L,
  validity~ : Int64 = 90L * 24L * 3600L,
) -> Int64 raise RegistryError {
  match self.entries.get(urn) {
    Some(e) =>
      if e.state is @identity.Active {
        match e.cai_ref {
          Some(cai) =>
            if !verifier.verify(cai) {
              self.events.push(AuthenticationDenied(urn))
              raise CredentialDenied(urn)
            }
          None => ()
        }
        match e.expires_at {
          Some(exp) =>
            if now > exp {
              self.events.push(AuthenticationDenied(urn))
              raise CredentialExpired(urn)
            }
          None => ()
        }
        let new_exp = now + validity
        e.expires_at = Some(new_exp)
        e.last_seen = now
        self.events.push(CredentialRenewed(urn))
        new_exp
      } else {
        raise NotActive(urn)
      }
    None => raise UnknownAgent(urn)
  }
}

///|
/// 鉴权（GB/Z 185.3）：agent 须 Active、凭证未过期（now 参数 sans-I/O 注入）、CAI 校验通过；
/// 成功时更新 last_seen。denied 记入审计事件。
pub fn TokenRegistry::authenticate(
  self : TokenRegistry,
  urn : String,
  cai_ref : String,
  verifier : &CAIVerifier,
  now~ : Int64 = 0L,
) -> Bool raise RegistryError {
  match self.entries.get(urn) {
    Some(e) =>
      if e.state is @identity.Active {
        match e.expires_at {
          Some(exp) =>
            if now > exp {
              self.events.push(AuthenticationDenied(urn))
              return false
            }
          None => ()
        }
        let verdict = verifier.verify(cai_ref)
        if verdict {
          e.last_seen = now
        } else {
          self.events.push(AuthenticationDenied(urn))
        }
        verdict
      } else {
        raise NotActive(urn)
      }
    None => raise UnknownAgent(urn)
  }
}
