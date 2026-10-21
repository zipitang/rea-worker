# REA Worker — 本地逆向分析环境

> 部署完成日期：2026-10-17　|　REA 版本：**6.5.0**　|　License：MIT
> 上游：https://github.com/morluto/rea

## 一句话

WorkBuddy 现在通过 MCP 接入 REA 的 **207 个逆向工具**，全部组件安装在 **D 盘**，C 盘仅占约 **95 KB** 配置。

---

## 1. 磁盘布局（为什么这样放）

| 位置 | 内容 | 占用 |
|---|---|---|
| `D:\mycp\game\REA-worker\.runtime\` | rea-agents 运行时（Node 依赖） | 516 MB |
| `D:\mycp\game\REA-worker\toolchain\jdk21\` | Temurin JDK 21.0.12.1 | 329 MB |
| `D:\mycp\game\REA-worker\toolchain\ghidra\` | Ghidra 12.1.4 PUBLIC | 875 MB |
| `D:\mycp\game\REA-worker\toolchain\android\` | jadx-headless-mcp 0.7.1 JAR | 41 MB |
| `D:\mycp\game\REA-worker\.cache\npm\` | npm 缓存（重定向，避开 C 盘） | 75 MB |
| `C:\Users\...\.workbuddy\mcp.json` | MCP 注册（1.2 KB） | ← 必要配置 |
| `C:\Users\...\.workbuddy\skills\reverse-engineer-anything\` | 调查工作流指令 | 92 KB |

**没有使用 `npm i -g`**：全局安装会写进 `C:\...\node\versions\22.22.2-6\node_modules`，且 Node 版本一升级路径就失效。改为 workspace 内固定路径安装，同时避开 C 盘与版本漂移。

---

## 2. 已装组件

| 组件 | 版本 | 用途 |
|---|---|---|
| rea-agents | 6.5.0 | MCP 服务器（stdio） |
| Temurin JDK | 21.0.12.1+1 LTS | Ghidra 与 JADX 的共同前置（含 javac） |
| Ghidra | 12.1.4 PUBLIC | 原生反汇编 / 伪代码 |
| jadx-headless-mcp | 0.7.1 | APK 反编译桥接 |

JADX JAR 按 REA 官方钉死的 SHA-256 校验通过：
`6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`

---

## 3. MCP 注册内容

`~/.workbuddy/mcp.json` 中的 `rea` 条目：

```json
"rea": {
  "command": "C:\\Users\\Administrator\\.workbuddy\\binaries\\node\\versions\\22.22.2-6\\node.exe",
  "args": [
    "D:\\mycp\\game\\REA-worker\\.runtime\\node_modules\\rea-agents\\scripts\\rea.mjs",
    "mcp"
  ],
  "env": {
    "REA_MCP_INPUT_SCHEMA_PROFILE": "compact",
    "JAVA_HOME": "D:\\mycp\\game\\REA-worker\\toolchain\\jdk21\\jdk-21.0.12.1+1",
    "GHIDRA_INSTALL_DIR": "D:\\mycp\\game\\REA-worker\\toolchain\\ghidra\\ghidra_12.1.4_PUBLIC",
    "REA_JADX_MCP_JAR": "D:\\mycp\\game\\REA-worker\\toolchain\\android\\jadx-headless-mcp-0.7.1-all.jar"
  }
}
```

`compact` 把工具 schema 从约 496 KB 压到约 290 KB —— 207 个工具全量暴露会显著挤占上下文。

---

## 4. 启用步骤（需你手动完成一次）

> ⚠️ **常见误会**：`rea` **不会**出现在连接器列表（那个网格只列官方市场连接器）。
> 自定义 MCP 在**右上角独立的「自定义连接器」入口**里。

1. **完全退出并重启 WorkBuddy**（配置只在启动时读取）
2. 左侧边栏 → **专家·技能·连接器** → **连接器**
3. 页面**右上角** → 点 **「自定义连接器」** → 打开「MCP 服务管理」
4. 在列表里找到 **`rea`** → 点 **「信任」**
5. 状态变为已启用后，新会话中即可看到 `mcp__rea__*` 工具

> REA 官方文档记录：WorkBuddy 的注册加载与真实工具调用已通过验证。但**必须重启**，`doctor` 只检查文件与前缀条件，不检测活跃连接。

### 如果「MCP 服务管理」里连 `blender` 都看不到

说明面板没有读到 `~/.workbuddy/mcp.json`。此时改用**项目级**配置：

在 `D:\mycp\game\REA-worker\.workbuddy\mcp.json` 新建同名文件，内容与第 3 节 `rea` 条目一致（外层套 `{"mcpServers": {...}}`）。项目级与用户级不要同时定义 `rea`，避免重复注册。

---

## 5. 验证命令

在本目录打开终端（`rea.cmd` 会自动注入四个环境变量）：

```bat
rea.cmd --version                    :: 6.5.0
rea.cmd doctor --client workbuddy --json
rea.cmd doctor --provider ghidra --json
rea.cmd doctor --provider jadx --json
rea.cmd capabilities
```

实测结果（部署当日）：

| 检查 | 结果 |
|---|---|
| `doctor --client workbuddy` | `healthy: true`，skill `aligned`，207 tools |
| `doctor --provider ghidra` | `healthy: true` → `ghidra_12.1.4_PUBLIC` |
| `doctor --provider jadx` | `healthy: true`，JAR 结构校验通过 |
| 冒烟：静态分析自建 Electron 样本 | 通过，`evidence_id` 稳定可复现 |

冒烟样本在 `samples/smoke-app/`，重跑：

```bat
rea.cmd analyze-javascript-application "D:\mycp\game\REA-worker\samples\smoke-app" --json
```

结果正确识别出 IPC 通道 `read-config` 与 `contextBridge` 边界。

---

## 6. 能力矩阵（Windows 实际可用）

| 能力 | 状态 | 依赖 |
|---|---|---|
| JS / Electron 静态分析 | ✅ 已验证 | 内置 |
| .NET 程序集元数据 + CIL | ✅ 可用 | 内置 |
| Go / Rust 二进制指纹 | ✅ 可用 | 内置 |
| WASM / EVM / SQLite | ✅ 可用 | 内置 |
| 网站结构与网络观察 | ✅ 可用 | 需 Chrome 系浏览器 |
| Android APK 反编译 | 🟡 已配置，未实跑 | JDK + JADX JAR |
| 原生 x86/x64/ARM PE 分析 | 🟡 已配置，未实跑 | Ghidra（**Windows 实验性只读 P0**） |
| Hopper | ❌ 不支持 Windows | — |
| 固件 / 抓包 / 逻辑信号 / mitmproxy | ❌ 仅 Linux | Binwalk · TShark · sigrok |

> Ghidra 在 Windows 上是 **P0 只读**边界：仅 x86/x64/ARMNT/ARM64 PE 及显式 raw NMOS 6502 镜像，且需固定 NTFS 卷。不要期待与 Linux/macOS 同等的覆盖面。

---

## 7. 故障排查

**工具在会话里看不到**
→ 没重启，或没在连接器管理页点「信任」。

**MCP 启动失败 / 找不到 rea.mjs**
→ 检查 `.runtime\node_modules\rea-agents\scripts\rea.mjs` 是否存在。若 WorkBuddy 升级了内置 Node，`.workbuddy\binaries\node\versions\...` 路径会变，重跑第 8 节的重装。

**`doctor` 报 provider 未配置，但 MCP 里明明写了 env**
→ doctor 读的是**当前进程**环境变量，不是 `mcp.json` 的 env 块。用 `rea.cmd` 运行即可，或在终端手动 `set JAVA_HOME=...`。

**上下文被吃掉 / 响应变慢**
→ 确认 `REA_MCP_INPUT_SCHEMA_PROFILE` 仍是 `compact`。如果仍紧张，可在会话中只启用需要的工具子集。

**Ghidra 启动超时（大二进制）**
→ 设 `REA_GHIDRA_STARTUP_TIMEOUT_MS`（如 `180000`）与 `GHIDRA_HEADLESS_MAXMEM`。

---

## 8. 重装 / 升级

```bat
:: 重装运行时（不动 toolchain）
rmdir /s /q D:\mycp\game\REA-worker\.runtime
npm install --prefix "D:/mycp/game/REA-worker/.runtime" --cache "D:/mycp/game/REA-worker/.cache/npm" --no-audit --no-fund rea-agents@6.5.0

