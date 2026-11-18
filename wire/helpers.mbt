// GB/Z 185 wire 层：公共 JSON helpers（重叠钉扎 #4——避免各协议包复制）

///|
pub fn json_string_array_opt(
  j : Json,
  key : String,
) -> Array[String] raise JsonWireError {
  match j {
    Object(fields) =>
      match fields.get(key) {
        Some(Array(items)) => {
          let out : Array[String] = []
          for item in items {
            match item {
              String(s) => out.push(s)
              _ => raise BadType(key, "string-array")
            }
          }
          out
        }
        Some(_) => raise BadType(key, "array")
        None => []
      }
    _ => raise BadType(key, "object")
  }
}

///|
pub fn json_int64_field(j : Json, key : String) -> Int64 raise JsonWireError {
  match j {
    Object(fields) =>
      match fields.get(key) {
        Some(Number(n, ..)) => n.to_int64()
        _ => raise MissingField(key)
      }
    _ => raise BadType(key, "object")
  }
}

///|
pub fn json_string_field(j : Json, key : String) -> String raise JsonWireError {
  match j {
    Object(fields) =>
      match fields.get(key) {
        Some(String(s)) => s
        _ => raise MissingField(key)
      }
    _ => raise BadType(key, "object")
  }
}

///|
pub fn json_bool_field(j : Json, key : String) -> Bool raise JsonWireError {
  match j {
    Object(fields) =>
      match fields.get(key) {
        Some(True) => true
        Some(False) => false
        _ => raise BadType(key, "boolean")
      }
    _ => raise BadType(key, "object")
  }
}

///|
pub fn json_optional_string(
  j : Json,
  key : String,
) -> String? raise JsonWireError {
  match j {
    Object(fields) =>
      match fields.get(key) {
        Some(String(s)) => Some(s)
        Some(Null) => None
        Some(_) => raise BadType(key, "string|null")
        None => None
      }
    _ => raise BadType(key, "object")
  }
}

///|
pub fn json_object_field(j : Json, key : String) -> Json raise JsonWireError {
  match j {
    Object(fields) =>
      match fields.get(key) {
        Some(o) => o
        _ => raise MissingField(key)
      }
    _ => raise BadType(key, "object")
  }
}

///|
pub fn json_optional_int64(
  j : Json,
  key : String,
) -> Int64? raise JsonWireError {
  match j {
    Object(fields) =>
      match fields.get(key) {
        Some(Number(n, ..)) => Some(n.to_int64())
        Some(Null) => None
        Some(_) => raise BadType(key, "number|null")
        None => None
      }
    _ => raise BadType(key, "object")
  }
}
