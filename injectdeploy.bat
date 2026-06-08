@chcp 936 >nul
@echo off
setlocal enabledelayedexpansion
color a
title PanDaSys 部署手动离线接管程序 - v26.06.08
cd /d "%~dp0"
set silent=0

@REM 检测静默参数
if /i "%1"=="/S" (
    set silent=1
    @echo on
)

@REM 创建文件夹
for %%a in (
    Windows\Setup\Set\InDeploy
    Windows\Setup\Set\osc
    Windows\Setup\Set\Run
    Windows\Setup\Run\1
    Windows\Setup\Run\2
) do (
    mkdir "%%a" 2>nul
)

@REM 处理文件
if exist "unattend.xml" move /y "unattend.xml" "Windows\Panther\unattend.xml"
if exist "osc.exe" move /y "osc.exe" "Windows\Setup\Set\osc.exe"
if exist "MSVCRedist.AIO.exe" (
    mkdir "Windows\Setup\Set\osc\runtime" 2>nul
    move /y "MSVCRedist.AIO.exe" "Windows\Setup\Set\osc\runtime\MSVCRedist.AIO.exe"
)

@REM 判断文件完整性
if not exist "Windows\System32\config\SYSTEM" call :error "找不到系统注册表文件"
if not exist "Windows\Panther\unattend.xml" call :error "找不到unattend.xml文件"
if not exist "Windows\Setup\Set\osc.exe" call :error "找不到osc.exe文件"
find /i "IMAGE_STATE_COMPLETE" "Windows\Setup\State\State.ini" && call :error "不支持接管已经部署/未封装的映像"
goto main

:main
cls
echo.
echo 提示：即将接管系统部署，注入系统部署
echo.
echo 注意：1. 默认仅支持接管Win8.1x64、Win10x64、Win11x64系统；
echo 　　　2. 您的执行环境如果不带choice.exe，将无法完成后续配置；
echo 　　　3. 建议在PE环境或TrustedInstaller用户下运行此脚本
echo.
echo 信息：
if exist "Windows\Es4.Deploy.exe" echo 　　　该映像使用了IT天空ES4封装
if exist "Sysprep\ES5\EsDeploy.exe" echo 　　　该映像使用了IT天空ES5封装
if exist "Sysprep\ES5S\ES5S.exe" echo 　　　该映像使用了IT天空ES5S封装
if exist "Windows\ScData\ScData.sc" echo 　　　该映像使用了系统总裁SCPT3.0封装
echo.
echo 警告：此操作不可逆，请三思而后行！
echo.
if %silent% EQU 0 pause
goto inject

:inject
if not exist "Windows\Panther\unattend2.xml" copy /y "Windows\Panther\unattend.xml" "Windows\Panther\unattend2.xml"

echo 修改系统注册表
REG LOAD "HKLM\Mount_SYSTEM" "Windows\System32\config\SYSTEM"
REG LOAD "HKLM\Mount_SOFTWARE" "Windows\System32\config\SOFTWARE"
REG LOAD "HKLM\Mount_DEFAULT" "Windows\System32\config\DEFAULT"
REG LOAD "HKLM\Mount_NTUSER" "Users\Default\NTUSER.DAT"

echo 强制禁用 Windows Defender

rem 移除 Defender 和 Windows 安全服务
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\MsSecCore" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\wscsvc" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\WdNisDrv" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\WdNisSvc" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\WdFilter" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\WdBoot" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\SgrmAgent" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\SgrmBroker" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\WinDefend" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Virus and threat protection" /v "UILockdown" /t REG_DWORD /d "1" /f

rem 禁用设备驱动
reg add "HKLM\Mount_SOFTWARE\Microsoft\Windows Defender\Real-Time Protection" /v "DisableAsyncScanOnOpen" /t REG_DWORD /d "1" /f

rem 禁用内核内缓解措施 In-kernel Mitigations
reg add "HKLM\Mount_SYSTEM\ControlSet001\Control\Session Manager\kernel" /v "MitigationAuditOptions" /t REG_BINARY /d "000000000000202200000000000000200000000000000000" /f
reg add "HKLM\Mount_SYSTEM\ControlSet001\Control\Session Manager\kernel" /v "MitigationOptions" /t REG_BINARY /d "002222202220222220000000002000200000000000000000" /f
reg add "HKLM\Mount_SYSTEM\ControlSet001\Control\Session Manager\kernel" /v "KernelSEHOPEnabled" /t REG_DWORD /d "0" /f

