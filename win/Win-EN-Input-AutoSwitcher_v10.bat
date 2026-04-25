<# :
@echo off
setlocal
chcp 65001 >nul

:: 1. 自动请求管理员权限
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' neq '0' (
    goto UACPrompt
) else ( goto gotAdmin )
:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B
:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )

:: 2. 直接调用内置 PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command "IEX ([System.IO.File]::ReadAllText('%~f0'))"
goto :eof
#>

# ============================================================
# 核心逻辑 - 典藏完美版 (浏览器免检 + 竞态双杀 + 精细分类注释)
# ============================================================
$TaskName = "WindowsInputAutoSwitcher"
$InstallDir = "$env:ProgramData\InputAutoSwitcher"
$ExePath = "$InstallDir\AutoSwitcher.exe"

function Stop-App {
    cmd.exe /c "taskkill /F /IM AutoSwitcher.exe /T >nul 2>&1"
    Start-Sleep -Seconds 1 
}

# 1. 🛠️ 原生 C# 源代码
$csharpCode = @"
using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Diagnostics;
using System.Collections.Generic;

namespace AutoSwitcher {
    class Program {
        [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
        [DllImport("user32.dll")] static extern IntPtr LoadKeyboardLayout(string pwszKLID, uint Flags);
        [DllImport("user32.dll")] static extern IntPtr GetKeyboardLayout(uint idThread);
        
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
        
        [DllImport("imm32.dll")] static extern IntPtr ImmGetDefaultIMEWnd(IntPtr hWnd);
        
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT { public int left; public int top; public int right; public int bottom; }

        [StructLayout(LayoutKind.Sequential)]
        public struct GUITHREADINFO {
            public uint cbSize; public uint flags; public IntPtr hwndActive; public IntPtr hwndFocus;
            public IntPtr hwndCapture; public IntPtr hwndMenuOwner; public IntPtr hwndMoveSize;
            public IntPtr hwndCaret; public RECT rcCaret; 
        }
        [DllImport("user32.dll")] static extern bool GetGUIThreadInfo(uint idThread, ref GUITHREADINFO lpgui);

        static void SafeSendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam) {
            if (hWnd != IntPtr.Zero) {
                IntPtr result;
                SendMessageTimeout(hWnd, Msg, wParam, lParam, 0x0002, 50, out result);
            }
        }

        static void ForceImeState(IntPtr fgHwnd, IntPtr targetHwnd, bool toChinese) {
            IntPtr openStatus = (IntPtr)(toChinese ? 1 : 0);
            IntPtr convMode1 = (IntPtr)(toChinese ? 1 : 0);
            IntPtr convMode2 = (IntPtr)(toChinese ? 1025 : 0);

            IntPtr[] hwnds = { targetHwnd, fgHwnd };
            foreach (IntPtr hwnd in hwnds) {
                if (hwnd == IntPtr.Zero) continue;
                IntPtr imeWnd = ImmGetDefaultIMEWnd(hwnd);
                
                if (imeWnd != IntPtr.Zero) {
                    SafeSendMessage(imeWnd, 0x0283, (IntPtr)6, openStatus); 
                    SafeSendMessage(imeWnd, 0x0283, (IntPtr)2, convMode1);  
                    SafeSendMessage(imeWnd, 0x0283, (IntPtr)2, convMode2);
                }
                SafeSendMessage(hwnd, 0x0283, (IntPtr)6, openStatus);
                SafeSendMessage(hwnd, 0x0283, (IntPtr)2, convMode1);
                SafeSendMessage(hwnd, 0x0283, (IntPtr)2, convMode2);
            }
        }

