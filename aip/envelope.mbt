// GB/Z 185.6 AIP 消息信封与消息类型（wire 契约）

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
pub extend AipEnvelope with Eq::{equal, not_equal}

///|
pub extend AipEnvelope with @moonbitlang/core/debug.Debug::{to_repr}