rem 禁用 Spectre 熔毁缓解措施
reg add "HKLM\Mount_SYSTEM\ControlSet001\Control\Session Manager\Memory Management" /v "FeatureSettings" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SYSTEM\ControlSet001\Control\Session Manager\Memory Management" /v "FeatureSettingsOverride" /t REG_DWORD /d "3" /f
reg add "HKLM\Mount_SYSTEM\ControlSet001\Control\Session Manager\Memory Management" /v "FeatureSettingsOverrideMask" /t REG_DWORD /d "3" /f

rem 禁用服务缓解
reg add "HKLM\Mount_SOFTWARE\Microsoft\FTH" /v "Enabled" /t REG_DWORD /d "0" /f

rem 关闭实时防护
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableRoutinelyTakingAction" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableBehaviorMonitoring" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableIOAVProtection" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableOnAccessProtection" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableAsyncScanOnOpen" /t REG_DWORD /d "1" /f

rem 移除 Defender 和 Windows 安全相关服务
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\SecurityHealthService" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender Security Center\App and Browser protection" /v "DisallowExploitProtectionOverride" /t REG_DWORD /d "1" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\MsSecFlt" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\MsSecWfp" /f

rem 强制禁用 Windows Defender 反病毒策略
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowIOAVProtection" /v "value" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowIOAVProtection" /v "PUAProtection" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowIOAVProtection" /v "ServiceKeepAlive" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowIOAVProtection" /v "AllowFastServiceStartup" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowIOAVProtection" /v "DisableLocalAdminMerge" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowIOAVProtection" /v "RandomizeScheduleTaskTimes" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowArchiveScanning" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowBehaviorMonitoring" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowCloudProtection" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowEmailScanning" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowFullScanOnMappedNetworkDrives" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowFullScanRemovableDriveScanning" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowIntrusionPreventionSystem" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowOnAccessProtection" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowRealtimeMonitoring" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowScanningNetworkFiles" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowScriptScanning" /v "value" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowUserUIAccess" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\AvgCPULoadFactor" /v "value" /t REG_DWORD /d "50" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\CheckForSignaturesBeforeRunningScan" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\CloudBlockLevel" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\CloudExtendedTimeout" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\DaysToRetainCleanedMalware" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\DisableCatchupFullScan" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\DisableCatchupQuickScan" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\EnableControlledFolderAccess" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\EnableLowCPUPriority" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\EnableNetworkProtection" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\PUAProtection" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\RealTimeScanDirection" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\ScanParameter" /v "value" /t REG_DWORD /d "2" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\ScheduleScanDay" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\ScheduleScanTime" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\SignatureUpdateInterval" /v "value" /t REG_DWORD /d "24" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\Defender\SubmitSamplesConsent" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions" /v "DisableAutoExclusions" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" /v "MpEnablePus" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" /v "MpCloudBlockLevel" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" /v "MpBafsExtendedTimeout" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" /v "EnableFileHashComputation" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\NIS\Consumers\IPS" /v "ThrottleDetectionEventsRate" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\NIS\Consumers\IPS" /v "DisableSignatureRetirement" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\NIS\Consumers\IPS" /v "DisableProtocolRecognition" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "DisableScanningNetworkFiles" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "DisableScanOnRealtimeEnable" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "LocalSettingOverrideDisableOnAccessProtection" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "LocalSettingOverrideRealtimeScanDirection" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "LocalSettingOverrideDisableIOAVProtection" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "LocalSettingOverrideDisableBehaviorMonitoring" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "LocalSettingOverrideDisableIntrusionPreventionSystem" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "LocalSettingOverrideDisableRealtimeMonitoring" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "RealtimeScanDirection" /t REG_DWORD /d "2" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "IOAVMaxSize" /t REG_DWORD /d "1298" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "DisableInformationProtectionControl" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "DisableIntrusionPreventionSystem" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" /v "DisableRawWriteNotification" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "LowCpuPriority" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableRestorePoint" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableArchiveScanning" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableScanningNetworkFiles" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableCatchupFullScan" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableCatchupQuickScan" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableEmailScanning" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableHeuristics" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableReparsePointScanning" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "SignatureDisableNotification" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "RealtimeSignatureDelivery" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "ForceUpdateFromMU" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "DisableScheduledSignatureUpdateOnBattery" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "UpdateOnStartUp" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "SignatureUpdateCatchupInterval" /t REG_DWORD /d "2" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "DisableUpdateOnStartupWithoutEngine" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "ScheduleTime" /t REG_DWORD /d "5184" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "DisableScanOnUpdate" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "DisableBlockAtFirstSeen" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "LocalSettingOverrideSpynetReporting" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "SpynetReporting" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "SubmitSamplesConsent" /t REG_DWORD /d "2" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\UX Configuration" /v "SuppressRebootNotification" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access" /v "EnableControlledFolderAccess" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Network Protection" /v "EnableNetworkProtection" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\WOW6432Node\Policies\Microsoft\Windows Defender" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Microsoft Antimalware" /v "DisableAntiVirus" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Microsoft Antimalware\SpyNet" /v "SpyNetReporting" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Microsoft Antimalware\SpyNet" /v "LocalSettingOverrideSpyNetReporting" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" /v "DisableEnhancedNotifications" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" /v "DisableGenericRePorts" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" /v "WppTracingLevel" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" /v "WppTracingComponents" /t REG_DWORD /d "0" /f
reg add "HKLM\Mount_SYSTEM\ControlSet001\Control\CI\Policy" /v "VerifiedAndReputablePolicyState" /t REG_DWORD /d "0" /f

