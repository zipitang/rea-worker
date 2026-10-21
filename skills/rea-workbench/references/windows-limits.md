# Windows 平台能力边界

REA 的能力矩阵**不做跨平台对齐**。同一套工具名，在 macOS、Linux、Windows 上能做的事差别很大。
把 macOS 的预期搬到 Windows 上，是这一套工具最常见的误判来源。

---

## 一、能力矩阵

| 能力 | Windows | 说明 |
|---|---|---|
| JS / Electron / Web bundle 静态分析 | ✅ 完整 | 纯 JS 解析，无外部引擎依赖 |
| 站点行为与网络观测 | ✅ 完整 | 走浏览器通道 |
| .NET 程序集 | ✅ 完整 | 托管元数据直接读 |
| Go / Rust 二进制指纹 | ✅ 完整 | 符号与构建信息 |
| WASM / EVM / SQLite / plist / 归档 | ✅ 完整 | 格式解析层 |
| APK 反编译（JADX） | ✅ 就绪 | 需 JDK + 桥 JAR，本机已装 |
| APK 元数据 / 资源 / 类检索 | ✅ 就绪 | 不依赖 JADX 也可部分可用 |
| Ghidra 原生伪代码 | ⚠️ 实验性只读（P0） | 仅 x86/x64/ARMNT/ARM64 的 **PE**，加 raw 6502 |
| Hopper 反汇编 | ❌ 无 | macOS only，Windows 上不存在这个后端 |
| Binwalk / Unblob 固件解包 | ❌ 无 | Linux 专属；改用 `extract_firmware` 通用路径 |
| TShark / 深度 pcap 解析 | ❌ 无 | Linux 专属 |
| sigrok 信号解码 | ❌ 无 | Linux 专属 |
| mitmproxy 抓包 | ❌ 无 | Linux 专属 |
| ADB 设备族 | ❌ 未装 | 工具在，缺 `adb` 与真机 |
| Frida 动态注入 | ⚠️ 未验证 | 工具在，未装服务端，未实跑 |
| GDB / rizin 调试 | ⚠️ 未验证 | 同上 |

---

## 二、Ghidra 在 Windows 上的真实限制

这四条会直接影响你能不能给结论：

1. **只读**。不能改符号、不能 patch、不能持久化分析结果到项目。
2. **只认 PE**。ELF、Mach-O、部分容器格式走不通。macOS/Linux 上的分析路径在这里不成立。
3. **架构窄**：x86 / x64 / ARMNT / ARM64，外加 raw 6502。MIPS、PowerPC、RISC-V 等没有保证。
4. **要求 NTFS 卷**。网络盘、exFAT、部分虚拟挂载会失败。

首次调用会构建脚本缓存，可能几分钟无输出。**不要误判为卡死并中断**。

---

## 三、能力不足时的降级策略

原则：**降级要说明，不能静默降级**。

| 做不到 | 可替代路径 | 报告里怎么写 |
|---|---|---|
| 无 Ghidra 伪代码 | `inspect_with_objdump` 拿汇编 + 人工解读 | 「伪代码不可得，以下为汇编级推断」 |
| 无 Hopper | 无替代（Windows 无此后端） | 「该后端仅 macOS 可用」 |
| 无 Binwalk | `extract_firmware` / `inspect_firmware_regions` | 「使用通用解包，未经签名库匹配」 |
| 无 TShark | `inspect_pcap_capture` 的基础解析 | 「仅基础层解析，未做协议深度解码」 |
| 无 ADB | 只做 APK 静态 | 「设备端行为未验证，仅静态结论」 |
| 无 Frida | 静态 + 字符串/调用图推断 | 「运行时未观测，以下为静态推断」 |

**禁止**：把静态推断写成「运行时行为已确认」；把 objdump 的汇编解读写成「反编译结果」。

---

## 四、路径与编码

- 首选全 ASCII 路径。Ghidra 与分析脚本对非 ASCII 路径容错差。
- 本机部署目录 `D:\mycp\game\REA-worker` 已满足此条件，样本也放这下面。
- 反斜杠在 JSON 里要转义（`\\`）；写 `mcp.json` 时别手抖。
- 长路径（>260 字符）在深层解包时可能触发限制，必要时缩短中间目录。

---

## 五、性能现实

| 操作 | 量级 |
|---|---|
| 加载大 PE + 全量分析（Ghidra） | 分钟级，取决于体积 |
| `batch_decompile` 上百函数 | 数分钟起 |
| Electron 应用全量分析 | 十秒级到分钟级 |
| 单文件字符串/符号枚举 | 秒级 |

长任务放后台，别在前台干等。跑之前先估规模，别对 500 MB 的二进制直接全量反编译。
