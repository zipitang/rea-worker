---
name: rea-workbench
description: Operate the local REA (Reverse Engineer Anything) workbench on this Windows machine. Use when a question depends on a shipped artifact (binary, package, APK, Electron/JS bundle, firmware, WASM, .NET assembly) rather than on available source, or when REA's MCP tools are missing, failing, or need provider readiness checks. Covers the D-drive deployment layout, target-to-tool routing, evidence discipline, Windows capability limits, and the authorization boundary.
metadata:
  version: "1.0.0"
  deployment: "D:/mycp/game/REA-worker"
  platform: "windows-x64"
---

# REA 工作台（本机部署版）

这不是 REA 官方文档的复述。官方通用说明已由 `reverse-engineer-anything` 提供；本 skill 只记录**这台机器上的真实事实**：装在哪、怎么起、哪些后端真的能用、哪些工具名是对的、什么算证据、什么不能碰。

## 零、先判断该不该用 REA

用 REA 的前提：结论必须落在**已发布的产物**或**运行期证据**上。

| 情形 | 用不用 REA |
|---|---|
| 有完整源码仓库，问架构、问某函数逻辑 | ❌ 不用。直接读源码，别启动分析引擎 |
| 只有 APK / EXE / DLL / .app / 打包后的 JS / 固件 | ✅ 用 |
| 源码与产物不一致，要证明「线上跑的到底是什么」 | ✅ 用（source-to-bundle 对比） |
| 要对比两个版本的产物差异 | ✅ 用 |
| 问「这个 Electron 应用怎么和主进程通信」 | ✅ 用（静态即可，不需要反汇编器） |

不要为了「保险」在每个逆向问题上都先跑一遍 doctor。**只在工具缺失或报错时才做就绪诊断。**

## 一、本机部署事实（已验证）

| 项 | 值 |
|---|---|
| REA 版本 | `rea-agents@6.5.0`（npm，MIT） |
| 安装形态 | **本地安装**（非全局），`--prefix` 落在 D 盘 |
| 运行时 | `D:\mycp\game\REA-worker\.runtime\node_modules\rea-agents\scripts\rea.mjs` |
| 启动器 | `D:\mycp\game\REA-worker\rea.cmd`（自动注入四个 env） |
| MCP 注册 | `~/.workbuddy/mcp.json` → `mcpServers.rea` |
| Schema 档位 | `REA_MCP_INPUT_SCHEMA_PROFILE=compact` |
| 工具数量 | 207（compact 档注册，调用时仍全量校验） |
| JDK | `D:\mycp\game\REA-worker\toolchain\jdk21\jdk-21.0.12.1+1` |
| Ghidra | `D:\mycp\game\REA-worker\toolchain\ghidra\ghidra_12.1.4_PUBLIC` |
| JADX 桥 | `D:\mycp\game\REA-worker\toolchain\android\jadx-headless-mcp-0.7.1-all.jar` |
| 磁盘 | D 盘约 1.8 GB；C 盘仅配置与 skill ≈ 95 KB |
| 正式 skill | `~/.workbuddy/skills/reverse-engineer-anything/`（官方，207 工具） |

**关键推论**：启动器指向 D 盘绝对路径，所以 WorkBuddy 升级内置 Node **不会**让注册失效。这是刻意设计的，别改成 `npm i -g`——那会把 516 MB 写回 C 盘。

## 二、四条 env 是能力开关

`mcp.json` 里 `rea` 条目已注入：

| 变量 | 解锁什么 | 缺失后果 |
|---|---|---|
| `JAVA_HOME` | JDK 21 定位 | Ghidra 与 JADX 全线不可用 |
| `GHIDRA_INSTALL_DIR` | 原生反汇编后端 | `procedure_pseudo_code` / `batch_decompile` 类工具失败 |
| `REA_JADX_MCP_JAR` | APK 反编译桥 | Android 反编译不可用，但 APK 元数据/资源仍可读 |
| `REA_MCP_INPUT_SCHEMA_PROFILE` | 上下文占用（compact） | 退回 full，约 496 KB schema 挤占上下文 |

手动跑 CLI 时不要手写这些 env——用 `rea.cmd`，它已经注入好了。详见 [provider-setup](references/provider-setup.md)。

## 三、目标路由：什么目标用什么工具

这是最高频的误用来源。**先认目标类型，再选工具链**，不要拿反汇编器去啃一个纯 JS 包。

### 3.1 走静态、零额外依赖（Windows 首选，今天就能用）

| 目标 | 入口工具 | 典型后续 |
|---|---|---|
| Electron / 打包 JS | `analyze_javascript_application` | `inspect_electron_page`、`inspect_electron_fuses`、`recover_javascript_sources`、`compare_source_to_bundle` |
| Web bundle | `analyze_web_bundle` | `compare_bundles`、`compare_javascript_export_shapes`、`export_web_scripts` |
| 浏览器站点行为 | `inspect_web_page`、`capture_browser_scenario` | `inspect_web_network_capture`、`inspect_web_event_listeners`、`trace_web_module_imports` |
| .NET 程序集 | `inspect_managed_artifact` | `inspect_managed_members`、`project_managed_application_graph` |
| Go 二进制 | `inspect_go_binary` | 符号/构建信息指纹 |
| Rust 二进制 | `inspect_rust_binary` | panic 字符串、crate 特征 |
| WASM | `inspect_wasm_artifact` | `compare_wasm_interfaces` |
| Android（仅元数据） | `inspect_android_package` | `decode_android_resources`、`search_android_classes` |
| 固件/归档 | `extract_firmware`、`inspect_firmware_regions` | `extract_artifact`、`inspect_keyed_archive` |
| 通用容器 | `binary_overview`、`list_segments`、`list_strings`、`search_strings` | 决定了后面走哪条路 |