rem 禁用杀毒
rem 禁止覆盖实时保护设置
rem 禁用 Windows Defender 安全中心通知
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\WindowsDefenderSecurityCenter\DisableEnhancedNotifications" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\WindowsDefenderSecurityCenter\DisableNotifications" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\PolicyManager\default\WindowsDefenderSecurityCenter\HideWindowsSecurityNotificationAreaControl" /f
reg delete "HKLM\Mount_SOFTWARE\Microsoft\Security Center" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\Security Center" /v "FirstRunDisabled" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\Security Center" /v "AntiVirusOverride" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\Security Center" /v "FirewallOverride" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /t REG_DWORD /d "1" /f
reg add "HKLM\Mount_DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" /v "Enabled" /t REG_DWORD /d "0" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{2781761E-28E2-4109-99FE-B9D127C57AFE}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{195B4D07-3DE2-4744-BBF2-D90121AE785B}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{361290c0-cb1b-49ae-9f3e-ba1cbe5dab35}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{45F2C32F-ED16-4C94-8493-D72EF93A051B}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{6CED0DAA-4CDE-49C9-BA3A-AE163DC3D7AF}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{8a696d12-576b-422e-9712-01b9dd84b446}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{8C9C0DB7-2CBA-40F1-AFE0-C55740DD91A0}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{A2D75874-6750-4931-94C1-C99D3BC9D0C7}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{A7C452EF-8E9F-42EB-9F2B-245613CA0DC9}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{DACA056E-216A-4FD1-84A6-C306A017ECEC}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{E3C9166D-1D39-4D4E-A45D-BC7BE9B00578}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{F6976CF5-68A8-436C-975A-40BE53616D59}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{2781761E-28E2-4109-99FE-B9D127C57AFE}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{195B4D07-3DE2-4744-BBF2-D90121AE785B}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{361290c0-cb1b-49ae-9f3e-ba1cbe5dab35}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{45F2C32F-ED16-4C94-8493-D72EF93A051B}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{6CED0DAA-4CDE-49C9-BA3A-AE163DC3D7AF}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{8a696d12-576b-422e-9712-01b9dd84b446}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{8C9C0DB7-2CBA-40F1-AFE0-C55740DD91A0}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{A2D75874-6750-4931-94C1-C99D3BC9D0C7}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{A7C452EF-8E9F-42EB-9F2B-245613CA0DC9}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{DACA056E-216A-4FD1-84A6-C306A017ECEC}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{E3C9166D-1D39-4D4E-A45D-BC7BE9B00578}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{F6976CF5-68A8-436C-975A-40BE53616D59}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{2781761E-28E2-4109-99FE-B9D127C57AFE}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{195B4D07-3DE2-4744-BBF2-D90121AE785B}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{361290c0-cb1b-49ae-9f3e-ba1cbe5dab35}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{45F2C32F-ED16-4C94-8493-D72EF93A051B}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{6CED0DAA-4CDE-49C9-BA3A-AE163DC3D7AF}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{8a696d12-576b-422e-9712-01b9dd84b446}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{8C9C0DB7-2CBA-40F1-AFE0-C55740DD91A0}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{A2D75874-6750-4931-94C1-C99D3BC9D0C7}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{A7C452EF-8E9F-42EB-9F2B-245613CA0DC9}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{DACA056E-216A-4FD1-84A6-C306A017ECEC}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{E3C9166D-1D39-4D4E-A45D-BC7BE9B00578}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{F6976CF5-68A8-436C-975A-40BE53616D59}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{2781761E-28E2-4109-99FE-B9D127C57AFE}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{195B4D07-3DE2-4744-BBF2-D90121AE785B}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{361290c0-cb1b-49ae-9f3e-ba1cbe5dab35}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{45F2C32F-ED16-4C94-8493-D72EF93A051B}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{6CED0DAA-4CDE-49C9-BA3A-AE163DC3D7AF}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{8a696d12-576b-422e-9712-01b9dd84b446}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{8C9C0DB7-2CBA-40F1-AFE0-C55740DD91A0}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{A2D75874-6750-4931-94C1-C99D3BC9D0C7}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{A7C452EF-8E9F-42EB-9F2B-245613CA0DC9}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{DACA056E-216A-4FD1-84A6-C306A017ECEC}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{E3C9166D-1D39-4D4E-A45D-BC7BE9B00578}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{F6976CF5-68A8-436C-975A-40BE53616D59}" /f

