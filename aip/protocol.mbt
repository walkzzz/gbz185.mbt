// GB/Z 185.6 AIP 协议核心状态机：注册（185.3 客户端面）/发现（185.5 客户端面）/能力交换/交互
// 本地模式 sans-I/O：无时钟/无网络，时间戳与传输由调用方/transport-async 注入。
// InterconnectProtocol trait 于 W12 集成期引入（本包 .mbti 即 F17 冻结契约）。
// GB/Z 185.6 AIP core protocol state machine: register (185.3 client side), discover (185.5 client side), capability exchange, interaction
// — local-mode sans-I/O (no clock/network); timestamps and transport are injected by callers or transport-async; the InterconnectProtocol trait lands in W12 with this package's .mbti as the frozen F17 contract.

///|
#derive(Debug)
pub struct AipProtocol {
  mut self_node : @discovery.AgentNode
  peers : Map[String, @discovery.AgentNode]
  mut outbox_seq : Int64
  inbox_seq : Map[String, Int64]
}

///|
pub extend AipProtocol with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn AipProtocol::new(self_node : @discovery.AgentNode) -> AipProtocol {
  { self_node, peers: Map([]), outbox_seq: 0L, inbox_seq: Map([]), }
}

///|
pub fn AipProtocol::self_urn(self : AipProtocol) -> String {
  self.self_node.urn
}

///|
pub fn AipProtocol::identity(self : AipProtocol) -> @identity.AgentIdentity {
  self.self_node.identity
}

///|
pub fn AipProtocol::peer_count(self : AipProtocol) -> Int32 {
  self.peers.length()
}

///|
pub fn AipProtocol::peer(
  self : AipProtocol,
  urn : String,
) -> @discovery.AgentNode? {
  self.peers.get(urn)
}

///|
/// 已发现对端 URN 清单（shortlex 确定性顺序：MoonBit String Compare 先长度后逐字符；
/// 本栈 URN 等长时即为字典序）
/// Discovered peer URN list (shortlex deterministic order; equal-length stack URNs are lexicographic).
pub fn AipProtocol::peer_urns(self : AipProtocol) -> Array[String] {
  let out : Array[String] = []
  for urn, _node in self.peers {
    out.push(urn)
  }
  out.sort()
  out
}

///|
/// 本端是否已注册（身份 Active）——dispatch 的前置条件
/// Whether this endpoint is registered (identity Active) — the precondition of dispatch.
pub fn AipProtocol::is_registered(self : AipProtocol) -> Bool {
  self.self_node.identity.identity_status.is_active()
}

///|
/// 当前发送序号（最近一次 dispatch 分配；未发送为 0）
/// Current outbox sequence (last assigned by dispatch; 0 before the first send).
pub fn AipProtocol::outbox_seq(self : AipProtocol) -> Int64 {
  self.outbox_seq
}

///|
/// 某发送者的防重放水位（未收到过其信封为 0）
/// Replay watermark for a sender (0 if no envelope has been received from it).
pub fn AipProtocol::inbox_watermark(
  self : AipProtocol,
  sender_urn : String,
) -> Int64 {
  match self.inbox_seq.get(sender_urn) {
    Some(s) => s
    None => 0L
  }
}

///|
pub fn AipProtocol::invariant(self : AipProtocol) -> Bool {
  self.outbox_seq >= 0L &&
  self.self_node.urn.has_prefix(@wire.agent_urn_prefix())
}

/// GB/Z 185.3 ATR 客户端面：构造可信注册请求（携带 AIC/ACS；本地模式 aic 待分配）
/// GB/Z 185.3 ATR client side: build a trustworthy register request (carries AIC/ACS; aic pending in local mode)

///|
pub fn AipProtocol::register_request(self : AipProtocol) -> RegisterRequest {
  { node: self.self_node, }
}

///|
pub fn AipProtocol::handle_register_response(
  self : AipProtocol,
  resp : RegisterResponse,
) -> Unit raise AipError {
  guard resp.accepted else {
    let why = match resp.reason {
      Some(r) => r
      None => "no reason given"
    }
    raise Registry("registration rejected: \{why}")
  }
  let identity = self.self_node.identity
  let aic = match resp.aic {
    Some(a) => a
    None => identity.aic
  }
  let registered_at = match identity.registered_at {
    Some(t) => Some(t)
    None => Some(0L)
  }
  self.self_node = {
    ..self.self_node,
    identity: {
      ..identity,
      aic,
      identity_status: @identity.Active,
      registered_at,
    },
  }
}

