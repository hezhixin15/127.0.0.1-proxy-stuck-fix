@echo off
chcp 65001 >nul
title 迅游加速器 + Clash Verge 系统代理修复

:: 必须管理员权限
net session >nul 2>&1
if errorlevel 1 (
    echo [错误] 请右键此文件 -^> 以管理员身份运行！
    pause
    exit /b 1
)

echo ==================================================
echo  第 1 步：当前代理状态（修复前快照）
echo ==================================================
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL
netsh winhttp show proxy
echo.

echo ==================================================
echo  第 2 步：结束迅游相关进程
echo ==================================================
powershell -NoProfile -Command "$n=@('xunyou','xy','xyf','xyapp','xyservice','xunyouacc','xyspeed'); Get-Process | Where-Object { $m=$_.ProcessName.ToLower(); ($n -contains $m) -or ($m -match 'xunyou|迅游') } | ForEach-Object { Write-Host ('  结束: ' + $_.ProcessName + ' (PID ' + $_.Id + ')'); Stop-Process -Id $_.Id -Force }"
echo.

echo ==================================================
echo  第 3 步：停止并禁用迅游相关服务
echo ==================================================
powershell -NoProfile -Command "Get-Service | Where-Object { $_.Name -match 'xunyou|迅游' -or $_.DisplayName -match 'xunyou|迅游' } | ForEach-Object { Write-Host ('  停止: ' + $_.DisplayName); Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue; Set-Service -Name $_.Name -StartupType Disabled -ErrorAction SilentlyContinue }"
echo.

echo ==================================================
echo  第 4 步：清除卡死的系统代理设置（核心修复）
echo ==================================================
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /f 2>nul
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /f 2>nul
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL /f 2>nul
netsh winhttp reset proxy
ipconfig /flushdns
echo.

echo ==================================================
echo  第 5 步：修复后的状态（应显示 直接访问）
echo ==================================================
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable
netsh winhttp show proxy
echo.
echo ==================================================
echo  完成！请重启电脑，然后打开 123云盘/华硕App 测试。
echo  正常后，再打开 Clash Verge 并开启系统代理。
echo ==================================================
pause
