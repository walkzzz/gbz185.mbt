// GB/Z 185.6 AIP 消息信封与消息类型（wire 契约）
// GB/Z 185.6 AIP message envelope and message kinds (wire contract)

///|
#derive(Eq, Debug)
pub(all) enum MessageKind {
  TaskRequest
  TaskResult
  Event
  Heartbeat
}

///|
pub fn MessageKind::to_wire(self : MessageKind) -> String {
  match self {
    TaskRequest => "task_request"
    TaskResult => "task_result"
    Event => "event"
    Heartbeat => "heartbeat"
  }
}

///|
pub fn MessageKind::from_wire(s : String) -> MessageKind? {
  match s {
    "task_request" => Some(TaskRequest)
    "task_result" => Some(TaskResult)
    "event" => Some(Event)
    "heartbeat" => Some(Heartbeat)
    _ => None
  }
}

///|
pub extend MessageKind with Eq::{equal, not_equal}

///|
pub extend MessageKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn envelope_version() -> String {
  @wire.envelope_version()
}

///|
pub fn protocol_name() -> String {
  @wire.aip_protocol_name()
}

///|
#derive(Eq, Debug)
pub(all) struct AipEnvelope {
  envelope_version : String
  sender_urn : String
  recipient_urn : String
  seq : Int64
  timestamp : Int64
  kind : MessageKind
  payload : Json
}

///|
/// 消息标识单源（GB/Z 185.6）：`sender_urn#seq`——接收侧 AipMessage::message_id 由此生成
/// Single-source message identity (GB/Z 185.6): `sender_urn#seq`, used by AipMessage::message_id on the receive side.
pub fn AipEnvelope::message_id(self : AipEnvelope) -> String {
  "\{self.sender_urn}#\{self.seq}"
}

///|
pub extend AipEnvelope with Eq::{equal, not_equal}

///|
pub extend AipEnvelope with @moonbitlang/core/debug.Debug::{to_repr}
