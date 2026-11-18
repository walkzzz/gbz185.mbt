// GB/Z 185 wire 层公共工具黑盒测试（json_string_array_opt 从原 aip wbtest 迁入）

///|
test "json_string_array_opt: non-object input raises" {
  let mut got = false
  try {
    let _ = @wire.json_string_array_opt(Json::string("x"), "key")
    panic()
  } catch {
    @wire.BadType(_, _) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "json_string_array_opt: missing key returns empty array" {
  let out = @wire.json_string_array_opt(Json::empty_object(), "missing") catch {
    _ => panic()
  }
  assert_eq(out.length(), 0)
}

///|
test "json_string_array_opt: non-array value raises" {
  let mut got = false
  try {
    let _ = @wire.json_string_array_opt({ "key": Json::string("x") }, "key")
    panic()
  } catch {
    @wire.BadType(_, _) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "json_string_array_opt: non-string element raises" {
  let mut got = false
  try {
    let _ = @wire.json_string_array_opt({ "key": [1.0] }, "key")
    panic()
  } catch {
    @wire.BadType(_, _) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "json_string_array_opt: happy path preserves order" {
  let out = @wire.json_string_array_opt({ "key": ["a", "b", "c"] }, "key") catch {
    _ => panic()
  }
  assert_eq(out, ["a", "b", "c"])
}

///|
test "scalar field helpers" {
  let obj : Json = {
    "s": "v",
    "n": 42.0,
    "b": true,
    "opt_s": "x",
    "opt_n": Json::null(),
  }
  assert_eq(@wire.json_string_field(obj, "s") catch { _ => panic() }, "v")
  assert_eq(@wire.json_int64_field(obj, "n") catch { _ => panic() }, 42L)
  assert_eq(@wire.json_bool_field(obj, "b") catch { _ => panic() }, true)
  assert_eq(
    @wire.json_optional_string(obj, "opt_s") catch {
      _ => panic()
    },
    Some("x"),
  )
  assert_eq(
    @wire.json_optional_int64(obj, "opt_n") catch {
      _ => panic()
    },
    None,
  )
}

///|
test "wire error contract via ProtocolError (特征系统)" {
  let err : @wire.JsonWireError = @wire.MissingField("aic")
  assert_eq(err.part(), "gbz185.wire")
  assert_eq(err.code(), "WIRE-1001")
  assert_eq(err.message(), "missing field aic")
}
