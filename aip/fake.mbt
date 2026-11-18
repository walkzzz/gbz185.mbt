// FakeTransport（sans-I/O mock）：内存直连两个协议栈。
// 用途：上层（skills-mcp/server）与互联互通测试（TC-F17-002 本地版）的注入点；
// 正式 transport（@socket/@tls/MQ）于 W12 接入同一 dispatch/receive 契约面。

///|
pub fn send_direct(
  sender : AipProtocol,
  receiver : AipProtocol,
  kind : MessageKind,
  payload : Json,
) -> AipMessage raise AipError {
  let env = AipProtocol::dispatch(sender, kind, receiver.self_urn(), payload)
  AipProtocol::receive(receiver, env)
}
