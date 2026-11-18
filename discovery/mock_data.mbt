// 小模型 AI mock 数据生成器（fake LLM simulation，GB/Z 185.5 发现域）：
// 用 seed 化 chacha8 PRNG 模拟本地小模型（Qwen2.5-0.5B GGUF，见 test-fixtures/llm-local.md）
// 的采样输出——每次调用（不同 seed）生成不同的 mock 数据；真实模型接入保留同接口。

///|
let mock_capabilities : Array[String] = [
  "skill:demo", "tool:file_read", "tool:net_fetch", "agent:translate", "tool:cli_execute",
]

///|
let mock_name_words : Array[String] = [
  "alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel",
]

///|
/// 生成 count 个模拟小模型输出的智能体节点（seed 化可复现；不同 seed → 不同数据）
pub fn generate_mock_nodes(seed : Int32, count : Int32) -> Array[AgentNode] {
  let rand = @random.Rand::chacha8(
    seed=@wire.seed32_bytes("gbz185-mock-\{seed}"),
  )
  let out : Array[AgentNode] = []
  for i in 0..<count {
    let cap_a = mock_capabilities[rand
      .uint(limit=mock_capabilities.length().reinterpret_as_uint())
      .reinterpret_as_int()]
    let cap_b = mock_capabilities[rand
      .uint(limit=mock_capabilities.length().reinterpret_as_uint())
      .reinterpret_as_int()]
    let word = mock_name_words[rand
      .uint(limit=mock_name_words.length().reinterpret_as_uint())
      .reinterpret_as_int()]
    let discoverable = rand.uint(limit=2U) == 0U
    let caps = if cap_a == cap_b { [cap_a] } else { [cap_a, cap_b] }
    let node = AgentNode::from_frontmatter(
      "urn:agent:mock:\{seed}-\{i}",
      "\{word}-\{i}",
      @identity.Active,
      discoverable,
      caps,
      ["text"],
      ["text"],
    )
    out.push(node)
  }
  out
}
