# REA 工具地图（207 个，按能力域）

工具名即 MCP 工具后缀。会话中调用形式为 `mcp__rea__<name>`。
本机 schema 档位为 `compact`，参数提示精简但校验完整；参数不确定时用 `ToolSearch` 查一次，别凭猜。

---

## 1. 会话与二进制基础设施

| 工具 | 用途 |
|---|---|
| `binary_session` | 建立/描述分析会话上下文 |
| `open_binary` / `close_binary` | 加载/释放二进制 |
| `current_document` / `list_documents` | 当前与已加载文档 |
| `binary_overview` | 全局概览（格式、架构、入口） |
| `list_architectures` / `list_segments` | 架构与段表 |
| `inspect_binary_layout` | 布局细节 |
| `read_bytes` / `search_bytes` | 原始字节读写检索 |
| `list_strings` / `search_strings` | 字符串枚举与检索 |
| `list_names` / `search_procedures` / `list_procedures` | 符号与函数 |
| `xrefs` / `find_xrefs_to_name` | 交叉引用 |
| `goto_address` / `current_address` / `next_address` / `prev_address` | 地址导航 |
| `address_name` / `set_address_name` / `set_addresses_names` | 命名 |
| `address_to_file_offset` | 地址↔文件偏移 |
| `inspect_address_context` | 地址上下文 |
| `comment` / `set_comment` / `inline_comment` / `set_inline_comment` | 注释 |
| `list_bookmarks` / `set_bookmark` / `unset_bookmark` | 书签（跨会话保留线索） |
| `export_evidence_bundle` / `get_evidence_bundle` / `import_evidence_bundle` | 证据包往返 |

## 2. 原生代码分析

| 工具 | 用途 |
|---|---|
| `inspect_with_objdump` | 零依赖快速反汇编视图 |
| `analyze_function` | 单函数结构化分析 |
| `batch_decompile` | 批量反编译（需 Ghidra） |
| `procedure_info` / `procedure_address` | 函数元信息 |
| `procedure_pseudo_code` | 伪代码（需 Ghidra） |
| `procedure_assembly` / `read_function_instructions` | 汇编视图 |
| `procedure_callees` / `procedure_callers` / `procedure_references` | 调用关系 |
| `resolve_containing_procedure` | 地址归函数 |
| `get_call_graph` / `build_call_path` / `trace_call_path` | 调用图与路径 |
| `compare_functions` | 函数级差异 |
| `find_changed_behavior` | 行为变化定位 |
| `demangle_swift` | Swift 符号还原 |
| `inspect_native_instruction` / `inspect_native_api` / `inspect_native_data_type` | 指令/API/类型 |
| `inspect_native_dispatch_metadata` / `inspect_native_load_image` | 派发元数据、加载镜像 |
| `resolve_native_call_targets` / `annotate_native_function` | 间接调用解析与标注 |
| `inspect_pe_resources` | PE 资源段 |
| `inspect_macho` / `inspect_signature` | Mach-O、代码签名 |
| `inspect_artifact` / `compare_artifacts` | 产物描述与对比 |

## 3. 托管代码与重建验证

| 工具 | 用途 |
|---|---|
| `inspect_managed_artifact` | .NET 程序集入口 |
| `inspect_managed_members` / `compare_managed_members` | 成员枚举与对比 |
| `inspect_managed_native_boundaries` / `verify_managed_native_boundaries` | 托管↔原生边界 |
| `project_managed_application_graph` | 应用图投影 |
| `import_managed_reconstruction` | 导入重建结果 |
| `build_reconstruction_obligation_ledger` | 重建义务台账 |
| `evaluate_reconstruction_coverage` / `verify_reconstruction` | 覆盖率与验证 |
| `list_unknowns` / `record_unknown` / `update_unknown` / `verify_unknown_resolution` | 未知项闭环（**逆向工作流的核心资产**） |
| `open_jeb_project` / `list_jeb_units` / `decompile_jeb_item` / `inspect_jeb_client` | JEB（需自有授权） |

> `record_unknown` → `update_unknown` → `verify_unknown_resolution` 这条链，是把「一次性分析」变成「可持续重建」的关键。做长任务时用它，不要靠上下文记忆。

## 4. 语言/格式指纹

| 工具 | 用途 |
|---|---|
| `inspect_go_binary` | Go 构建信息、符号表、模块 |
| `inspect_rust_binary` | Rust crate 特征、panic 字符串 |
| `inspect_wasm_artifact` / `compare_wasm_interfaces` | WASM 结构与接口差异 |
| `inspect_evm_interface` | EVM 合约接口 |
| `inspect_sqlite_database` | SQLite schema 与内容 |
| `inspect_plist` | plist |
| `inspect_keyed_archive` | 键控归档（iOS/资源包） |
| `inspect_asset_catalog` | 资源目录 |
| `analyze_swift_types` | Swift 类型结构 |
| `extract_artifact` / `extract_firmware` / `inspect_firmware_regions` | 解包与固件分区 |

## 5. JavaScript / Electron / Web

