# 安全说明（gbz185.mbt 0.2.0）

## 1. 威胁模型

| 威胁 | 面 | 现有防护 |
| --- | --- | --- |
| 报文重放 | 185.6 交互 | 每发送者单调序号；`verify.inbox_advance`（Z3 证明）在 `receive` 真实裁决 |
| 序号回退/溢出 | 185.3 分配 / 185.6 接收 | `verify.next_seq` 严格递增证明；`clamp_i64` 硬边界；`inbox_update` 单调不变量 |
| 身份冒充 | 185.2 / 185.3 | AIC 结构校验；注册中心分配 AIC；凭证校验 `CAIVerifier` 注入 |
| 凭证泄露/过期 | 185.3 生命周期 | 有效期 `expires_at` + `renew`；过期鉴权失败并记 `AuthenticationDenied` |
| 资源耗尽 | 注册表 / 工具表 | `max_entries`（默认 1024）/ `max_tools`（默认 256）容量防护；`verify.register_within_capacity` |
| 传输窃听/中间人 | transport_async | TLS + 对端证书 SHA-256 指纹钉扎（`peer_cert_fingerprint`） |
| JS 精度漂移 | wire 数字字段 | Int64 → `Json::number(to_double())` 显式转换；`verify.in_js_safe_domain`（2^53） |

## 2. 信任边界

- **协议核心**不含秘密：不读环境变量、不持私钥、不做 I/O；密钥与凭证由调用方通过 `CAIVerifier` 注入。
- **传输扩展**独立成包（native-only），核心不依赖其安全实现；证书指纹校验由调用方在连接期比较。
- **工具调用**执行函数由调用方注入；库只负责查找、分发与审计日志，不执行沙箱策略。

## 3. 已知安全边界（真话）

- mTLS 双向客户端证书受 `@tls` API 限制，以对端指纹钉扎**等效**实现，不等同于完整双向证书链校验（GAP-2）。
- MQ 分发与国密套件（SM2/SM3/SM4）未实现（GAP-3），互联生产部署需上层补齐。
- 审计事件为内存数组，进程退出即失；持久化审计属上层职责。
- `transport_async` 的 async API 未出现在 `.mbti` 契约（工具链限制），使用前请阅读源码文档。

## 4. 依赖与供应链

- 核心包零 mooncakes 依赖（仅 MoonBit core）；
- `transport_async` 依赖 `moonbitlang/async`、`cc06b/mooncry`，版本在 `moon.mod` 钉扎；
- 第三方组件与许可证见 [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)。

## 5. 漏洞报告

请按 [`SECURITY.md`](../SECURITY.md) 的私密渠道报告；请勿在公开 issue 中披露可利用细节。建议附最小复现（输入 JSON / 调用序列）与影响面判断。