rem Defender 日志
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Control\WMI\Autologger\DefenderAuditLogger" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Control\WMI\Autologger\DefenderApiLogger" /f

rem 清除 Defender 任务计划
reg delete "HKLM\Mount_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{0ACC9108-2000-46C0-8407-5FD9F89521E8}" /f
reg delete "HKLM\Mount_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{1D77BCC8-1D07-42D0-8C89-3A98674DFB6F}" /f
reg delete "HKLM\Mount_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{4A9233DB-A7D3-45D6-B476-8C7D8DF73EB5}" /f
reg delete "HKLM\Mount_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{B05F34EE-83F2-413D-BC1D-7D5BD6E98300}" /f

rem 移除右键关联菜单中的杀毒扫描菜单项
reg delete "HKLM\Mount_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\ShellServiceObjects\{900c0763-5cad-4a34-bc1f-40cd513679d5}" /f
reg delete "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ShellServiceObjects\{900c0763-5cad-4a34-bc1f-40cd513679d5}" /f
reg delete "HKLM\Mount_SOFTWARE\Microsoft\Windows Defender" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\Folder\shell\WindowsDefender" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\DesktopBackground\Shell\WindowsSecurity" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\Folder\shell\WindowsDefender\Command" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\AppUserModelId\Windows.Defender" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\AppUserModelId\Microsoft.Windows.Defender" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\AppX9kvz3rdv8t7twanaezbwfcdgrbg3bck0" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\Local Settings\MrtCache\C:%%5CWindows%%5CSystemApps%%5CMicrosoft.Windows.AppRep.ChxApp_cw5n1h2txyewy%%5Cresources.pri" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WindowsDefender" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WindowsDefender" /f

rem 移除外壳关联
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Control\Ubpm" /v "CriticalMaintenance_DefenderCleanup" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Control\Ubpm" /v "CriticalMaintenance_DefenderVerification" /f
reg add "HKLM\Mount_SYSTEM\ControlSet001\Control\Ubpm" /f
reg add "HKLM\Mount_SYSTEM\ControlSet001\Control\Ubpm" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System" /v "WindowsDefender-1" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System" /v "WindowsDefender-2" /f
reg delete "HKLM\Mount_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System" /v "WindowsDefender-3" /f
reg add "HKLM\Mount_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System" /f

