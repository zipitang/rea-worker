# DESIGN.md — REA（Reverse Engineer Anything）本地部署方案

> 版本：v1.0　|　日期：2026-10-17　|　状态：**待用户确认**
> 项目目录：`D:/mycp/game/REA-worker`
> 上游：https://github.com/morluto/rea（npm 包 `rea-agents@6.5.0`，MIT）

---

## 1. 需求本质

**要解决的问题**：让当前 WorkBuddy 会话具备「无源码逆向理解」能力——能检查二进制、JS/Electron 应用、.NET 程序集、APK、网站等目标，输出带证据的功能说明。

**不是要解决的问题**（明确排除，避免范围蔓延）：
- 不做远程/多用户服务化部署（REA 只支持 stdio 传输）
- 不改写 REA 源码、不参与其测试套件（源码仅可选留档）
- 不绕过任何商业工具授权

---

## 2. 需求确认（已拍板）

| 决策项 | 结论 | 来源 |
|---|---|---|
| 部署形态 | **全局安装 + 官方 `rea setup`**（注册指向本地启动器，非每次 `npx`） | 用户确认 |
| 分析后端 | **静态能力 + Ghidra + JADX/JDK**；**不接 IDA** | 用户确认 |
| 工具暴露 | **`compact` 精简 schema** | 用户确认 |
| 合规边界 | **仅分析自有或已获授权软件**，接受上游 `DISCLAIMER.md` | 用户确认 |

---

## 3. 现状基线（只读探测结果）

| 项 | 实测 | 判定 |
|---|---|---|
| OS | Windows 11 专业版 26200 | ✅ |
| Node.js | v22.22.2 | ✅ 满足 `^22.19.0 \|\| ^24.11.0 \|\| >=26.0.0` |
| npm | 10.9.7 | ✅ |
| npm 全局根 | `C:\Users\Administrator\.workbuddy\binaries\node\versions\22.22.2-6\node_modules` | ⚠️ 见 R3 |
| `~/.workbuddy/mcp.json` | 已存在，含 `blender`、`lighthouse-ops` | ⚠️ 必须保留 |
| `~/.workbuddy/skills/` | 已存在，约 30 个 skill | ✅ 目标目录就绪 |
| `~/.rea` | 不存在 | ✅ 全新安装 |
| JDK | **无**（`java: command not found`，`JAVA_HOME` 空） | ❌ R1 |
| Ghidra | **无**（`GHIDRA_INSTALL_DIR` 空，常见路径均不存在） | ❌ R1 |
| JADX / adb / apktool | **均无** | ❌ R1 |
| D 盘余量 | 174 GB | ✅ |

---

## 4. 技术选型

### 4.1 决策：全局安装 + 官方 setup

```bash
npm install --global rea-agents@6.5.0
rea setup --client workbuddy --yes --json
```

**理由**：
1. 官方 `setup` **原生支持 `workbuddy` 客户端**，文档明确记录「Loading this registration and real REA tool calls through WorkBuddy are verified」——走官方路径，出问题有据可查；
2. setup 以 **upsert** 方式写入 `mcpServers.rea`，保留其他 server 与顶层键，并有 `.rea.backup` 快照机制；
3. 全局安装后注册项指向**本地启动器绝对路径**，无冷启动联网拉包；
4. `rea uninstall` 提供精确、可审计的回滚，不误伤 Node / Hopper / 其他 MCP。

### 4.2 备选方案与为何不选

| 备选 | 不选原因 |
|---|---|
| npx 直连（官方默认） | 每次冷启动联网拉包，离线不可用，二次启动明显变慢 |
| 源码克隆 + `npm ci` + `turbo build` | 构建链重（tsc + turbo + 原生构件），属「开发」而非「部署」；对「把工具用起来」无增量收益 |

### 4.3 已知取舍：全局根的路径脆弱性

注册项会写入形如
`node C:\Users\...\node\versions\22.22.2-6\node_modules\rea-agents\scripts\rea.mjs mcp`
的绝对路径。若 WorkBuddy 升级内置 Node 版本，该路径失效 → **缓解见 R3**。

> 备选加固（若确认需要长期稳定）：改用 `npm i --prefix D:/mycp/game/REA-worker/.runtime rea-agents@6.5.0`，注册指向 workspace 内固定路径，不随 Node 升级漂移。**默认不做**，除非用户要求。

---

## 5. 部署架构