### 3.2 需要 Ghidra（原生伪代码）

入口：`open_binary` → `list_architectures` / `list_procedures` → `procedure_pseudo_code` / `batch_decompile` / `get_call_graph`。

Windows 上仅**实验性只读 P0**：x86 / x64 / ARMNT / ARM64 的 **PE**，以及 raw 6502。**不要承诺**它能处理 Mach-O、ELF 或 exotic 架构。

### 3.3 需要 JADX（APK 反编译）

走 `inspect_android_package` → 类/方法级 `search_android_classes`、`inspect_android_method`、`trace_android_references`；反编译通过 JADX 桥。

### 3.4 本机未验证的通道

Frida 动态注入、GDB、rizin 调试、ADB 设备、mitmproxy/pcap、sigrok 信号解码——工具在，但**本机未装对应外部依赖，也未实跑过**。别声称「能抓运行时」，先在目标上试一次再下结论。

完整工具清单见 [tool-map](references/tool-map.md)。

## 四、证据纪律（这是 REA 的核心价值，不是附属品）

REA 的输出不是「我觉得」，是**可复现的证据**。

1. **每个结论都要挂 Evidence ID**。拿不到 ID 的断言，标成假设。
2. **同一目标跑两次，Evidence 哈希应一致**。不一致说明输入不稳定（时间戳、随机目录、并发），要说明原因。
3. **引用证据要能定位**：文件偏移、函数地址、字符串、模块路径——给到读者能自己复演的程度。
4. **静态与动态冲突时，先说冲突，不要选一个顺眼的**。用 `correlate_static_and_runtime` 对齐，冲突本身就是发现。
5. **区分「读到的」与「推断的」**。字符串里出现 `AES` 不等于它就是加密实现。

报告模板与证据导出见 [evidence-and-report](references/evidence-and-report.md)。

## 五、Windows 能力边界（别按 macOS 的预期答）

| 能力 | Windows 状态 |
|---|---|
| Hopper 反汇编 | ❌ 不支持（macOS only） |
| Ghidra 原生伪代码 | ⚠️ 实验性只读 P0，仅 PE + raw 6502，且要求 NTFS 卷 |
| Binwalk / Unblob | ❌ Linux 专属（用 `extract_firmware` 的通用路径替代） |
| TShark / pcap 深度解析 | ❌ Linux 专属 |
| sigrok 信号解码 | ❌ Linux 专属 |
| mitmproxy 抓包 | ❌ Linux 专属 |
| JADX（APK） | ✅ 已就绪 |
| JS/Electron / .NET / Go / Rust / WASM / 站点 | ✅ 已就绪 |

遇到「本机做不到」时，**直接说做不到 + 给出替代路径**，不要用降级结果伪装成完整结论。

## 六、合规红线（硬约束，不接受讨价还价）

- 只分析**你自己拥有、或已获明确授权**的软件。
- 商业工具（IDA Pro / Hex-Rays、Hopper、JEB）必须自行合法取得授权。REA **不提供任何密钥、激活或绕过手段**。
- 不协助：绕过授权校验、破解付费功能、提取他人密钥、制作外挂、规避 DRM。
- 分析第三方软件时，默认按**互操作性研究 / 安全评估**处理，并在报告中写明授权依据。
- 产出物（证据包、反编译片段）可能含敏感信息，交付前提示用户注意流转范围。

用户请求越界时：说明边界，把需求收敛到「你可以合法分析的那部分」，继续把能做的做完。

## 七、故障排查（按这个顺序，别乱试）

| 现象 | 判定 | 处置 |
|---|---|---|
| 连接器列表里找不到 `rea` | 找错入口。那个网格只放官方市场连接器 | 右上角「自定义连接器」→「MCP 服务管理」→ 找 `rea` → 信任 |
| 自定义连接器面板里连 `blender` 都没有 | `mcp.json` 未被读取 | 改用项目级 `.workbuddy/mcp.json` |
| 面板里有 `blender` 没有 `rea` | 条目级问题（多为 env 校验） | 先删 env 试最小条目，再逐条加回 |
| 注册项正常但会话里没有 `mcp__rea__*` | 未重启 / 未信任 | 完全退出重启，`doctor` 无法证明活跃连接 |
| provider 报 unhealthy | env 未注入到进程 | 用 `rea.cmd` 起，或检查 `mcp.json` 的 `env` |
| 分析跑通但结果为空 | 目标类型判断错（如拿 Ghidra 啃纯 JS） | 回 §3 重新路由 |

诊断命令：

```bash
cd /d/mycp/game/REA-worker
./rea.cmd --version
./rea.cmd doctor --client workbuddy --json
./rea.cmd doctor --provider ghidra --json
./rea.cmd doctor --provider jadx --json
```

`doctor` 只看**文件与前缀条件**，不证明当前会话已连上。这条区别能省掉大量无效排查。

## 八、工作方式

1. **先定目标类型**，再选工具链，写清「这次要证明什么」。
2. **最小充分证据**：能用一个字符串证明的，不要跑全量反汇编。
3. **不可逆动作先说明**：解包、写文件、启动进程、连接设备——先讲影响再执行。
4. **结论分级**：已证实 / 高置信推断 / 未验证假设，三档分开写。
5. **交付要有复现路径**：命令、样本标识、Evidence ID。

## References

- [tool-map.md](references/tool-map.md) — 207 个工具按能力域分组（真实工具名）
- [provider-setup.md](references/provider-setup.md) — 四个 env、JDK/Ghidra/JADX 安装与校验
- [windows-limits.md](references/windows-limits.md) — 平台能力矩阵与降级策略
- [evidence-and-report.md](references/evidence-and-report.md) — 证据导出与报告骨架
