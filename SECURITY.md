# 安全策略（Security Policy）

## 支持的版本

| 版本 | 支持状态 |
| --- | --- |
| 0.1.x | ✅ 支持 |

## 报告漏洞

**请勿通过公开 GitHub Issues 报告安全漏洞。**

- 邮箱：通过 GitHub 个人主页（walkzzz）联系方式私下披露
- 报告内容请包含：受影响的包（wire/identity/registry/capability/discovery/aip/tooling/transport_async）、复现步骤（最小复现工程最佳）、影响的 GB/Z 185-2026 部分（185.2/185.3/185.6 等）

### 响应目标

| 严重级 | 响应 | 修复 |
| --- | --- | --- |
| 高危（协议绕过/密钥泄露/身份伪造） | 48 小时内确认 | 7 天内补丁发布 |
| 中危（校验缺失/信息泄露） | 7 天内确认 | 下一版本 |
| 低危 | 随下版本 | — |

## 安全设计要点（供审计参考）

- **身份**：AIC 采用 OID 点分数字编码（逐字符状态机校验），identity_status 四态由 ATR 状态机管理
- **防重放**：AIP 信封序号单调递增（`next_seq`/`inbox_advance` 经 moon prove + Z3 形式化证明，见 `verify/core.mbt`），会话级与协议级双层水位
- **凭证**：CAI 校验经 `CAIVerifier` trait 注入（核心零第三方依赖），凭证有效期与续期由 registry 生命周期管理
- **传输**：TLS（服务器证书链验证/对端证书 SHA256 指纹钉扎）；**mTLS 双向客户端证书受 @tls API 限制**，以指纹钉扎等效实现（已知限制）
- **密钥管理**：本栈不存储长期密钥；凭证与签名均委托 mooncry/mooncred（外部加密原语库）
- **已知限制**：transport_async 的 MQ 分发与国密套件（SM2/SM3/SM4）为路线图项（见 CHANGELOG Unreleased）

## 范围声明

本栈为 **sans-I/O 协议核心**：不做网络策略决策、不管理长期密钥存储、不执行运行时沙箱隔离——这些由宿主应用（skills-server/skills-agent）负责。transport_async 的 TLS 绑定依赖 moonbitlang/async 的 OpenSSL 绑定。