```
WorkBuddy 客户端
      │  MCP stdio（Windows 下由 setup 包装为 cmd.exe /d /c）
      ▼
~/.workbuddy/mcp.json  ──►  mcpServers.rea  ──►  node <global>/rea-agents/scripts/rea.mjs mcp
~/.workbuddy/skills/reverse-engineer-anything/     （172 个工具，compact schema）
      │
      ▼
分析后端：静态引擎（内置） | Ghidra（P0 只读） | JADX+JDK
```

**配置文件变更模型**（唯一被写入的外部文件）：

```jsonc
// ~/.workbuddy/mcp.json  —— 仅新增 rea 键，其余原样保留
{
  "mcpServers": {
    "blender": { /* 原样保留 */ },
    "lighthouse-ops": { /* 原样保留 */ },
    "rea": {
      "command": "cmd.exe",
      "args": ["/d", "/c", "<全局启动器绝对路径>", "mcp"],
      "env": { "REA_MCP_INPUT_SCHEMA_PROFILE": "compact" }
    }
  }
}
```

> `command`/`args` 的最终形态由 `rea setup` 决定，我在实施时按其 `--dry-run` 输出核对，**不臆造字段**。

---

## 6. 阶段划分（因依赖缺口而切分）

### 阶段一：静态能力上线（本次必做，无额外下载）

覆盖能力：**JS/Electron**、**.NET 程序集**、**Go/Rust 二进制指纹**、**WASM**、**EVM 字节码**、**SQLite**、**网站结构**、**Flutter 静态解析**、**包与资源清单**。
这些均**不需要** Ghidra / JDK / adb，安装即用。

### 阶段二：原生与 Android 能力（需用户批准下载，约 1.2 GB）

| 依赖 | 用途 | 体积 | Windows 限制 |
|---|---|---|---|
| JDK 21 (Temurin) | JADX 与 Ghidra 的共同前置 | ~190 MB | — |
| Ghidra 11.x | 原生伪代码/汇编 | ~400 MB | **实验性只读 P0**：仅 x86/x64/ARMNT/ARM64 PE + raw NMOS 6502，需固定 NTFS 卷 |
| JADX headless | APK 反编译 | 由 REA 链管理或自备 | 需完整 JDK |

**若不做阶段二**：`binary_session` 的风险分析能力缺失，但静态链路完全可用。**这是可接受的降级**。

---

## 7. 验收标准（Definition of Done）

| # | 判据 | 命令 / 检查 |
|---|---|---|
| AC1 | 版本正确 | `rea --version` → `6.5.0` |
| AC2 | 注册健康 | `rea doctor --client workbuddy --json` → `scope.mode: "explicit"` 且 healthy |
| AC3 | 不破坏既有配置 | `mcp.json` 中 `blender`、`lighthouse-ops` 逐字节保留；含 `mcpServers.rea` |
| AC4 | skill 落位 | `~/.workbuddy/skills/reverse-engineer-anything/SKILL.md` 存在 |
| AC5 | 客户端可见 | 重启 WorkBuddy 后连接器面板出现 `rea`，授权后 `tools/list` 非空 |
| AC6 | 冒烟通过 | 对 workspace 内**自建**测试文件跑一次静态分析，返回含证据的结果 |

---

## 8. 风险登记

| ID | 风险 | 影响 | 缓解 |
|---|---|---|---|
| **R1** | 本机无 JDK / Ghidra / JADX（已实测） | 你选的 Ghidra + JADX **阶段一不可用** | 阶段一先上线静态能力；阶段二需你批准下载 ~1.2 GB |
| **R2** | 172 工具全量 schema ≈ 496 KB | 长会话上下文被挤占、可能触发压缩抖动 | 已选 `compact`（≈290 KB），并写入 `env` 固化 |
| **R3** | 注册项指向 Node 版本目录绝对路径 | WorkBuddy 升级内置 Node 后路径失效，MCP 启动失败 | 文档化重装命令；如需长期稳定改用 workspace 内 `.runtime` 安装 |
| **R4** | setup 会改写 `~/.workbuddy/mcp.json` | 配置损坏风险 | 事前手工备份 `.rea.backup.manual`；setup 自身亦有快照 + sha256 recovery |
| **R5** | Windows 能力打折 | Hopper 不可用；Linux 专属（Binwalk/TShark/sigrok/mitmproxy）全缺 | 已在文档标注，不承诺这些能力 |
| **R6** | MCP 需客户端「信任」才加载 | 安装完成但工具不可见 | 明确指引在连接器管理页对新 server 点「信任」并重启 |

---

## 9. 合规与安全边界

