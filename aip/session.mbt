// GB/Z 185.6 AIP 会话管理（Session）：两方消息会话的状态与序号追踪。
// 会话级序号空间独立于协议栈全局序号；sans-I/O（时间戳由调用方注入）。
// AIP session management (GB/Z 185.6): per-session state and sequence tracking;
// session-scoped sequence space independent from the protocol-global one; sans-I/O.

///|
#derive(Eq, Debug)
pub(all) enum SessionState {
  Open
  Closed
}

///|
pub extend SessionState with Eq::{equal, not_equal}

///|
pub extend SessionState with @moonbitlang/core/debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub struct AipSession {
  session_id : String
  self_urn : String
  peer_urn : String
  mut state : SessionState
  mut outbox_seq : Int64
  mut inbox_seq : Int64
  mut message_count : Int32
}

///|
pub extend AipSession with Eq::{equal, not_equal}

///|
pub extend AipSession with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 打开会话（GB/Z 185.6 会话建立；session_id 由调用方生成并保证唯一）
pub fn AipSession::open(
  session_id : String,
  self_urn : String,
  peer_urn : String,
) -> AipSession {
  {
    session_id,
    self_urn,
    peer_urn,
    state: Open,
    outbox_seq: 0L,
    inbox_seq: 0L,
    message_count: 0,
  }
}

///|
/// 会话标识（调用方生成并保证唯一）
pub fn AipSession::session_id(self : AipSession) -> String {
  self.session_id
}

///|
/// 会话本端 URN
pub fn AipSession::local_urn(self : AipSession) -> String {
  self.self_urn
}

///|
/// 会话对端 URN
pub fn AipSession::remote_urn(self : AipSession) -> String {
  self.peer_urn
}

///|
/// 会话内发送序号（最近一次 send 分配；未发送为 0）
pub fn AipSession::outbox_seq(self : AipSession) -> Int64 {
  self.outbox_seq
}

///|
pub fn AipSession::is_active(self : AipSession) -> Bool {
  self.state is Open
}

///|
pub fn AipSession::message_count(self : AipSession) -> Int32 {
  self.message_count
}

///|
pub fn AipSession::inbox_watermark(self : AipSession) -> Int64 {
  self.inbox_seq
}

///|
/// 关闭会话（关闭后 send/recv 均被拒绝；幂等）
pub fn AipSession::close(self : AipSession) -> Unit {
  self.state = Closed
}

///|
/// 会话内发送：信封 recipient 固定为对端，序号为会话内单调递增；关闭后拒绝
pub fn AipSession::send(
  self : AipSession,
  kind : MessageKind,
  payload : Json,
) -> AipEnvelope raise AipError {
  guard self.state is Open else {
    raise Envelope("session \{self.session_id} is closed")
  }
  self.outbox_seq = @verify.next_seq(self.outbox_seq)
  {
    envelope_version: envelope_version(),
    sender_urn: self.self_urn,
    recipient_urn: self.peer_urn,
    seq: self.outbox_seq,
    timestamp: 0L,
    kind,
    payload,
  }
}

///|
/// 会话内接收：校验收发双方身份并推进防重放水位；关闭后拒绝
pub fn AipSession::recv(
  self : AipSession,
  env : AipEnvelope,
) -> AipMessage raise AipError {
  guard self.state is Open else {
    raise Envelope("session \{self.session_id} is closed")
  }
  guard env.sender_urn == self.peer_urn else {
    raise Envelope(
      "session peer mismatch: expected \{self.peer_urn}, got \{env.sender_urn}",
    )
  }
  guard env.recipient_urn == self.self_urn else {
    raise Envelope("session envelope not addressed to self")
  }
  let watermark = self.inbox_seq
  guard @verify.inbox_advance(watermark, env.seq) else {
    raise Envelope("stale or duplicate seq \{env.seq} <= \{watermark}")
  }
  self.inbox_seq = env.seq
  self.message_count += 1
  {
    message_id: "\{self.session_id}#\{env.seq}",
    kind: env.kind,
    sender_urn: env.sender_urn,
    seq: env.seq,
    payload: env.payload,
  }
}
