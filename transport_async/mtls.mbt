// GB/Z 185 传输扩展包：TLS 安全信封通道（互联模式安全层）。
// Tls 装饰 Tcp（@tls.Tls 是 Reader+Writer 装饰器，NDJSON 帧逻辑复用）；
// 对端证书 SHA256 指纹（mooncry）用于应用层身份钉扎（与 ACPs 注册的 cert_fingerprint 比对）。
// TLS secure envelope channel: Tls decorates Tcp (Reader+Writer decorator), NDJSON framing reused;
// peer certificate SHA256 fingerprint (mooncry) for application-layer identity pinning.

///|
/// TLS 安全信封通道：单向 TLS（服务器证书 + 客户端验证）+ 对端指纹钉扎。
/// mTLS 双向客户端证书受 @tls API 限制（client 证书未暴露）——以指纹钉扎等效实现。
pub struct TlsTcpChannel {
  tls : @tls.Tls
}

///|
/// 建立 TLS 信封通道（client 侧）：TCP 连接 → TLS 握手。
/// trust 参数（GB/Z 185 互联模式适配）：SystemRoot 生产默认 / NoVerification 测试自签 / CustomPemFile 国标自建 CA。
pub async fn TlsTcpChannel::connect_tls(
  addr : String,
  host~ : String = "localhost",
  trust~ : @tls.TrustedRoot = @tls.SystemRoot,
) -> TlsTcpChannel raise TransportError {
  let a = @socket.Addr::parse(addr) catch { _ => raise AddrInvalid(addr) }
  let tcp = @socket.Tcp::connect(a) catch {
    _ => raise ConnectionClosed("tcp connect failed")
  }
  let tls = @tls.Tls::client(tcp, trust~, host~) catch {
    _ => raise ConnectionClosed("tls handshake failed")
  }
  { tls, }
}

///|
/// 发送信封（TLS 帧）
pub async fn TlsTcpChannel::send_env(
  self : TlsTcpChannel,
  env : @aip.AipEnvelope,
) -> Unit raise TransportError {
  self.tls.write(ndjson_encode(env)) catch {
    _ => raise ConnectionClosed("tls write failed")
  }
}

///|
/// 接收信封（TLS 读行 → 解码；None = 对端关闭）
pub async fn TlsTcpChannel::recv_env(
  self : TlsTcpChannel,
) -> @aip.AipEnvelope? raise TransportError {
  // TLS 的 async 错误类型为通用 Error——catch 后归一为 TransportError
  match
    (self.tls.read_until("\n") catch {
      _ => raise ConnectionClosed("tls read failed")
    }) {
    Some(line) => {
      let decoded = ndjson_decode(line) catch { _ => raise FrameInvalid(line) }
      Some(decoded)
    }
    None => None
  }
}

///|
/// 对端证书 SHA256 指纹（小写 hex）——与 ACPs 注册的 cert_fingerprint 比对
/// （GB/Z 185.2 身份-证书绑定：AIC 持有者的证书指纹钉扎，应用层 mTLS 等效实现）
pub fn TlsTcpChannel::peer_cert_fingerprint(
  self : TlsTcpChannel,
) -> String? raise TransportError {
  let cert = self.tls.get_peer_certificate() catch {
    _ => raise FrameInvalid("peer certificate unavailable")
  }
  match cert {
    Some(der) => Some(@wire.bytes_hex(@mooncry.sha256(der)))
    None => None
  }
}

///|
/// 关闭 TLS 通道（shutdown 握手）
pub fn TlsTcpChannel::close(self : TlsTcpChannel) -> Unit {
  self.tls.close()
}
