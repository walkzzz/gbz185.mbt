// TLS 安全信封通道黑盒测试（指纹纯函数 / 连接失败路径 / NDJSON over TLS 无网络部分）

///|
test "bytes_hex produces lowercase hex" {
  // 空输入
  assert_eq(@wire.bytes_hex(Bytes::from_array([])), "")
  // 已知向量：字节 0xDE 0xAD 0xBE 0xEF → "deadbeef"
  assert_eq(
    @wire.bytes_hex(Bytes::from_array([222, 173, 190, 239])),
    "deadbeef",
  )
  // 单字节低位
  assert_eq(@wire.bytes_hex(Bytes::from_array([15])), "0f")
}

///|
test "mooncry sha256 known vector (empty input)" {
  // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  let digest = @mooncry.sha256(Bytes::from_array([]))
  assert_eq(
    @wire.bytes_hex(digest),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "mooncry sha256 known vector (abc)" {
  // SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  let digest = @mooncry.sha256(Bytes::from_array([97, 98, 99]))
  assert_eq(
    @wire.bytes_hex(digest),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

// connect_tls 的 TCP 连接失败路径为 async——test 块不可调 async（MoonBit 限制），
// 由 transport_async 的 cmd E2E 脚本验证（对齐 simple-agent fakeapi 模式）；见 GATE_REPORT 整改项。
