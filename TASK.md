# TASK.md — REA 部署任务拆解

> 对应 `DESIGN.md` v1.0　|　执行状态：**阶段一 + 阶段二 全部完成**（2026-10-17）
> 记号：`[x]` 已完成　`[~]` 进行中　`[!]` 阻塞　`[–]` 按用户要求变更

## 阶段一：静态能力上线

### T1 环境预检与配置备份　`[x]`
- 断言 Node v22.22.2 ✅（满足 `^22.19.0 || ^24.11.0 || >=26.0.0`）
- 备份 `~/.workbuddy/mcp.json` → `mcp.json.rea.backup.manual`
- sha256 一致：`e262ebe342175403f29e1af07c2043462ee22f9ba0b27ec251094a4bd8b34372`

### T2 安装 rea-agents　`[x]`（**方案变更**）
- `[–]` 原计划 `npm i -g` → 用户要求不占 C 盘，改为 workspace 本地安装
- 实际：`npm install --prefix .runtime --cache .cache/npm rea-agents@6.5.0`
- 结果：147 packages，`.runtime` 516 MB，缓存 75 MB，全在 D 盘
- 验收：`rea --version` → `6.5.0` ✅

### T3 setup 试运行　`[x]`
- `standalone` 计划确认：仅写 `~/.workbuddy/mcp.json` + `~/.workbuddy/skills`
- 关键发现：注册命令指向本地启动器，**不经 npx、不联网**
- 关键发现：JADX 需自备 `jadx-headless-mcp 0.7.1` JAR（REA 不下载）

### T4 注册 MCP + 安装 skill　`[x]`
- `rea setup --client workbuddy --yes`
- 验收：`mcpServers` = `blender, lighthouse-ops, rea`
- diff 确认：`blender` / `lighthouse-ops` **零改动**，仅新增 `rea` 块
- skill：`~/.workbuddy/skills/reverse-engineer-anything/SKILL.md`（92 KB）

### T5 固化 compact schema + provider env　`[x]`
- 注入 4 个 env：`REA_MCP_INPUT_SCHEMA_PROFILE` / `JAVA_HOME` / `GHIDRA_INSTALL_DIR` / `REA_JADX_MCP_JAR`
- 验收：JSON 可解析，其他 server 未受影响

### T6 验收回归（AC1–AC4）　`[x]`
| 判据 | 结果 |
|---|---|
| AC1 版本 6.5.0 | ✅ |
| AC2 `doctor --client workbuddy` | ✅ `healthy: true`，skill `aligned`，207 tools |
| AC3 既有配置保留 | ✅ diff 逐行核对 |
| AC4 skill 落位 | ✅ |

### T7 冒烟：静态分析实跑　`[x]`
- 自建样本 `samples/smoke-app/`（Electron，4 文件，MIT，无第三方代码）
- `analyze-javascript-application` → `evidence_id: ev_8f12ae06...54fb30`，两次运行哈希一致
- 正确识别 IPC 通道 `read-config` 与 `contextBridge` 边界

### T8 交付与沉淀　`[x]`
- `README.md`：布局 / 验证 / 故障排查 / 重装 / 回滚 / 合规
- `rea.cmd`：自动注入 provider env 的 CLI 入口
- `.workbuddy/memory/2026-10-17.md` 已记录

---

## 阶段二：原生与 Android

### T9 安装 JDK 21　`[x]`
- Temurin `21.0.12.1+1` LTS，解压至 `toolchain/jdk21/`（329 MB）
- 验收：`java -version` → 21.0.12.1；`javac` 可用（JADX 桥接需要编译器模块）

### T10 安装 Ghidra 并接线　`[x]`
- Ghidra `12.1.4 PUBLIC`，解压至 `toolchain/ghidra/`（875 MB）
- `GHIDRA_INSTALL_DIR` 已注入注册 env
- 验收：`doctor --provider ghidra` → `healthy: true`
- 残留限制：Windows 为实验性只读 P0；**未做实跑**（无自有 PE 样本）

### T11 JADX / Android 链　`[x]`
- `jadx-headless-mcp-0.7.1-all.jar`（41 MB），SHA-256 与官方钉死值一致
- 验收：`doctor --provider jadx` → `healthy: true`，JAR 结构校验通过
- 残留限制：**未实跑**（无自有 APK 样本）

### T12 IDA Pro　`[–]`
- 按用户决定排除，未接入

---

## 剩余待办（需人工）

- `[!]` **重启 WorkBuddy** 并在连接器管理页对 `rea` 点「信任」——否则工具不出现在会话中
- `[ ]` 可选：用自有 PE / APK 各跑一次真实分析，把 🟡 转为 ✅

## 不在范围内

- 源码编译（`npm ci` + `turbo build`）
- 远程 / HTTP 传输部署（REA 仅 stdio）
- 修改 REA 自身源码