rem 移除 Defender 启动项
reg add "HKLM\Mount_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System" /f
reg add "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /f
reg delete "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "WindowsDefender" /f

rem 移除 Web 防护
reg add "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{E48B2549-D510-4A76-8A5F-FC126A6215F0}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{E48B2549-D510-4A76-8A5F-FC126A6215F0}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\CLSID\{E48B2549-D510-4A76-8A5F-FC126A6215F0}" /f
reg delete "HKLM\Mount_SOFTWARE\Classes\WOW6432Node\CLSID\{E48B2549-D510-4A76-8A5F-FC126A6215F0}" /f
reg delete "HKLM\Mount_SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Microsoft.OneCore.WebThreatDefense.Service.UserSessionServiceManager" /f
reg delete "HKLM\Mount_SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Microsoft.OneCore.WebThreatDefense.ThreatExperienceManager.ThreatExperienceManager" /f
reg delete "HKLM\Mount_SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Microsoft.OneCore.WebThreatDefense.ThreatResponseEngine.ThreatDecisionEngine" /f
reg delete "HKLM\Mount_SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Microsoft.OneCore.WebThreatDefense.Configuration.WTDUserSettings" /f

rem 隐藏 Windows 设置页面中的 Defender
reg add "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "SettingsPageVisibility" /t REG_SZ /d "hide:windowsdefender;" /f

echo 接管系统部署
REG ADD "HKLM\Mount_SYSTEM\Setup" /f /v "CmdLine" /t REG_SZ /d "deploy.exe" 

echo 拒绝厂商 WPBT 执行
REG ADD "HKLM\Mount_SYSTEM\ControlSet001\Control\Session Manager" /f /v "DisableWpbtExecution" /t REG_DWORD /d 1

echo 跳过系统配置检测
for %%a in (
BypassCPUCheck
BypassRAMCheck
BypassSecureBootCheck
BypassStorageCheck
BypassTPMCheck
) do REG ADD "HKLM\Mount_SYSTEM\Setup\LabConfig" /f /v "%%a" /t REG_DWORD /d 1
REG ADD "HKLM\Mount_SYSTEM\Setup\MoSetup" /f /v "AllowUpgradesWithUnsupportedTPMOrCPU" /t REG_DWORD /d 1

echo 禁用 BitLocker 自动加密（Windows 11+）
REG ADD "HKLM\Mount_SYSTEM\ControlSet001\BitLocker" /f /v "PreventDeviceEncryption" /t REG_DWORD /d 1
REG ADD "HKLM\Mount_SOFTWARE\Microsoft\Windows Defender\Spynet" /f /v "SubmitSamplesConsent" /t REG_DWORD /d 0

echo 禁用保留存储的空间占用
REG ADD "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" /v "MiscPolicyInfo" /t REG_DWORD /d "2" /f
REG ADD "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" /v "PassedPolicy" /t REG_DWORD /d "0" /f
REG ADD "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" /v "ShippedWithReserves" /t REG_DWORD /d "0" /f

echo 处理 OOBE
REG ADD "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "BypassNRO" /t REG_DWORD /d "1" /f
REG DELETE "HKLM\Mount_SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe" /v "DevHomeUpdate" /f
REG DELETE "HKLM\Mount_SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\CrossDeviceUpdate" /f
REG DELETE "HKLM\Mount_SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate" /f
REG DELETE "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate" /f
REG DELETE "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate" /f
REG DELETE "HKLM\Mount_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\CrossDeviceUpdate" /f

echo 跳过系统配置检测
for %%a in (SV1,SV2) do REG ADD "HKLM\Mount_NTUSER\Control Panel\UnsupportedHardwareNotificationCache" /f /v "%%a" /t REG_DWORD /d 0

echo 禁用 OneDriveSetup 自动启动（Windows 11 26H1 转换成计划任务禁用）
REG DELETE "HKLM\Mount_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /f /v "OneDriveSetup"

