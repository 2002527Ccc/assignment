# Task02 GitHub 交付核验

核验日期：2026-10-30。

本次沿用远程 `task02-finalediagnostics` 分支已有提交
`f59e150effe91d362c3b0cefb66c47e67ab74cec` 中的全部 Task02 交付。
没有重新构建 ZIP，没有修改已有源码、Diff、README、哈希清单或验证报告。
本次只新增这份交付核验说明。

## 可直接从 GitHub 获取的文件

- [Vortex 诊断安装包](CHRONOS_TASK02_FinaleDiagnostics_V0.1.0.zip)
- [完整源码与审查包](CHRONOS_TASK02_Source_and_Review.zip)
- [完整 Diff](CHRONOS_V032_to_TASK02.diff)
- [中文 README](README_zh.md)
- [原有验证报告](VALIDATION.md)
- [原有哈希清单](SHA256_MANIFEST.json)
- [完整安装文件树](patch/)
- [新增诊断源码](source/)

ZIP 在 GitHub 文件页面可通过 Download raw file 下载。两个 ZIP 的用途不同；
源码审查包不是 Vortex 安装包。安装、依赖、回退步骤以原 README 为准。

## 本次实际执行的检查

- 两份既有 ZIP 的 CRC 检查均通过。
- 安装 ZIP 的 6 个路径及各文件字节均与仓库 `patch/` 对应文件一致。
- 源码审查 ZIP 中的 `install_tree/` 与仓库 `patch/` 对应文件字节一致。
- `source/` 中三个诊断源文件与实际安装目录中的副本一致。
- `patch/` 的全部 6 个 SHA-256 与已有 `SHA256_MANIFEST.json` 一致。
- 重新执行既有 `test_lua.py`：Lua 5.4 解析、模拟宿主生命周期及 JSONL
  序列化检查通过；这不是游戏或 CET 实机测试。
- 本次未执行 `build.py`。由于本实例没有该 Task02 原始 CHRONOS 解压基线，
  没有重新执行依赖完整基线的 `verify.py`；原验证报告保持原样，不冒称重跑通过。
- 未执行 redscript 游戏编译、Cyberpunk 2077、CET 或 Vortex 实机测试。

## 两份保留 ZIP 的完整 SHA-256

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `CHRONOS_TASK02_FinaleDiagnostics_V0.1.0.zip` | 17055 | `41ae8c7d71da10e032b17cf4346fe919756f0ce7b1268b70d2b48e9a21cf2183` |
| `CHRONOS_TASK02_Source_and_Review.zip` | 54687 | `0bc8bca3c9aa0dbf91f69e4970dd0f3c6215ff24769d8886ebbadfc430953938` |

既有 ZIP 未纳入这份新说明，也没有为添加说明而重新压缩。
GitHub 是否已收到本次提交，需要以成功推送及远程提交核验为准；本文件的存在本身不证明推送成功。
