# Changelog

本项目的所有显著变更记录于此文件。格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本遵循 [语义化版本 2.0.0](https://semver.org/spec/v2.0.0.html)。

## [0.1.0] - 未发布（准发布：CDN 恢复后 mooncakes 上架）

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

### Quality

- 77/77 测试全绿（native；黑盒/白盒/Fake/quickcheck 属性 seed 固定/小模型 mock 消费）
- 四目标 `moon check --deny-warn --target all` 零警告
- 覆盖率 94.8%（78/1503 未覆盖，集中于防御分支）；CRAP 全函数 < 10
- 变异测试 12/12 KILLED（击杀率 100%）
- 基准实测（moon bench）：dispatch 90.51ns、registry_lookup 96.29ns、envelope_wire_roundtrip 1.69µs
- 形式化验证：3 goals proved（WSL Ubuntu + Z3 4.8.12）

## [Unreleased]

### Planned — 0.2.0

- transport-async：mTLS 双向客户端证书（@tls API 支持后）、MQ 分发（moonamqp1）、ACPs 注册/发现客户端
- AIP 会话超时与心跳重连（结构化并发）
- 国密通道（mooncry SM2/SM3/SM4）与后量子证书实验（mooncred ML-DSA）