| 工具 | 用途 |
|---|---|
| `analyze_javascript_application` | **Electron/打包 JS 首选入口** |
| `analyze_web_bundle` | Web bundle 入口 |
| `list_electron_targets` / `inspect_electron_page` / `inspect_electron_fuses` | Electron 目标、页面、fuses 开关 |
| `capture_electron_scenario` | Electron 场景抓取 |
| `compare_bundles` | bundle 差异 |
| `compare_source_to_bundle` | 源码 vs 产物（**证明线上跑的是什么**） |
| `compare_javascript_export_shapes` | 导出形态对比 |
| `recover_javascript_sources` | sourcemap/源码恢复 |
| `export_web_scripts` | 导出站点脚本 |
| `list_javascript_runtime_targets` / `observe_javascript_runtime` / `reconcile_javascript_runtime` | JS 运行时观测与对账 |
| `trace_javascript_semantics` / `trace_web_module_imports` / `trace_web_source_location` | 语义与模块溯源 |
| `inspect_web_page` / `inspect_web_event_listeners` / `inspect_web_network_capture` | 页面结构、事件、网络 |
| `capture_web_screenshot` / `compare_web_captures` / `compare_web_screenshots` | 截图与视觉差异 |
| `observe_web_execution` / `observe_web_session` | 执行与会话观测 |
| `list_browser_targets` / `capture_browser_scenario` | 浏览器目标与场景 |
| `discover_webmcp_tools` | 网页暴露的工具面 |

## 6. Android

| 工具 | 用途 |
|---|---|
| `inspect_android_package` | APK 入口 |
| `search_android_classes` / `inspect_android_class` / `inspect_android_method` | 类与方法检索 |
| `decode_android_resources` / `decode_interface_builder` | 资源与布局 |
| `trace_android_references` | 引用追踪 |
| `project_android_application_graph` | 应用图 |
| `identify_flutter_build` / `inspect_dart_aot` | Flutter / Dart AOT |
| `inspect_apktool_client` | apktool 可用性（本机未装） |
| `resolve_adb_packages` / `list_adb_packages` / `install_adb_package` / `uninstall_adb_package` | 设备端包管理（需 adb，本机未装） |
| `list_adb_devices` / `inspect_adb_device` / `inspect_adb_display` / `inspect_adb_window` | 设备与窗口 |
| `start_adb_app` / `stop_adb_app` / `start_adb_activity` | 应用控制 |
| `list_adb_processes` / `list_adb_services` / `list_adb_features` | 进程与服务 |
| `list_adb_directory` / `pull_adb_file` / `pull_adb_package` / `push_adb_file` | 文件搬运 |
| `read_adb_logcat` / `read_adb_setting` / `collect_adb_bugreport` | 日志与设置 |
| `capture_adb_screen` | 截屏 |
| `inspect_adb_client` / `inspect_adb_package` | 客户端与包状态 |

## 7. 动态与调试

| 工具 | 用途 |
|---|---|
| `list_frida_devices` / `list_frida_processes` | Frida 设备与进程 |
| `start_frida_session` / `frida_session_status` / `resume_frida_session` / `close_frida_session` | 会话生命周期 |
| `load_frida_script` / `unload_frida_script` | 脚本注入 |
| `observe_native_calls` / `trace_native_values` / `observe_native_ui` / `trace_native_ui_action` | 调用与取值观测 |
| `capture_native_ui_scenario` | 原生 UI 场景 |
| `capture_process_scenario` / `compare_process_captures` | 进程抓取与对比 |
| `inspect_recorded_crash` | 崩溃记录 |
| `start_gdb_session` / `gdb_console` / `gdb_session_status` / `close_gdb_session` | GDB |
| `start_rizin_debug_session` / `rizin_debug_command` / `rizin_debug_session_status` / `close_rizin_debug_session` | rizin 调试 |
| `execute_rizin_command` | rizin 静态命令 |
| `list_cutter_sessions` / `cutter_command` | Cutter |

> 本节工具**本机均未验证**（缺 GDB / rizin / Frida 服务端 / 真机）。声称动态结论前必须先跑一次并确认成功。

## 8. 跨平台应用图与网络/信号

| 工具 | 用途 |
|---|---|
| `project_apple_application_graph` | iOS/macOS 应用图 |
| `get_objc_classes` / `get_objc_protocols` | ObjC 结构 |
| `project_harmony_application_graph` | HarmonyOS 应用图 |
| `trace_dylib_resolution` | 动态库解析链 |
| `inspect_pcap_capture` / `inspect_pcap_client` | pcap 读取 |
| `inspect_packet_capture` / `inspect_packet_fields` | 数据包解析 |
| `decode_signal_recording` / `inspect_signal_decoders` | 信号解码 |

## 9. 跨域编排

| 工具 | 用途 |
|---|---|
| `trace_feature` / `trace_application_feature` | 从功能描述反查实现路径 |
| `correlate_static_and_runtime` | 静态与运行时对齐（**冲突裁决**） |
| `compare_application_versions` | 版本级差异 |
| `get_navigation_context` / `inspect_analysis_view` | 分析上下文 |

---

## 常见组合（直接照抄）

**Electron 应用通信审计**
```
analyze_javascript_application <dir>
→ inspect_electron_page
→ inspect_electron_fuses
→ recover_javascript_sources
→ compare_source_to_bundle
```

**版本升级差异**
```
compare_application_versions <v1> <v2>
→ compare_functions | compare_bundles | compare_managed_members
→ find_changed_behavior
```

**原生函数理解（需 Ghidra）**
```
open_binary <pe>
→ binary_overview
→ search_procedures <keyword>
→ procedure_pseudo_code
→ get_call_graph
→ build_call_path <src> <dst>
```

**APK 接口梳理（需 JADX）**
```
inspect_android_package <apk>
→ search_android_classes <kw>
→ inspect_android_method
→ trace_android_references
→ project_android_application_graph
```
