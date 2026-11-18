# Third-Party Notices

gbz185.mbt 依赖以下第三方开源组件，在此致谢并披露。各组件归其各自作者所有。

| 组件 | 版本 | 许可证 | 用途 |
| --- | --- | --- | --- |
| [moonbitlang/core](https://github.com/moonbitlang/core) | 工具链内置 | Apache-2.0 | MoonBit 标准库 |
| [moonbitlang/async](https://github.com/moonbitlang/async) | 0.22.9 | Apache-2.0 | transport_async 异步 TCP/TLS 通道 |
| [cc06b/mooncry](https://github.com/cc06b/mooncry) | 0.95.0 | Apache-2.0 | transport_async 的 SHA-256（对端证书指纹钉扎）；0.2.0 国密通道基础 |

核心协议包（wire/arch/identity/registry/capability/discovery/aip/tooling/verify）不依赖上述任何第三方组件，仅依赖 moonbitlang/core。
