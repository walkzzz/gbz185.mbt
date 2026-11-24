# Changelog

本项目的所有显著变更记录于此文件。格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本遵循 [语义化版本 2.0.0](https://semver.org/spec/v2.0.0.html)。

## [0.2.1] - 2026-11-24

### Fixed — 页面测试报告 F1–F4

- **F1 窄屏导航**：≤960px 新增汉堡按钮（`#nav-toggle`）+ 抽屉导航（`.nav.open`），含 `aria-expanded`、Escape/点链接/resize 关闭。
- **F2 演示层 int32 截断**：移除 `Number(x) | 0`，改为 `Number.isSafeInteger` + int32 范围前置校验；越界返回错误而非回绕；页面与 playground 文档标注「int32 演示范围」。
- **F3 空 URN / seq=0**：`aip_make_envelope` 拒绝空 sender/recipient、seq ≤ 0、timestamp < 0；`aip_validate` 增加取值语义校验（非空 URN、seq > 0、timestamp ≥ 0）。
- **F4 扇出 0 成员**：`aip_fanout_count` 返回 **-2**；页面提示「空群组拒绝（与路由卡同口径）」。

### Quality

- 页面门禁 131 → **141**；CDP E2E 17 → **26**（新增 939px 窄屏导航 5 项、边界输入 3 项、修复恢复 1 项）。
- 测试 / 变异 / 覆盖率口径不变（124 / 117×3；19/19；811/883）。

## [0.2.0] - 2026-11-24

### Added — API 扩充（纯增量，无破坏）

- `identity`：`IdentityStatus::is_active`、`AgentIdentity::is_active`（仅 Active 可用）
- `capability`：`AgentCapabilitySet::count` / `covers_any` / `missing`（缺失诊断，保持顺序并去重）
- `discovery`：`AgentNode::matches`（发现过滤原子判定）；`match_nodes` 复用同一判定
- `registry`：`TokenRegistry::is_registered` / `urn_list`（shortlex 确定性顺序）
- `aip`：`AipProtocol::is_registered` / `outbox_seq` / `inbox_watermark` / `peer_urns`；
  `AipEnvelope::message_id`（`sender#seq` 单源，接收侧复用）；
  `AipSession::session_id` / `local_urn` / `remote_urn` / `outbox_seq`；`RouteTable::is_member`
- `tooling`：`ToolRegistry::is_registered` / `names`（shortlex 确定性顺序）

### Changed

- `TokenRegistry::find_by_capability`：需求先去重 + 「能力条目数 < 需求数」长度剪枝（严格等价的性能优化，含等长/超集/短集测试）
- `AipProtocol::dispatch` 的身份门槛改用 `is_registered()`；`receive` 的消息标识改用 `envelope.message_id()`（单源）
- `tooling` 注销检查复用 `is_registered()`

### Added — 演示与页面

- `playground` 导出 4 → **11**：新增 `aip_envelope_meta`、`aip_protocol_flow`、`capability_report`、`discovery_match`、`identity_aic_check`、`route_resolve`、`tool_descriptor_check`
- `docs/index.html` / `app.js` / `style.css` 改为库首页范式（sticky 导航、Hero 实时流程、12 能力卡、10 演示卡、深浅主题、Open Graph、响应式），**保留既有 `id` 与 `data-*` 钩子**
- `scripts/check_pages.mjs` 18 → **131 项**（结构 / 旧钩子 / 新钩子 / 11 导出 / AIP 语义 / 版本口径）

### Added — 文档

- 七篇立项文档：`docs/architecture.md`、`performance.md`、`comparison.md`、`assessment.md`、`proposal.md`、`migration.md`、`security.md`；新增 `docs/roadmap.md`

### Quality（2026-11-24 实测）

- 测试：**native 124/124**；**js / wasm / wasm-gc 各 117/117**
- 覆盖率：**811/883 = 91.8%**（native 插桩点口径，排除 transport_async/playground/examples；旧 94.8% 分母不可复现，废弃）
- 变异：**19/19 KILLED**（12 → 19；修正 M01/M02/M10 失效的 old_sub）
- 基准：dispatch 122.98ns / registry_lookup 81.13ns / envelope 往返 1.56µs / find_by_capability 101.59µs（1000 节点 × 8 需求）
- 形式化：20 obligations / 13 verified functions（未改动证明函数）

### Fixed

- 明确并测试排序语义：MoonBit `Compare for String` 为 **shortlex**（长度优先），`names` 断言可区分「已排序」与「插入顺序」

## [0.1.0] - 2026-11-20

### Added — GB/Z 185-2026 协议栈（10 包）

- **GB/Z 185.1** `arch`（根包门面）：总体架构——双模式（本地/互联）、全局模型五实体（agents/agent_skills/agent_messages/agent_tasks/sessions）、互联角色五定义
- **GB/Z 185.2** `identity`：身份码 AIC 点分编码结构与校验（逐字符状态机）、唯一标识、CAI 凭证引用、`identity_status` 四态（none/active/locked/revoked）、wire 编解码
- **GB/Z 185.3** `registry`：ATR 内存注册表——注册（AIC 分配，`clamp_i64` 形式化防护）、凭证校验（CAIVerifier 注入）、鉴权（有效期判定 + last_seen 更新）、生命周期（lock/revoke）、注销、凭证续期（renew）、容量防护（CapacityExceeded）、审计事件（RegistryEvent 六型）、能力检索（find_by_capability）、运维观测（registered_at_of/last_seen_of/aic_of）
- **GB/Z 185.4** `capability`：ACS 能力元数据（capabilities/default_input_types/default_output_types/constraints）、匹配原语（covers）、wire 编解码
- **GB/Z 185.5** `discovery`：ADP 检索/匹配/`discoverable` 可见性过滤（match_nodes）、AgentNode wire 编解码、**小模型 mock 数据生成器**（fake LLM simulation，seed 化可复现）
- **GB/Z 185.6** `aip`：**AIP 交互协议**——报文信封（单调序号防重放，形式化证明）、群组 URN 直通、会话（AipSession：会话级序号空间/生命周期/peer 校验）、路由（RouteTable 群组管理/resolve 三分支/群组扇出 fanout）、FakeTransport（sans-I/O 直连）
- **GB/Z 185.7** `tooling`：工具调用——`ToolDescriptor` 单源模型（validate/编解码/**MCP tools/list 单源映射 to_mcp_entry**）、调用流程（ToolInvocation/ToolOutcome）、**ToolRegistry**（注册/容量防护/调用分发/审计日志/批量调用）、`ToolCallable` 绑定契约

### Added — 公共层与基础设施

- `wire`：`ProtocolError` 统一错误特征（pub(open) trait：part/code/message）、JSON 编解码工具 8 个、信封常量、`seed32_bytes`/`bytes_hex`
- `verify`：形式化验证——**moon prove 3 goals proved**（Z3 机器验证）：`clamp_i64`（ATR 序号防护）、`next_seq`（AIP 序号严格递增）、`inbox_advance`（防重放准入裁决）——均被主包真实调用（"已证明=已使用"）
- `transport_async`（native 限定）：TCP NDJSON 信封通道（TcpChannel：connect/send_env/recv_env/close）、**mTLS 安全通道**（TlsTcpChannel：trust 三模式 SystemRoot/NoVerification/CustomPemFile + 对端证书 SHA256 指纹钉扎）、信封回显服务（serve_echo）
- `aip/mock_data.mbt` + `discovery/mock_data.mbt`：小模型 AI mock 数据生成器（fake LLM simulation，seed 化 chacha8——每次调用不同数据）

### Added — 工程质量

- GitHub Actions CI：四目标 `moon check --deny-warn` + 三平台 native 测试 + 便携目标测试 + **moon prove**（Z3）+ .mbti 契约漂移门禁
- 中英双语 README（默认中文）+ 中英双语源码注释（17 文件头 + 26 API doc）
- mooncakes `moon publish` 与 GitHub Actions Release 工作流（workflow_dispatch 手动触发）

### Quality（0.1.0 历史口径，已被 0.2.0 取代）

- 77/77 测试全绿（native；黑盒/白盒/Fake/quickcheck 属性 seed 固定/小模型 mock 消费）
- 四目标 `moon check --deny-warn --target all` 零警告
- 覆盖率 94.8%（78/1503 未覆盖，集中于防御分支；该分母不可复现，0.2.0 起改用插桩点口径）
- 变异测试 12/12 KILLED（0.2.0 扩至 19/19）
- 基准实测（moon bench）：dispatch 90.51ns、registry_lookup 96.29ns、envelope_wire_roundtrip 1.69µs
- 形式化验证：3 goals proved（WSL Ubuntu + Z3 4.8.12；0.2.0 保持 20 obligations）

## [Unreleased]

### Planned — 0.3.0

- 互联模式 MQ 分发（185.6）设计评审与实现
- 国密套件（SM2/SM3/SM4）与 mooncry 集成评估
- `transport_async` async API 的 `.mbti` 导出（跟踪工具链修复）
- 覆盖率补充至 ≥95%（错误渲染分支与 mock 防御路径）
- transport-async：mTLS 双向客户端证书（@tls API 支持后）