1. **用途限定**：仅分析**自有**或**已书面授权**的软件；用于互操作研究、教育、软件保存。不用于破解授权校验、绕过 DRM、分发盗版。
2. **商业工具**：IDA Pro / Hex-Rays、Hopper、JEB 必须由用户合法取得并持有授权；REA 不提供任何密钥、激活或试用绕过。
3. **数据面**：分析全部在本地执行，不上传目标样本到第三方。`~/.rea` 缓存含分析证据，属本地敏感数据。
4. **密钥**：不写入任何密钥到代码、日志或本仓库。
5. **落盘范围**：仅 `~/.workbuddy/mcp.json`、`~/.workbuddy/skills/`、`~/.rea/`、本 workspace。

---

## 10. 回滚

```bash
rea uninstall                # 仅删 REA 自己的注册与 skill
rea uninstall --purge-data   # 额外清 ~/.rea 缓存与状态
```

兜底：用 `.rea.backup.manual` 覆盖 `~/.workbuddy/mcp.json` 即可还原到部署前状态。
`rea uninstall` 遇配置畸形会**先中止**而非破坏性删除；不触碰 Hopper / Node / 其他 MCP。

---

## 11. 用户确认结果

- [x] 认可本方案（阶段一 + 阶段二一起执行）
- [x] 批准阶段二下载（**实测约 739 MB 压缩包，解压后 1.2 GB**，低于预估）
- [x] **追加约束：不得占用 C 盘** → 触发方案变更，见 §12-1
- [ ] 源码 zip 留档：未要求，暂不下载

---

## 12. 实施记录（2026-10-17）

### 12-1 方案变更：全局安装 → workspace 本地安装

**触发**：用户要求「不要占用我的 C 盘」。

**原方案** `npm i -g rea-agents@6.5.0` 会把包写进
`C:\Users\...\node\versions\22.22.2-6\node_modules`（约 516 MB），且这正是 §8 R3 的脆弱路径。

**实际采用**：

```
npm install --prefix D:/mycp/game/REA-worker/.runtime \
            --cache   D:/mycp/game/REA-worker/.cache/npm \
            rea-agents@6.5.0
```

**收益**：C 盘占用从 516 MB → **95 KB**；同时一举消除 R3（注册项路径不再随 Node 升级漂移，因为启动器在 D 盘固定位置）。

`rea setup` 的 dry-run 输出确认了它按本地安装位置生成了启动器绝对路径，未使用 `npx`，因此**无冷启动联网依赖**。

### 12-2 环境实测偏差

| 原假设 | 实测 | 处理 |
|---|---|---|
| 阶段二约 1.2 GB | 压缩包 739 MB / 解压 1.2 GB | 符合，无需调整 |
| Ghidra 11.x | 最新稳定 12.1.4 | 采用 12.1.4，doctor 明确接受 `12.1.x` |
| JADX 由 REA 管理 | **REA 不下载，须自备 `jadx-headless-mcp 0.7.1` JAR** | 新增下载项，按官方钉死 SHA-256 校验通过 |

### 12-3 网络故障与绕过

**现象**：`github.com` 主域经代理超时（`CONNECT tunnel failed, 502`），但 `api.github.com`、`objects.githubusercontent.com`、`release-assets.githubusercontent.com` 均可达。

**根因**：Release 下载需先命中 `github.com` 的 302，主域被挡即整体失败。

**绕过**：改走 GitHub API 资产端点，由 API 直接 302 到可达的 release-assets 域：

```bash
curl -L -H "Accept: application/octet-stream" \
  "https://api.github.com/repos/<owner>/<repo>/releases/assets/<asset_id>"
```

> `asset_id` 需先查 `/releases/tags/<tag>` 获取。此路径已写入 README §8 供复用。

### 12-4 验收实测

| 判据 | 结果 |
|---|---|
| AC1 版本 | ✅ 6.5.0 |
| AC2 `doctor --client workbuddy` | ✅ `healthy: true`，skill `aligned`，207 tools |
| AC3 既有配置 | ✅ `blender` / `lighthouse-ops` 零改动 |
| AC4 skill 落位 | ✅ 92 KB |
| AC5 客户端可见 | 🟡 **待用户重启 WorkBuddy 并点「信任」** |
| AC6 冒烟 | ✅ 自建 Electron 样本，IPC `read-config` + `contextBridge` 均被识别，Evidence 哈希可复现 |

### 12-5 遗留限制（如实记录）

1. **Ghidra 未实跑**：Windows P0 只读，且手头无自有 PE 样本，仅验证到 doctor 就绪。
2. **JADX 未实跑**：同上，无自有 APK 样本。
3. 这两项从「已配置」到「已验证」需要真实样本，未虚报为通过。
