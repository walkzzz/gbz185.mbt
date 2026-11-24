# 立项建议书（gbz185.mbt 0.2.0）

## 1. 项目目标

在 MoonBit 生态中提供一套**可复用、可验证、跨目标一致**的 GB/Z 185-2026 智能体互联协议栈库：

1. 按国标 185.1-185.7 分部建模，一个分部一个包，边界可审计；
2. 协议核心 sans-I/O，传输与鉴权以注入方式扩展；
3. 关键安全语义（防重放、容量、序号）由形式化证明函数承担并被真实调用；
4. 同一份源码支持 native / js / wasm / wasm-gc，并可编译到浏览器演示。

## 2. 范围

### 2.1 纳入范围

- `identity`：AIC 结构校验、身份状态谓词、wire 编解码；
- `registry`：注册/鉴权/生命周期/容量/审计/能力检索；
- `capability`：能力集、`covers` / `covers_any` / `missing` / `count`；
- `discovery`：`AgentNode`、原子 `matches`、批量 `match_nodes`；
- `aip`：信封、协议状态机、会话、路由/扇出、状态观测、消息标识；
- `tooling`：`ToolDescriptor` 单源模型、注册表、调用日志、MCP 视图；
- `wire`：统一错误契约与 JSON helpers；`verify`：证明函数；
- `transport_async`：TCP NDJSON / TLS 指纹钉扎（native-only）；
- `playground`：11 个非 raise 演示导出 + `docs/` 静态页面。

### 2.2 非目标

- 协议端点服务、MQ 分发、国密套件（0.3.0+ 评估）；
- 与 gRPC/OpenAPI 的桥接；
- 双向 mTLS 客户端证书（以指纹钉扎等效，GAP-2）。

## 3. 里程碑

| 里程碑 | 内容 | 状态 |
| --- | --- | --- |
| M0 协议建模 | 十包骨架 + wire 错误契约 + 四目标编译 | ✅ 2026-11-17 |
| M1 生产级实现 | ATR 生命周期/容量/审计、ToolRegistry、传输扩展 | ✅ 2026-11-18 |
| M2 形式化 | 13 函数 / 20 条证明义务（Z3） | ✅ 2026-11-19 |
| M3 浏览器演示 | playground 导出 + Pages 页面 + 页面门禁 | ✅ 2026-11-20 |
| M4 0.2.0 立项增强 | 11 项 API、能力检索剪枝、124 测试、91.8% 覆盖、19/19 变异、11 导出、131 项页检、七篇立项文档 | ✅ 2026-11-24 |
| M5 0.3.0 候选 | MQ 分发、国密套件评估、跨版本兼容实证 | ⬜ 规划中 |

## 4. 验收口径（可复算）

```bash
moon check --deny-warn --target all   # 四目标零警告
moon test  --target native            # 124/124
moon test  --target js                # 117/117（wasm / wasm-gc 同）
moon bench --target native            # 4 项基准
moon run scripts/mutation_test.mbtx   # 19/19 KILLED
node scripts/check_pages.mjs          # 131 项
bash scripts/local_ci.sh --quick      # 本地 CI（含 prove）
```

覆盖率：`moon test --target native --enable-coverage --no-parallelize` 后
`moon coverage report -f full_summary`（核心包 trace）→ **811/883 = 91.8%**。

## 5. 交付物

- 库源码 10 包 + 根包门面 + `playground`；
- 测试矩阵（黑盒/白盒/属性/基准/变异脚本）；
- 七篇立项文档 + 测试报告 + 门禁报告 + 真话台账 + 变更日志；
- 浏览器演示页（`docs/`）与页面自检脚本；
- CI：`ci.yml`（check/test/contract/prove/coverage）、`pages.yml`、`release.yml`。

## 6. 资源与周期

单人维护，按版本迭代推进；无外部服务依赖，构建资源为 MoonBit 工具链 + Z3（prove 走 WSL/CI）。
