// GB/Z 185.6 AIP 域：信封变异生成器（小模型 fake，供防重放/校验模糊测试消费）
// 基于合法信封生成 seed 驱动的变体——变异信封应被 receive 的版本/收件人/防重放校验正确裁决。

///|
/// 基于合法信封生成 seed 驱动的变体：seq 在 ±1 与不变之间扰动、kind 随机重选
pub fn generate_mutated_envelope(
  base : AipEnvelope,
  seed : Int32,
) -> AipEnvelope {
  let rand = @random.Rand::chacha8(
    seed=@wire.seed32_bytes("gbz185-mut-\{seed}"),
  )
  let delta = (rand.uint(limit=3U).reinterpret_as_int() - 1).to_int64()
  let kinds = [TaskRequest, TaskResult, Event, Heartbeat]
  {
    ..base,
    seq: base.seq + delta,
    kind: kinds[rand.uint(limit=4U).reinterpret_as_int()],
  }
}

///|
/// 生成 count 个合法可分发信封（seed 化；供模糊测试批量消费）
pub fn generate_dispatch_envelopes(
  proto : AipProtocol,
  seed : Int32,
  count : Int32,
) -> Array[AipEnvelope] {
  let rand = @random.Rand::chacha8(
    seed=@wire.seed32_bytes("gbz185-disp-\{seed}"),
  )
  let kinds = [TaskRequest, TaskResult, Event, Heartbeat]
  let out : Array[AipEnvelope] = []
  for _i in 0..<count {
    let kind = kinds[rand.uint(limit=4U).reinterpret_as_int()]
    let payload : Json = Json::number(
      rand.uint(limit=1000U).reinterpret_as_int().to_double(),
    )
    let env = AipProtocol::dispatch(proto, kind, "urn:agent:group:g", payload) catch {
      _ => panic()
    }
    out.push(env)
  }
  out
}
