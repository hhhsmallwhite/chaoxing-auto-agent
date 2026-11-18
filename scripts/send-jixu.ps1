param(
    # 默认发送“继续”。用码点构造，避免任何编码/命令行传参问题。
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($Message)) {
    # U+7EE7 U+7EED = 继续
    $Message = [string][char]0x7EE7 + [string][char]0x7EED
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Dbx {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
}
"@

$WM_KEYDOWN = 0x0100
$WM_KEYUP   = 0x0101
$WM_CHAR    = 0x0102
$VK_BACK    = 0x08
$VK_RETURN  = 0x0D

# ---------- 1. 找豆包窗口 ----------
$root = [System.Windows.Automation.AutomationElement]::RootElement
$pids = (Get-Process Doubao -ErrorAction SilentlyContinue).Id
if (-not $pids) { Write-Output "ERR 豆包没在运行"; exit 1 }

$found = $null
foreach ($procId in $pids) {
    $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $procId)
    foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
        if ($w.Current.Name -and $w.Current.Name.Length -gt 0) { $found = $w; break }
    }
    if ($found) { break }
}
if (-not $found) { Write-Output "ERR 找不到豆包主窗口"; exit 1 }

$hwndTop = [IntPtr]$found.Current.NativeWindowHandle
Write-Output ("WIN  hwnd=" + $hwndTop + "  title=" + $found.Current.Name)

# ---------- 2. 找输入框 ----------
$all = $found.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
$pm = $null
foreach ($e in $all) {
    $cn = $e.Current.ClassName
    if ($cn -like "tiptap ProseMirror*" -and $cn -notlike "*trailingBreak*") { $pm = $e }
}
if (-not $pm) { Write-Output "ERR 找不到输入框(ProseMirror)"; exit 1 }

for ($i = 0; $i -lt 8; $i++) {
    try { $pm.SetFocus() } catch {}
    Start-Sleep -Milliseconds 300
    if ($pm.Current.HasKeyboardFocus) { break }
}

# ---------- 3. 找渲染窗口 ----------
$script:rw = [IntPtr]::Zero
$cb = [Dbx+EnumProc]{
    param($h, $l)
    $sb = New-Object Text.StringBuilder 512
    [void][Dbx]::GetClassName($h, $sb, 512)
    if ($sb.ToString() -eq "Chrome_RenderWidgetHostHWND") { $script:rw = $h }
    return $true
}
[void][Dbx]::EnumChildWindows($hwndTop, $cb, [IntPtr]::Zero)
if ($script:rw -eq [IntPtr]::Zero) { Write-Output "ERR 找不到 Chrome_RenderWidgetHostHWND"; exit 1 }

# ---------- 4. 清空输入框 ----------
for ($i = 0; $i -lt 80; $i++) {
    [void][Dbx]::SendMessage($script:rw, $WM_KEYDOWN, [IntPtr]$VK_BACK, [IntPtr]0x000E0001)
    [void][Dbx]::SendMessage($script:rw, $WM_KEYUP,   [IntPtr]$VK_BACK, [IntPtr]0xC00E0001)
}
Start-Sleep -Milliseconds 500

# ---------- 5. 打字：GBK 双字节打包成 wParam ----------
# 关键点：直接按 Unicode 码点发 WM_CHAR 会被 Chromium 按 GBK 解释，
# 结果变成乱码（“继续” -> “鐍韣”）。必须先把字符编成 GBK 字节，
# 再按 (低字节 + 高字节*256) 拼成 wParam。
try { [Text.Encoding]::RegisterProvider([Text.CodePagesEncodingProvider]::Instance) } catch {}
$gbk = [Text.Encoding]::GetEncoding(936)
$bytes = $gbk.GetBytes($Message)
$i = 0
while ($i -lt $bytes.Length) {
    $b1 = [int]$bytes[$i]
    if ($b1 -lt 0x80) { $w = $b1; $i += 1 }
    else { $b2 = [int]$bytes[$i + 1]; $w = ($b2 * 256) + $b1; $i += 2 }
    [void][Dbx]::SendMessage($script:rw, $WM_CHAR, [IntPtr]$w, [IntPtr]1)
    Start-Sleep -Milliseconds 90
}
Start-Sleep -Milliseconds 700

# ---------- 6. 读回校验 ----------
$tp = $null
if ($pm.TryGetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern, [ref]$tp)) {
    $txt = $tp.DocumentRange.GetText(-1).Trim()
    Write-Output ("TYPED=[" + $txt + "]")
    if ($txt -ne $Message) {
        Write-Output ("MISMATCH 期望=[" + $Message + "] 实际=[" + $txt + "]")
        exit 2
    }
}

# ---------- 7. 回车发送 ----------
[void][Dbx]::SendMessage($script:rw, $WM_KEYDOWN, [IntPtr]$VK_RETURN, [IntPtr]0x001C0001)
Start-Sleep -Milliseconds 150
[void][Dbx]::SendMessage($script:rw, $WM_KEYUP,   [IntPtr]$VK_RETURN, [IntPtr]0xC01C0001)
Start-Sleep -Milliseconds 1200
Write-Output "SENT"
