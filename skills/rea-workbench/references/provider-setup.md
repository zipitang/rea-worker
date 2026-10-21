# Provider 配置与就绪校验

REA 本身只是编排层。真正干活的是外部引擎。**没有引擎，工具会在调用时失败，而不是在安装时失败**——这是最容易误判「装好了」的地方。

---

## 一、四个环境变量

| 变量 | 指向 | 缺失影响 |
|---|---|---|
| `JAVA_HOME` | JDK 根目录（不是 bin） | Ghidra / JADX 全不可用 |
| `GHIDRA_INSTALL_DIR` | 含 `support/analyzeHeadless` 的目录 | 原生反编译失败 |
| `REA_JADX_MCP_JAR` | jadx-headless-mcp 的 `*-all.jar` | APK 反编译失败 |
| `REA_MCP_INPUT_SCHEMA_PROFILE` | `compact`（本机设定） | 退回 full，schema 约 496 KB |

本机实际值：

```
JAVA_HOME=D:\mycp\game\REA-worker\toolchain\jdk21\jdk-21.0.12.1+1
GHIDRA_INSTALL_DIR=D:\mycp\game\REA-worker\toolchain\ghidra\ghidra_12.1.4_PUBLIC
REA_JADX_MCP_JAR=D:\mycp\game\REA-worker\toolchain\android\jadx-headless-mcp-0.7.1-all.jar
REA_MCP_INPUT_SCHEMA_PROFILE=compact
```

这些已写进 `~/.workbuddy/mcp.json` 的 `mcpServers.rea.env`。**手动跑 CLI 时不需要再导出**——`rea.cmd` 会注入。

---

## 二、就绪校验（唯一可信的做法）

```bash
cd /d/mycp/game/REA-worker

# 1. 版本断言
./rea.cmd --version                     # 期望 6.5.0

# 2. 客户端注册状态（看 scope 与 skill 对齐）
./rea.cmd doctor --client workbuddy --json

# 3. 各 provider 实况
./rea.cmd doctor --provider ghidra --json
./rea.cmd doctor --provider jadx --json
```

前两项的 `healthy: true` 只说明**配置正确**。第三组才说明**引擎可用**。

从 JSON 里只读这几个字段：

```
healthy          -> 总体结论
checks[name=ghidra].status
checks[name=jadx].status
identity.skill.aligned / tool_count
scope.mode       -> 期望 explicit
```

> ⚠️ `doctor` 读的是**当前进程环境变量**，不是 `mcp.json` 里的 `env`。
> 如果你不带 `rea.cmd` 直接跑 `node .../rea.mjs doctor`，provider 会显示「未设置」——那是误报，不是配置丢了。

---

## 三、安装要点（重装时照此执行）

### JDK 21

- 来源：Adoptium Temurin 21（LTS）
- 必须含 `javac`（Ghidra 的分析脚本需要，不能只用 JRE）
- 校验：`./jdk-21*/bin/java.exe -version` 与 `javac.exe -version`

### Ghidra

- 来源：`NationalSecurityAgency/ghidra` releases，PUBLIC 版
- 解压后根目录含 `support/analyzeHeadless`
- 首次运行会编译脚本缓存，**第一次调用可能慢到几分钟**，不要当成卡死

### JADX 桥（最容易漏）

- **REA 不下载它**。必须自备 `jadx-headless-mcp` 的 `-all.jar`。
- 本机版本 `0.7.1`，官方钉死摘要：
  `SHA-256 = 6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`
- 校验：`sha256sum <jar>`，必须逐字符匹配。不匹配就别用。
- 光有 JAR 不够，还需要 `JAVA_HOME` 有效。

---

## 四、网络绕行（本机踩过的坑）

本机代理会拦 `github.com` 主域（`CONNECT tunnel failed, 502`），但 `api.github.com` 与 `release-assets.githubusercontent.com` 可达。

**绕行方式**：走 GitHub API 的资产端点，不经主域重定向。

```bash
# 1. 取 asset id
curl -s -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/<owner>/<repo>/releases/tags/<tag>"

# 2. 用 asset 端点下载
curl -L -H "Accept: application/octet-stream" -H "User-Agent: rea-deploy" \
  -o out.zip "https://api.github.com/repos/<owner>/<repo>/releases/assets/<id>"
```

两个附加事实：

- Git Bash 自带的 `tar` 是 **GNU 版，不认 zip**。用 `unzip`。
- 大文件放后台跑，别让前台超时；超时后重跑要先删半截文件。

---

## 五、安装位置纪律

**不要把 REA 装到 C 盘。**

- ❌ `npm i -g rea-agents` → 写进 `C:\...\node\versions\<ver>\node_modules`，约 516 MB
- ✅ `npm install --prefix <D盘目录> rea-agents@6.5.0` → 落在指定目录
- 同时把 npm 缓存也重定向：`--cache <D盘目录>/.cache/npm`

顺带好处：注册项指向 D 盘固定路径，WorkBuddy 升级内置 Node 不会让启动器失效。

---

## 六、重装 / 回滚

```bash
# 卸载（只删 REA 自己的注册与 skill，不动引擎、不动其他 MCP）
./rea.cmd uninstall
./rea.cmd uninstall --purge-data      # 连证据数据一起清

# 保守回滚：覆盖回部署前快照
cp ~/.workbuddy/mcp.json.rea.backup.manual ~/.workbuddy/mcp.json
```

清盘：删 `D:\mycp\game\REA-worker` 即回收约 1.8 GB。

---

## 七、升级注意

REA 的 skill 与工具集随版本变化。升级后必须重新做两件事：

1. `rea setup --client workbuddy --yes`（刷新 skill 与注册）
2. 重新核对本文件里的工具名——升级可能改名或新增，本 skill 的 [tool-map](tool-map.md) 需同步

升级前先 `--dry-run --json` 看它打算写什么，别直接 `--yes`。
