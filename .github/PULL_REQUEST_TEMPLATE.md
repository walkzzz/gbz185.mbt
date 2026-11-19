## 变更内容

（一句话说明 + 对应 GB/Z 185 部分编号 / issue 编号）

## 验证

- [ ] `moon check --deny-warn --target all` 零警告
- [ ] `moon test --target native|js|wasm|wasm-gc` 全绿
- [ ] `moon fmt && moon info` 且 `.mbti` diff 已提交
- [ ] `moon prove`（WSL/CI 通道）全 proved
- [ ] `bash scripts/local_ci.sh` 通过（与 CI jobs 对齐）
- [ ] 涉及协议语义：docs/TEST_REPORT.md 与 docs/known-gaps.md 口径已同步

## 说明

（破坏性变更 / 迁移指引 / 证据链）