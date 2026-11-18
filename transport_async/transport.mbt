// GB/Z 185 传输扩展包（transport-async，spire 式 core/extensions 分层的扩展实现）：
// TCP NDJSON 信封通道（GB/Z 185.6 信封的传输帧格式）+ 服务端回显（E2E 验证）。
// 协议核心（aip 包）保持 sans-I/O 零改动——传输层经信封 wire 契约对接。
// Transport extension (spire-style core/extensions split): TCP NDJSON envelope
// channel; the protocol core (aip) stays sans-I/O via the envelope wire contract.

///|
/// 传输层错误（NDJSON 帧/连接）
pub(all) suberror TransportError {
  AddrInvalid(String)
  FrameInvalid(String)
  ConnectionClosed(String)
}

///|
pub impl Show for TransportError with fn output(self, logger) -> Unit {
  match self {
    AddrInvalid(a) => logger.write_string("transport/addr-invalid: \{a}")
    FrameInvalid(line) =>
      logger.write_string("transport/frame-invalid: \{line}")
    ConnectionClosed(a) =>
      logger.write_string("transport/connection-closed: \{a}")
  }
}

///|
pub extend TransportError with Show::{to_string, output}

///|
/// NDJSON 帧编码：信封 → 单行 JSON + 换行
pub fn ndjson_encode(env : @aip.AipEnvelope) -> String {
  env.to_json().stringify() + "\n"
}

///|
/// NDJSON 帧解码：单行（含尾换行）→ 信封
pub fn ndjson_decode(line : String) -> @aip.AipEnvelope raise TransportError {
  let trimmed = if line.has_suffix("\n") {
    line[:line.length() - 1].to_owned()
  } else {
    line
  }
  let j = @json.parse(trimmed) catch { _ => raise FrameInvalid(trimmed) }
  @aip.AipEnvelope::from_json(j) catch {
    _ => raise FrameInvalid(trimmed)
  }
}

///|
/// TCP NDJSON 传输通道（client/server 连接的统一封装）
pub struct TcpChannel {
  tcp : @socket.Tcp
}

///|
/// 连接远端（client 侧）
pub async fn TcpChannel::connect(
  addr : String,
) -> TcpChannel raise TransportError {
  let a = @socket.Addr::parse(addr) catch { _ => raise AddrInvalid(addr) }
  let tcp = @socket.Tcp::connect(a) catch { _ => raise AddrInvalid(addr) }
  { tcp, }
}

///|
/// 发送信封（NDJSON 帧）
pub async fn TcpChannel::send_env(
  self : TcpChannel,
  env : @aip.AipEnvelope,
) -> Unit raise TransportError {
  self.tcp.write(ndjson_encode(env)) catch {
    _ => raise ConnectionClosed("write failed")
  }
}

///|
/// 接收信封（读一行 NDJSON → 解码；None = 对端关闭）
pub async fn TcpChannel::recv_env(
  self : TcpChannel,
) -> @aip.AipEnvelope? raise TransportError {
  // read_until 的 async 错误类型为通用 Error——catch 后归一为 TransportError
  match
    (self.tcp.read_until("\n") catch {
      _ => raise ConnectionClosed("read failed")
    }) {
    Some(line) => {
      let decoded = ndjson_decode(line) catch { _ => raise FrameInvalid(line) }
      Some(decoded)
    }
    None => None
  }
}

///|
pub fn TcpChannel::close(self : TcpChannel) -> Unit {
  self.tcp.close()
}

///|
/// 信封回显服务（E2E 验证）：accept 循环 + 每连接读信封 → 原样回写
pub async fn serve_echo(addr : String) -> Unit raise TransportError {
  let a = @socket.Addr::parse(addr) catch { _ => raise AddrInvalid(addr) }
  let server = @socket.TcpServer::TcpServer(a) catch {
    _ => raise AddrInvalid(addr)
  }
  server.run_forever(async fn(tcp : @socket.Tcp, _peer : @socket.Addr) {
    match tcp.read_until("\n") {
      Some(line) => tcp.write(line) catch { _ => () }
      None => ()
    }
  }) catch {
    _ => ()
  }
}
