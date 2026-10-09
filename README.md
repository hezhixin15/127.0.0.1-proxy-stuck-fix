# 127.0.0.1 Proxy Stuck Fix

> **English summary:** On Windows 11, if apps suddenly time out on `127.0.0.1` (e.g. `ERR_CONNECTION_TIMED OUT (-118)` in 123 Cloud Drive) or Clash Verge says *"proxy server error / not connected"*, the cause is usually two proxy-based tools (game accelerators like Xunyou/Gili/Yoyo + Clash Verge) fighting over the **system proxy**. Whichever exits last leaves `ProxyServer = 127.0.0.1:dead-port` behind, and every proxied app hangs until timeout. This repo contains the diagnosis, the manual fix, and a one-click repair script.

修复 Windows 上加速器（迅游 / 给梨 / 悠悠）与 Clash Verge 冲突导致的**系统代理卡死**——症状为 `127.0.0.1` 访问超时、`ERR_CONNECTION_TIMED OUT (-118)`、"代理服务器出现问题或地址有误"。

## 目录

- [症状](#症状)
- [根因分析](#根因分析)
- [为什么常规修复无效](#为什么常规修复无效)
- [一键修复](#一键修复)
- [手动修复步骤](#手动修复步骤)
- [修好 Clash Verge](#修好-clash-verge)
- [防复发约定](#防复发约定)
- [顽固情况排查清单](#顽固情况排查清单)
- [免责声明](#免责声明)

## 症状

- 各类软件访问 `127.0.0.1` 或走代理的请求"响应时间太长"，最终超时
- 123云盘 App 打不开：`ERR_CONNECTION_TIMED OUT (-118)`
- 悠悠加速器、华硕 Armoury Crate 等 App 加载不出来
- Clash Verge 开系统代理后访问 GitHub 提示：
  > 未连接到互联网，代理服务器出现问题或地址有误
- 腾讯电脑管家 / 360 的"网络异常修复"**检测不出问题**
- Windows 设置里的"网络重置"无效

### 典型触发过程

1. 打开某加速器（给梨 / 迅游）正在加速 Steam
2. 又打开 Clash Verge，点击"系统代理"开关
3. GitHub 报错"代理服务器出现问题"，关掉 Clash 系统代理后恢复
4. 关掉加速器后，**之前一直能用的 Clash 系统代理从此失效**
5. 之后即使所有软件都关闭，各 App 依然超时

## 根因分析

给梨、迅游、悠悠这类加速器和 Clash Verge 的原理完全相同：

> 在本地开一个监听 `127.0.0.1:端口`（常见 7897）的代理服务，然后把 Windows 的"系统代理"指向它，让全部流量先经过本地端口再转发出去。

两个软件同时开 → 互相抢写"系统代理"设置；退出时谁都没恢复 →
**系统代理被永久卡死在 `127.0.0.1:某端口`，而该端口已经没人干活。**

| 端口状态 | 结果 |
|---|---|
| Clash 正在正常监听 | 流量正常出海，一切正常 |
| 端口无人接听（残留进程 / 不干活的服务占着） | 请求挂死直到超时 → `-118`、"响应时间太长" |

### 关键诊断假设

1. **残留进程占端口的证据**：端口完全没人听时通常**秒报**"拒绝连接"；报**超时**说明大概率有加速器后台进程/服务占着端口但不转发流量 → 修复必须先清理残留进程和服务
2. **管家/360 查不出来**：它们的网络修复只查 DNS、网卡、Winsock，**不查系统代理注册表项**
3. **网络重置没用**：网络重置重装网卡、重置 Winsock，但**不会碰 `HKCU` 下的系统代理设置**
4. **报错含义**："代理服务器出现问题或地址有误" = 系统代理开着，但指向的 `127.0.0.1:端口` 上没有可用服务

## 为什么常规修复无效

| 你试过的方法 | 为什么没用 |
|---|---|
| 腾讯电脑管家 / 360 网络修复 | 不检查 `HKCU\...\Internet Settings` 的代理项 |
| Windows 网络重置 | 重置网卡和 Winsock，不清理系统代理 |
| 重启电脑 | 卡死的代理项存在注册表里，重启照样生效 |

## 一键修复

下载 [`fix_proxy.bat`](./fix_proxy.bat) → **右键 → 以管理员身份运行** → 重启电脑。

脚本五步：

1. 打印修复前代理状态快照（`ProxyEnable` / `ProxyServer` / `AutoConfigURL` / `netsh winhttp`）
2. 结束迅游相关进程（按进程名模式匹配）
3. 停止并**禁用**迅游相关服务（禁用而非只停止，防止开机再抢代理）
4. 清除系统代理注册表项 + `netsh winhttp reset proxy` + `ipconfig /flushdns`
5. 打印修复后状态（应显示"直接访问"）

## 手动修复步骤

### 1. 清理加速器残留

- `Ctrl+Shift+Esc` 任务管理器 → 详细信息 → 结束所有加速器相关进程
- `Win+R` → `services.msc` → 加速器服务 → 停止 + 启动类型改**禁用**
- 任务管理器 → 启动应用 → 禁用加速器自启
- 建议先卸载该加速器（修好后要用再重装）

### 2. 诊断（管理员终端逐条执行）

```bat
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer
netsh winhttp show proxy
```

看到 `ProxyEnable 0x1` + `ProxyServer 127.0.0.1:xxxx` → 证实根因。

### 3. 清除卡死的系统代理（核心）

```bat
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /f
netsh winhttp reset proxy
ipconfig /flushdns
```

然后检查：`Win+I` → 网络和 Internet → 代理 → "使用代理服务器"=关、"自动检测设置"=关。**重启电脑**。

### 4. 验证

两个软件都不开 → 打开 123云盘、华硕 App 应秒开，浏览器正常。

## 修好 Clash Verge

1. 记下 Clash 混合端口（一般 `7897`），**先不开**系统代理
2. 管理员终端确认内核活着：

```bat
netstat -ano | findstr :7897
```

必须有 `LISTENING`，没有就重启 Clash Verge 或重装

3. 再开系统代理，确认：

```bat
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer
```

应显示 `127.0.0.1:7897`

4. 若端口被自动改走 → 还有加速器在抢，回第 1 步
5. 若仍报"代理服务器出现问题" → 防火墙拦了内核：Windows 安全中心 → 防火墙 → "允许应用通过防火墙"勾选 Clash / mihomo；第三方安全软件里加入信任

### TraeWork CN / 应用登录不上

- 系统代理修好后通常即恢复
- 若仍不行：`sysdm.cpl` → 高级 → 环境变量 → 删除用户变量中的 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`（值为 `127.0.0.1:...` 时）
- 快速检查：`set | findstr /i proxy`

## 防复发约定

**系统代理同一时间只能归一个软件管。**

- 开加速器加速游戏时 → 不要开 Clash 的系统代理（TUN 模式同样抢路由，也别同时开）
- 退出顺序：**先在软件里关掉"系统代理"开关，再退出软件**
- 再遇到"未连接到互联网，代理服务器出现问题" → 第一反应去 `设置 → 代理` 查看，**不要用网络重置**
- 换用另一个代理工具前，先确认 `设置 → 代理` 里开关已关

## 顽固情况排查清单

- [ ] 跑完脚本后"第 5 步"显示的是什么？（欢迎贴 issue）
- [ ] `netstat -ano | findstr :7897` 有无 `LISTENING`
- [ ] `C:\Windows\System32\drivers\etc\hosts` 有无加速器写入的条目（尤其 Steam 相关域名）
- [ ] `Win+R` → `ncpa.cpl` 禁用残留虚拟网卡
- [ ] `netsh winsock reset` + 重启（**必须在卸载加速器之后**做）
- [ ] 策略级代理：`HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings` 有无异常项
- [ ] 防火墙是否放行 Clash 内核
- [ ] 环境变量是否残留 `HTTP_PROXY`

## 免责声明

`fix_proxy.bat` 会结束相关进程、禁用相关服务，并修改 `HKCU` 注册表中的系统代理设置。运行前请自行确认，出问题自负。本仓库按 MIT 许可证发布。