echo 屏蔽“同意个人数据跨境传输”
REG ADD "HKLM\Mount_NTUSER\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\PersonalDataExport" /f /v "PDEShown" /t REG_DWORD /d 2

echo 禁用 Windows 全新安装后擅自安装三方 App
for %%a in (
ContentDeliveryAllowed
DesktopSpotlightOemEnabled
FeatureManagementEnabled
OemPreInstalledAppsEnabled
PreInstalledAppsEnabled
PreInstalledAppsEverEnabled
RemediationRequired
SilentInstalledAppsEnabled
SlideshowEnabled
SoftLandingEnabled
SystemPaneSuggestionsEnabled
SubscribedContentEnabled
) do REG ADD "HKLM\Mount_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "%%a" /t REG_DWORD /d "0" /f

echo 禁用 Windows 在各处无用的建议提示
for %%a in (
310093Enabled
338388Enabled
338389Enabled
338393Enabled
353694Enabled
353696Enabled
) do REG ADD "HKLM\Mount_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-%%a" /t REG_DWORD /d "0" /f

echo 禁用游戏栏 Game Bar
REG ADD "HKLM\Mount_NTUSER\SOFTWARE\Microsoft\GameBar" /v "UseNexusForGameBarEnabled" /t REG_DWORD /d "0" /f

echo 隐藏任务栏小组件 (新版本系统报错属正常情况，OSC 会进行处理)
REG ADD "HKLM\Mount_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d "0" /f

echo 隐藏任务栏聊天 (新版本系统报错属正常情况，OSC 会进行处理)
REG ADD "HKLM\Mount_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarMn" /t REG_DWORD /d "0" /f

echo 任务栏显示搜索图标 (新版本系统报错属正常情况，OSC 会进行处理)
REG ADD "HKLM\Mount_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarMode" /t REG_DWORD /d "1" /f

echo 任务栏禁用资讯和兴趣 (新版本系统报错属正常情况，OSC 会进行处理)
REG ADD "HKLM\Mount_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /v "ShellFeedsTaskbarViewMode" /t REG_DWORD /d "2" /f
REG ADD "HKLM\Mount_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /v "ShellFeedsTaskbarOpenOnHover" /t REG_DWORD /d "0" /f
REG ADD "HKLM\Mount_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /v "IsFeedsAvailable" /t REG_DWORD /d "0" /f
REG ADD "HKLM\Mount_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /v "IsEnterpriseDevice" /t REG_DWORD /d "1" /f

echo 卸载挂载注册表
REG UNLOAD "HKLM\Mount_DEFAULT"
REG UNLOAD "HKLM\Mount_SOFTWARE"
REG UNLOAD "HKLM\Mount_SYSTEM"
REG UNLOAD "HKLM\Mount_NTUSER"

>"Windows\Setup\pandasys.txt" echo ispandasys
if %silent% EQU 0 (
    if /i "%systemdrive%"=="x:" if not exist "%windir%\System32\choice.exe" (
        copy /y "Windows\System32\choice.exe" "%windir%\System32\choice.exe"
        copy /y "Windows\System32\zh-CN\choice.exe.mui" "%windir%\System32\zh-CN\choice.exe.mui"
    )
    choice /? || goto :success
)
goto :success

:ask
echo.
echo # 是否设置为Administrator账户登录？（不推荐）
choice
if %errorlevel% equ 1 (
    >"Windows\Setup\pandasysadmin.txt" echo 1
) else (   
    del /f /q "Windows\Setup\pandasysadmin.txt" >nul 2>nul
    echo.
    echo ## 是否设置新建账户的用户名？（默认会自动检测）
    choice
    if !errorlevel! equ 1 (
        echo.
        set /p username=### 请输入用户名：
        >"Windows\Setup\pandasysnewuser.txt" echo !username!
    )
)
goto :success

:success
cls
echo.
echo 恭喜您，系统接管成功。
echo.
if %silent% EQU 0 (
    pause
    del %0
)
exit 0

:error
echo.
echo 错误：%~1
echo.
echo 接管错误, 请检查文件是否释放正确！！！
echo.
if %silent% EQU 0 pause
exit 1