        static void Main() {
            bool createdNew;
            using (Mutex mutex = new Mutex(true, "Global\\WinInputAutoSwitcherMutex", out createdNew)) {
                if (!createdNew) return;
                
                IntPtr hChinese = LoadKeyboardLayout("00000804", 1); 
                IntPtr lastFgWindow = IntPtr.Zero; 
                IntPtr lastTargetHwnd = IntPtr.Zero;
                
                // 🛡️ VIP 免检名单 (系统组件 + 浏览器)
                // 交还给 Windows 原生管理，防止脚本干扰 Chromium 沙盒导致变英文
                HashSet<string> ignoreApps = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
                    "explorer", "ShellExperienceHost", "SearchHost", "TextInputHost", "LockApp", "Idle", "dwm", "Taskmgr", "SearchApp", "StartMenuExperienceHost",
                    "chrome", "msedge", "firefox", "brave", "opera", "safari", "iexplore", "360se", "360chrome", "sogouexplorer", "qqbrowser", "yandex", "vivaldi"
                };

                // 🌟 13大类全景研发工具名单 (精细分类典藏版)
                HashSet<string> apps = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
                    // 1. 通用编辑器与 AI 编码辅助
                    "Code", "Cursor", "Windsurf", "Trae", "Zed", "VSCodium", "Atom", "sublime_text", "notepad++",
                    
                    // 2. Java 开发生态 (含 JVM 监控工具)
                    "idea64", "eclipse", "myeclipse", "netbeans", "sts", "jvisualvm", "jconsole", "jadx-gui", "java", "javaw",
                    
                    // 3. Python, 算法与数据科学 (AI / 大数据)
                    "pycharm64", "python", "pythonw", "jupyter-notebook", "jupyter-lab", "spyder", "anaconda-navigator", "tensorboard", "netron", "matlab", "rstudio",
                    
                    // 4. 前端开发与 Node.js 运行环境
                    "webstorm64", "HBuilder", "HBuilderX", "wechatdevtools", "node", "npm", "yarn", "pnpm", "electron", "nw", "Brackets",
                    
                    // 5. C/C++, C#, Go, Rust, PHP 等其他后端环境
                    "devenv", "vcexpress", "wdexpress", "clion64", "rider64", "goland64", "rustrover64", "phpstorm64", "rubymine64", "devc++", "codeblocks", "qtcreator",
                    
                    // 6. 测试工程师 (QA), API 调试与网络抓包
                    "Postman", "Apifox", "Fiddler", "Charles", "Wireshark", "JMeter", "SoapUI", "Katalon", "Insomnia", "Proxyman", "burpsuite", "burpsuite_pro", "zap", "appium", "selenium", "cypress", "playwright",
                    
                    // 7. 产品交互设计, UI/UX 与 3D 建模 (快捷键重度依赖区)
                    "Figma", "Pixso", "MasterGo", "AxureRP10", "AxureRP9", "AxureRP8", "Photoshop", "Illustrator", "xd", "InDesign", "AfterFX", "Premiere", "blender", "c4d", "zbrush", "rhinoceros", "maya", "3dsmax", "eagle",
                    
                    // 8. 数据库、缓存可视化与数据管理
                    "Navicat", "navicat", "dbeaver", "datagrip64", "TablePlus", "redis-desktop-manager", "Another Redis Desktop Manager", "Studio 3T", "HeidiSQL", "SQLyog", "pgAdmin4", "sqldeveloper", "plsqldev", "dbvis", "robomongo", "mongod", "mongosh",
                    
                    // 9. 终端, SSH 客户端与本地命令行
                    "WindowsTerminal", "powershell", "pwsh", "cmd", "XTerminal", "MobaXterm", "Xshell", "finalshell", "putty", "Termius", "SecureCRT", "bash", "wsl", "mintty",
                    
                    // 10. DevOps, 容器, 虚拟机与版本控制客户端
                    "Docker Desktop", "docker", "kubectl", "minikube", "lens", "sourcetree", "Fork", "githubdesktop", "gitea", "vagrant", "vmware", "VirtualBox",
                    
                    // 11. 嵌入式底层开发, 单片机与 EDA 硬件设计
                    "Keil", "UV4", "iaride", "Stm32CubeIDE", "Arduino IDE", "esp-idf", "SourceInsight", "Altium Designer", "DXP", "proteus", "quartus", "vivado",
                    
                    // 12. 安全分析, 逆向工程与十六进制编辑器
                    "ida64", "ida", "WinDbg", "x64dbg", "x32dbg", "ghidra", "cutter", "HxD", "WinHex", "010Editor", "dnSpy", "ILSpy", "BinaryNinja",
                    
                    // 13. 研发文档写作, 架构图, 知识库与代码比对
                    "Typora", "Obsidian", "Logseq", "Notion", "Swagger", "marktext", "joplin", "bcompare", "winmerge", "Unity", "Unity Hub"
                };
                