:: 重新注册（会保留其他 MCP server）
node "D:\mycp\game\REA-worker\.runtime\node_modules\rea-agents\scripts\rea.mjs" setup --client workbuddy --yes

:: 然后重新注入第 3 节的 env 块，重启 WorkBuddy
```

> 网络注意：本机代理会拦 `github.com` 主域，但放行 `api.github.com` 与 `objects.githubusercontent.com`。
> 下载 GitHub Release 资产请走 API asset 端点：
> `curl -L -H "Accept: application/octet-stream" "https://api.github.com/repos/<owner>/<repo>/releases/assets/<id>"`

原始安装包（739 MB）在部署后已清理。如需重下：

| 组件 | 地址 |
|---|---|
| JDK 21 | `adoptium/temurin21-binaries` → `jdk-21.0.12.1+1` |
| Ghidra | `NationalSecurityAgency/ghidra` → `Ghidra_12.1.4_build` |
| JADX JAR | `1013503897/jadx-headless-mcp` → `v0.7.1` |

---

## 9. 回滚

```bat
:: 仅移除 REA 的注册与 skill
node "D:\...\rea.mjs" uninstall

:: 额外清理缓存与状态
node "D:\...\rea.mjs" uninstall --purge-data
```

兜底：用备份直接覆盖配置，恢复到部署前状态：

```bat
copy /Y "C:\Users\Administrator\.workbuddy\mcp.json.rea.backup.manual" "C:\Users\Administrator\.workbuddy\mcp.json"
```

备份文件：
- `~/.workbuddy/mcp.json.rea.backup.manual` —— 部署前手工快照（sha256 `e262ebe3...4372`）
- `~/.workbuddy/mcp.json.rea.backup` —— setup 自动快照

彻底删除 D 盘占用：直接删除整个 `D:\mycp\game\REA-worker`（1.8 GB）。

---

## 10. 合规边界（硬约束）

1. 仅分析**你拥有**或**已获书面授权**的软件；用于互操作研究、教育、软件保存。
2. 不用于绕过授权校验、破解 DRM、分发盗版。
3. IDA Pro / Hex-Rays、Hopper、JEB 等商业工具须自行合法取得授权；REA 不提供任何密钥或激活。
4. 分析全程本地执行，样本不上传第三方；`Evidence` 与缓存属本地敏感数据。
5. 本机**未**接入 IDA（本次明确排除）。
