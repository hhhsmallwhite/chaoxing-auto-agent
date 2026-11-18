# 豆包刷课看门狗（Watchdog）
#
# 作用：后台常驻，自动检测豆包是否停下，停下就发「继续」。
#       全程写日志，方便事后查发生了什么。
#
# 用法（后台跑）：
#   powershell -NoProfile -ExecutionPolicy Bypass -File watchdog.ps1
#
# 用法（前台跑，看实时输出）：
#   powershell -NoProfile -ExecutionPolicy Bypass -File watchdog.ps1 -Verbose

param(
    # 检查间隔（秒）
    [int]$IntervalSec = 60,

    # 静默多久算"停下"（分钟）。豆包视频监控每 ~2 分钟写一次日志，
    # 所以阈值不能太小，3 分钟比较稳。
    [double]$IdleMinutes = 3.0,

    # 发完「继续」后等多久再确认（秒）
    [int]$ConfirmSec = 90,

    # 两次发送之间的最小间隔（分钟），防止狂发
    [double]$CooldownMin = 10.0,

    # 日志文件
    [string]$LogFile = "watchdog.log",

    # 最多循环多少次（0 = 无限）
    [int]$MaxLoops = 0,

    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sendScript = Join-Path $scriptDir "send-jixu.ps1"
$checkScript = Join-Path $scriptDir "check-doubao.ps1"

function Write-Log {
    param([string]$Msg, [string]$Level = "INFO")
    $line = "{0} [{1}] {2}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Level, $Msg
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    if ($Verbose -or $Level -ne "DEBUG") { Write-Host $line }
}

function Get-DoubaoState {
    # 定位最新轨迹日志
    $sessRoot = Join-Path $env:LOCALAPPDATA "Doubao\User Data\Default\.doubao\agent_mode\workspace\.sessions"
    $traj = $null
    if (Test-Path $sessRoot) {
        $latest = Get-ChildItem $sessRoot -Recurse -Filter "trajectory.jsonl" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) { $traj = $latest.FullName }
    }

    # 沙箱进程
    $runners = Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
               Where-Object { $_.CommandLine -like '*gac_runtime.runner*' }
    $nRun = ($runners | Measure-Object).Count

    # 最后活动
    $idle = 9999.0
    $lastTitle = ""
    $lastPct = ""
    $done = $false

    if ($traj -and (Test-Path $traj)) {
        $fi = Get-Item $traj
        $idle = ((Get-Date) - $fi.LastWriteTime).TotalMinutes

        $lines = [IO.File]::ReadAllLines($traj, [Text.Encoding]::UTF8)
        # 最近的动作标题
        $titles = @()
        foreach ($l in $lines) {
            if ($l -match '"title":"([^"]+)"') { $titles += $Matches[1] }
        }
        if ($titles.Count -gt 0) { $lastTitle = $titles[-1] }

        # 最近的视频进度
        # 注意：pct 出现在 tool 结果的 content 字符串里，JSON 转义后是 \"pct\":54，
        # 所以正则要容忍前面有反斜杠。
        $pcts = @()
        foreach ($l in $lines) {
            if ($l -match 'pct\\?"?:(\d+)') { $pcts += [int]$Matches[1] }
        }
        if ($pcts.Count -gt 0) { $lastPct = $pcts[-1] }

        # 判断是否全部完成
        $tail = ($lines | Select-Object -Last 30) -join "`n"
        if ($tail -match '全部完成|课程完成|所有章节.*完成|11\.1.*结束') { $done = $true }
    }

    return [PSCustomObject]@{
        Traj      = $traj
        Sandbox   = $nRun
        IdleMin   = $idle
        LastTitle = $lastTitle
        LastPct   = $lastPct
        Done      = $done
    }
}

# ============ 启动 ============
Write-Log "===== 看门狗启动 ====="
Write-Log "检查间隔=${IntervalSec}s  静默阈值=${IdleMinutes}min  冷却=${CooldownMin}min"
Write-Log "日志: $LogFile"

if (-not (Test-Path $sendScript)) {
    Write-Log "找不到发送脚本: $sendScript" "ERROR"
    exit 1
}

$loop = 0
$lastSent = [DateTime]::MinValue
$sendCount = 0

while ($true) {
    $loop++
    if ($MaxLoops -gt 0 -and $loop -gt $MaxLoops) {
        Write-Log "达到最大循环次数 $MaxLoops，退出"
        break
    }

    $st = Get-DoubaoState
    $idleStr = [Math]::Round($st.IdleMin, 1)

    Write-Log ("状态: 沙箱={0} 静默={1}min 动作=[{2}] 进度={3}%" -f $st.Sandbox, $idleStr, $st.LastTitle, $st.LastPct) "DEBUG"

    # 全部完成？
    if ($st.Done) {
        Write-Log "检测到课程可能已全部完成，退出看门狗" "DONE"
        break
    }

    # 判断是否需要发「继续」
    $needSend = $false
    $reason = ""

    if ($st.Sandbox -eq 0 -and $st.IdleMin -ge $IdleMinutes) {
        $sinceLast = ((Get-Date) - $lastSent).TotalMinutes
        if ($sinceLast -ge $CooldownMin) {
            $needSend = $true
            $reason = "沙箱=0 且静默 ${idleStr}min"
        }
        else {
            Write-Log ("需要发送但冷却中（距上次 {0:N1}min < {1}min）" -f $sinceLast, $CooldownMin) "WARN"
        }
    }

    if ($needSend) {
        Write-Log "→ 判定需要发送「继续」：$reason" "ACTION"
        $lastSent = Get-Date
        $sendCount++

        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $sendScript 2>&1
        $outStr = ($out | Out-String).Trim()
        Write-Log "发送输出: $outStr" "ACTION"

        if ($outStr -match "SENT") {
            Write-Log "✓ 已投递，等待 ${ConfirmSec}s 确认启动"
            Start-Sleep -Seconds $ConfirmSec

            $st2 = Get-DoubaoState
            if ($st2.Sandbox -gt 0) {
                Write-Log ("✓ 确认启动！沙箱={0} 当前动作=[{1}]" -f $st2.Sandbox, $st2.LastTitle) "OK"
            }
            elseif ($st2.IdleMin -lt 2) {
                Write-Log "✓ 日志有新写入，说明它在响应" "OK"
            }
            else {
                Write-Log ("✗ 发完 {0} 秒仍无动静（沙箱={1} 静默={2}min），可能出问题了" -f $ConfirmSec, $st2.Sandbox, [Math]::Round($st2.IdleMin,1)) "ERROR"
                Write-Log "  建议手动跑 check-doubao.ps1 排查" "ERROR"
            }
        }
        else {
            Write-Log "✗ 发送失败，输出里没有 SENT" "ERROR"
        }
    }

    Start-Sleep -Seconds $IntervalSec
}

Write-Log "===== 看门狗结束，共发送 $sendCount 次 ====="
