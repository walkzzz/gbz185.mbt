// wire 层错误契约测试（JsonWireError 三分型的 code/message/part/to_json/Show 全覆盖）

///|
test "json wire error variants expose code message part" {
  let missing : @wire.JsonWireError = @wire.MissingField("aic")
  assert_eq(missing.code(), "WIRE-1001")
  assert_eq(missing.part(), "gbz185.wire")
  assert_true(missing.message().contains("aic"))
  assert_true(missing.to_string().contains("missing-field"))
  assert_true(missing.to_json().stringify().contains("missing-field"))

  let bad_type : @wire.JsonWireError = @wire.BadType("capabilities", "array")
  assert_eq(bad_type.code(), "WIRE-1002")
  assert_true(bad_type.message().contains("array"))
  assert_true(bad_type.to_string().contains("bad-type"))
  assert_true(bad_type.to_json().stringify().contains("array"))

  let bad_value : @wire.JsonWireError = @wire.BadValue("kind", "bogus")
  assert_eq(bad_value.code(), "WIRE-1003")
  assert_true(bad_value.message().contains("bogus"))
  assert_true(bad_value.to_string().contains("bad-value"))
  assert_true(bad_value.to_json().stringify().contains("bogus"))
}

///|
test "json helpers reject non-object and wrong types" {
  let non_object = try {
    let _ = @wire.json_string_field(("x" : Json), "k")
    ""
  } catch {
    @wire.BadType(_, want) => want
    _ => "unexpected"
  }
  assert_eq(non_object, "object")

  let missing = try {
    let _ = @wire.json_string_field(Json::empty_object(), "k")
    ""
  } catch {
    @wire.MissingField(f) => f
    _ => "unexpected"
  }
  assert_eq(missing, "k")

  let bad_arr = try {
    let _ = @wire.json_string_array_opt({ "k": 1.0 }, "k")
    ""
  } catch {
    @wire.BadType(_, want) => want
    _ => "unexpected"
  }
  assert_eq(bad_arr, "array")

  let bad_item = try {
    let _ = @wire.json_string_array_opt({ "k": [1.0] }, "k")
    ""
  } catch {
    @wire.BadType(_, want) => want
    _ => "unexpected"
  }
  assert_eq(bad_item, "string-array")
}

///|
test "optional helpers treat null and absence as none" {
  assert_true(@wire.json_optional_string({ "k": Json::null() }, "k") is None)
  assert_true(@wire.json_optional_string(Json::empty_object(), "k") is None)
  assert_true(@wire.json_optional_int64({ "k": Json::null() }, "k") is None)
  assert_true(@wire.json_optional_int64(Json::empty_object(), "k") is None)
  assert_eq(@wire.json_optional_int64({ "k": 7.0 }, "k"), Some(7L))
  assert_eq(@wire.bytes_hex(@wire.seed32_bytes("abc")).length(), 64)
}
