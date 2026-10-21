@echo off
setlocal
set "REA_WORKER=%~dp0"
set "JAVA_HOME=%REA_WORKER%toolchain\jdk21\jdk-21.0.12.1+1"
set "GHIDRA_INSTALL_DIR=%REA_WORKER%toolchain\ghidra\ghidra_12.1.4_PUBLIC"
set "REA_JADX_MCP_JAR=%REA_WORKER%toolchain\android\jadx-headless-mcp-0.7.1-all.jar"
node "%REA_WORKER%.runtime\node_modules\rea-agents\scripts\rea.mjs" %*