/// GB/Z 185.5 ADP 客户端面：构造发现请求
/// GB/Z 185.5 ADP client side: build a discover request

///|
pub fn AipProtocol::discover_request(self : AipProtocol) -> DiscoverRequest {
  { requester_urn: self.self_node.urn, filter_capabilities: [], }
}

///|
pub fn AipProtocol::handle_discover_response(
  self : AipProtocol,
  resp : DiscoverResponse,
) -> Int32 {
  let mut added = 0
  for node in resp.nodes {
    if node.urn == self.self_node.urn {
      continue
    }
    if !node.discoverable {
      continue
    }
    match self.peers.get(node.urn) {
      Some(existing) =>
        if existing != node {
          self.peers[node.urn] = node
          added += 1
        }
      None => {
        self.peers[node.urn] = node
        added += 1
      }
    }
  }
  added
}

/// GB/Z 185.4 ACS：构造能力交换请求（仅限已知对端）
/// GB/Z 185.4 ACS: build a capability exchange request (known peers only)

///|
pub fn AipProtocol::capability_request(
  self : AipProtocol,
  target_urn : String,
) -> CapabilityRequest raise AipError {
  guard self.peers.get(target_urn) is Some(_) else {
    raise Capability("unknown peer \{target_urn}")
  }
  { requester_urn: self.self_node.urn, target_urn, }
}

///|
pub fn AipProtocol::capability_of(
  self : AipProtocol,
  peer_urn : String,
) -> @capability.AgentCapabilitySet raise AipError {
  guard self.peers.get(peer_urn) is Some(node) else {
    raise Capability("unknown peer \{peer_urn}")
  }
  node.acs
}

/// GB/Z 185.6 AIP：封装信封并分配单调递增序号（群组 URN 直通，单播须已发现）
/// GB/Z 185.6 AIP: wrap the envelope and assign a monotonically increasing seq (group URNs pass through; unicast requires a discovered peer)

///|
pub fn AipProtocol::dispatch(
  self : AipProtocol,
  kind : MessageKind,
  recipient_urn : String,
  payload : Json,
) -> AipEnvelope raise AipError {
  guard self.is_registered() else {
    raise Registry("dispatch requires active identity (register first)")
  }
  let is_group = recipient_urn.has_prefix(@wire.group_urn_prefix())
  if !(is_group || self.peers.get(recipient_urn) is Some(_)) {
    raise Dispatch("unknown unicast recipient \{recipient_urn}")
  }
  // 序号推进使用形式化证明函数（verify/next_seq：严格递增性质由 Z3 证明）
  self.outbox_seq = @verify.next_seq(self.outbox_seq)
  {
    envelope_version: envelope_version(),
    sender_urn: self.self_node.urn,
    recipient_urn,
    seq: self.outbox_seq,
    timestamp: 0L,
    kind,
    payload,
  }
}

/// GB/Z 185.6 AIP：接收侧校验（版本/收件人/自环/单调序号防重放）
/// GB/Z 185.6 AIP: receive-side validation (version/recipient/self-loop/monotonic seq anti-replay)

///|
pub fn AipProtocol::receive(
  self : AipProtocol,
  env : AipEnvelope,
) -> AipMessage raise AipError {
  guard env.envelope_version == envelope_version() else {
    raise Envelope("unsupported envelope version \{env.envelope_version}")
  }
  guard env.recipient_urn == self.self_node.urn else {
    raise Envelope("envelope not addressed to self")
  }
  guard env.sender_urn != self.self_node.urn else {
    raise Envelope("self-addressed envelope")
  }
  let last = match self.inbox_seq.get(env.sender_urn) {
    Some(s) => s
    None => 0L
  }
  // 防重放裁决使用形式化证明函数（verify/inbox_advance：res == (incoming > last) 由 Z3 证明）
  guard @verify.inbox_advance(last, env.seq) else {
    raise Envelope("stale or duplicate seq \{env.seq} <= \{last}")
  }
  self.inbox_seq[env.sender_urn] = env.seq
  {
    message_id: env.message_id(),
    kind: env.kind,
    sender_urn: env.sender_urn,
    seq: env.seq,
    payload: env.payload,
  }
}