                while (true) {
                    try {
                        IntPtr fgWindow = GetForegroundWindow();
                        if (fgWindow != IntPtr.Zero) {
                            uint processId;
                            uint threadId = GetWindowThreadProcessId(fgWindow, out processId);
                            
                            if (processId > 4) {
                                IntPtr targetHwnd = fgWindow;
                                GUITHREADINFO guiInfo = new GUITHREADINFO();
                                guiInfo.cbSize = (uint)Marshal.SizeOf(guiInfo);
                                if (GetGUIThreadInfo(threadId, ref guiInfo)) {
                                    if (guiInfo.hwndFocus != IntPtr.Zero) { targetHwnd = guiInfo.hwndFocus; }
                                }

                                if (fgWindow != lastFgWindow || targetHwnd != lastTargetHwnd) {
                                    // 必须先更新指针，避免遇到免检程序时死循环消耗 CPU
                                    lastFgWindow = fgWindow; 
                                    lastTargetHwnd = targetHwnd;
                                    
                                    string pName = "";
                                    try {
                                        using (Process p = Process.GetProcessById((int)processId)) {
                                            pName = p.ProcessName;
                                        }
                                    } catch { continue; } 
                                    
                                    // 遇到浏览器和系统组件，脚本立刻“装瞎”，交由 Windows 原生接管状态
                                    if (ignoreApps.Contains(pName)) { continue; }
                                    
                                    bool isDevApp = apps.Contains(pName);

                                    // 先等 Windows 底层把恶心的 Shift 记忆恢复完
                                    Thread.Sleep(50);
                                    
                                    // 统一穿上 0804 外衣，保住你的 Shift 快捷键
                                    IntPtr currentHkl = GetKeyboardLayout(threadId);
                                    if (currentHkl != hChinese) {
                                        SafeSendMessage(targetHwnd, 0x0050, IntPtr.Zero, hChinese);
                                    }

                                    // 双杀强制覆盖，彻底粉碎记忆
                                    for (int i = 0; i < 2; i++) {
                                        ForceImeState(fgWindow, targetHwnd, !isDevApp);
                                        Thread.Sleep(50); 
                                    }
                                }
                            }
                        }
                    } catch { }
                    Thread.Sleep(100); // 极低功耗休眠
                }
            }
        }
    }
}
"@

# 2. 🚀 即时编译引擎
function Build-Exe {
    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
    Stop-App
    Write-Host "⚙️ 正在为您即时编译原生守护程序..." -ForegroundColor Yellow
    Add-Type -TypeDefinition $csharpCode -Language CSharp -OutputAssembly $ExePath -OutputType WindowsApplication -ErrorAction Stop
}

function Install-Service {
    try {
        Build-Exe
        
        $Action = New-ScheduledTaskAction -Execute $ExePath
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger (New-ScheduledTaskTrigger -AtLogon) -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable) -RunLevel Highest -Force | Out-Null
        
        Start-ScheduledTask -TaskName $TaskName
        
        Write-Host "✅ 典藏完美版部署完成！兼顾性能与优雅！" -ForegroundColor Green
        Write-Host "🎯 现在请直接点右上角 X 关掉黑窗口，尽情享受吧！" -ForegroundColor Cyan
    } catch {
        Write-Host "❌ 部署失败：$_" -ForegroundColor Red
    }
}

function Uninstall-Service {
    Write-Host "`n清理系统中..." -ForegroundColor Yellow
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    Stop-App
    if (Test-Path $InstallDir) { Remove-Item -Path $InstallDir -Recurse -Force }
    Write-Host "✅ 已彻底卸载并清理残留。" -ForegroundColor Green
}

# ============================================================
# 用户交互界面
# ============================================================
while ($true) {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "   Windows 研发输入法智能切换 (典藏完美版)   " -ForegroundColor Cyan
    Write-Host "============================================="
    if (Test-Path $ExePath) { Write-Host " 状态: [已部署] 原生 EXE 守护进程运行中" -ForegroundColor Green } else { Write-Host " 状态: [未部署]" -ForegroundColor DarkGray }
    Write-Host "---------------------------------------------"
    Write-Host " [1] 🚀 立即测试"
    Write-Host " [2] 💻 一键安装 (编译原生 EXE 并后台生效)"
    Write-Host " [3] 🗑️ 彻底卸载"
    Write-Host " [0] 退出"
    Write-Host "---------------------------------------------"
    $choice = Read-Host " 请选择序号"
    switch ($choice) { 
        '1' { Build-Exe; Start-Process $ExePath; Write-Host "✅ 测试服务已启动！可以关掉此窗口了。"; pause } 
        '2' { Install-Service; pause } 
        '3' { Uninstall-Service; pause } 
        '0' { exit } 
    }
}