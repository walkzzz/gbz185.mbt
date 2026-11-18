# 贡献指南（Contributing to gbz185.mbt）

感谢关注 GB/Z 185-2026 MoonBit 协议栈。本指南说明如何参与贡献。

## 开发环境

1. 安装 MoonBit 工具链（[官方教程](https://docs.moonbitlang.cn/)）：
   - Linux/macOS：`curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash`
   - Windows：`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; iex (irm https://cli.moonbitlang.com/install/powershell.ps1)`
2. 形式化验证（可选）：安装 [Z3](https://github.com/Z3Prover/z3/releases)（SMT solver）并设置 `Z3PATH`
3. 克隆仓库：`git clone git@github.com:walkzzz/gbz185.mbt.git`

## 质量门禁（合入前必须全绿）

```bash
moon check --deny-warn --target all   # 四目标编译零警告
moon test                             # 全部测试通过
moon info                             # .mbti 契约更新（公开 API 变更时）
moon fmt                              # 格式化
moon prove                            # 形式化证明义务（需 Z3）
```

- `.mbti` 契约：公开 API 变更必须 `moon info` 更新并评审 diff
- 新增 `pub` 定义：`///` 文档注释（中文 + English 双语）
- 新增 `#derive(Eq, Debug)` 类型：须配 `pub extend T with Eq::{...}` 与 `Debug::{to_repr}` 显式声明

## 编码规范

- 新格式 `moon.mod`/`moon.pkg`（旧 JSON 格式已弃用）
- 测试专用依赖写 `import { ... } for "test"` 独立段
- 错误处理：`pub(all) suberror` 分型 + `ProtocolError` 特征统一（part/code/message）
- wire 数字字段：`Json::number(x.to_double())`（Int64 ToJson 序列化为字符串）
- 详见 `docs/TEST_REPORT.md` 与根目录 COD 规范引用

## 提交流程

1. Fork → 特性分支（`feat/xxx`）
2. 提交前跑全部门禁命令
3. Pull Request → CI 全绿（check/contract/prove/test 四类 job）
4. 变更记录补入 `CHANGELOG.md`

## 反馈渠道

- GitHub Issues（缺陷/特性请求）
- GB/Z 185-2026 标准语义问题请附标准文本引用
