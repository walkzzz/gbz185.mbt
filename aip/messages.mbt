// AIP 四原语消息模型（discover / register / capability / dispatch）
// AIP four-primitive message model (discover / register / capability / dispatch)

///|
#derive(Eq, Debug)
pub(all) struct DiscoverRequest {
  requester_urn : String
  filter_capabilities : Array[String]
}

///|
pub extend DiscoverRequest with Eq::{equal, not_equal}

///|
pub extend DiscoverRequest with @moonbitlang/core/debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct DiscoverResponse {
  nodes : Array[@discovery.AgentNode]
}

///|
pub extend DiscoverResponse with Eq::{equal, not_equal}

///|
pub extend DiscoverResponse with @moonbitlang/core/debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct RegisterRequest {
  node : @discovery.AgentNode
}

///|
pub extend RegisterRequest with Eq::{equal, not_equal}

///|
pub extend RegisterRequest with @moonbitlang/core/debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct RegisterResponse {
  accepted : Bool
  aic : String?
  reason : String?
}

///|
pub extend RegisterResponse with Eq::{equal, not_equal}

///|
pub extend RegisterResponse with @moonbitlang/core/debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct CapabilityRequest {
  requester_urn : String
  target_urn : String
}

///|
pub extend CapabilityRequest with Eq::{equal, not_equal}

///|
pub extend CapabilityRequest with @moonbitlang/core/debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct AipMessage {
  message_id : String
  kind : MessageKind
  sender_urn : String
  seq : Int64
  payload : Json
}

///|
pub extend AipMessage with Eq::{equal, not_equal}

///|
pub extend AipMessage with @moonbitlang/core/debug.Debug::{to_repr}
