# 豆包刷课状态检查（PowerShell）
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File check-doubao.ps1
#
# 输出三件事：
#   1. 豆包最后活动时间 + 最近动作
#   2. 沙箱里有没有正在跑的任务
#   3. 结论：在跑 / 停了（等你说继续）/ 出错了

param(
    # 轨迹日志路径。留空则自动搜索最新的一条。
    [string]$Traj = ""
)

$ErrorActionPreference = "SilentlyContinue"

# ============ 自动定位轨迹日志 ============
# 豆包把每个会话的动作记录放在：
#   %LOCALAPPDATA%\Doubao\User Data\Default\.doubao\agent_mode\workspace\.sessions\<会话ID>\agents\<代理ID>\system\trajectory.jsonl
# 会话 ID 每次新建会话都会变，所以这里自动找最近写入的那个。
if ([string]::IsNullOrEmpty($Traj)) {
    $sessRoot = Join-Path $env:LOCALAPPDATA "Doubao\User Data\Default\.doubao\agent_mode\workspace\.sessions"
    if (Test-Path $sessRoot) {
        $latest = Get-ChildItem $sessRoot -Recurse -Filter "trajectory.jsonl" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1
        if ($latest) { $Traj = $latest.FullName }
    }
}
# ==========================================

Write-Output "========== 豆包刷课状态 =========="
Write-Output ("检查时间: " + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

# ---------- 1. 豆包进程 ----------
$doubao = Get-Process Doubao -ErrorAction SilentlyContinue
if (-not $doubao) {
    Write-Output ""
    Write-Output "❌ 豆包没在运行！"
    exit 1
}
Write-Output ("豆包进程: " + ($doubao | Measure-Object).Count + " 个")

# ---------- 2. 轨迹日志 ----------
if (-not (Test-Path $Traj)) {
    Write-Output ""
    Write-Output "❌ 找不到轨迹日志，会话ID可能变了"
    Write-Output ("   路径: " + $Traj)
    exit 1
}

$fi = Get-Item $Traj
$idle = ((Get-Date) - $fi.LastWriteTime).TotalMinutes
Write-Output ("最后活动: " + $fi.LastWriteTime.ToString('HH:mm:ss') + "  (已静默 " + [Math]::Round($idle,1) + " 分钟)")

# 最近动作
$titles = Select-String -Path $Traj -Pattern '"title":"([^"]+)"' -AllMatches |
          ForEach-Object { $_.Matches } |
          ForEach-Object { $_.Groups[1].Value }
if ($titles) {
    Write-Output ""
    Write-Output "最近 5 个动作:"
    $titles | Select-Object -Last 5 | ForEach-Object { Write-Output ("  · " + $_) }
}

# ---------- 3. 沙箱任务 ----------
$runners = Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
           Where-Object { $_.CommandLine -like '*gac_runtime.runner*' }
$nRun = ($runners | Measure-Object).Count
Write-Output ""
Write-Output ("沙箱任务: " + $nRun + " 个")

if ($nRun -gt 0) {
    foreach ($p in $runners) {
        try {
            $b64 = ($p.CommandLine -split ' ')[-1]
            $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
            $flat = ($json -replace '\s+', ' ')
            # 抠出 title
            if ($flat -match '"title":"([^"]+)"') {
                Write-Output ("  正在执行: " + $Matches[1])
            }
        } catch {}
    }
}

# ---------- 4. 结论 ----------
Write-Output ""
Write-Output "========== 结论 =========="
if ($nRun -gt 0) {
    Write-Output "✅ 正在干活，不用管"
}
elseif ($idle -lt 5) {
    Write-Output "⏳ 刚停下（5 分钟内），可能在切换页面"
}
else {
    # 看看最后一条是不是"刷完一章"
    $tail = Get-Content $Traj -Tail 3 -ErrorAction SilentlyContinue
    $waiting = $false
    foreach ($line in $tail) {
        if ($line -match '你回|接着从|继续.{0,6}我就') { $waiting = $true }
    }

    if ($waiting) {
        Write-Output "⏸  刷完一章，在等你说「继续」"
        Write-Output ""
        Write-Output "   发送继续:"
        Write-Output "   powershell -NoProfile -ExecutionPolicy Bypass -File _doubao_send.ps1"
    }
    else {
        Write-Output ("⚠️  静默 " + [Math]::Round($idle,1) + " 分钟且无沙箱任务")
        Write-Output "   可能是：刷完一章 / 卡住了 / 出错了"
        Write-Output ""
        Write-Output "   先试发一次继续:"
        Write-Output "   powershell -NoProfile -ExecutionPolicy Bypass -File _doubao_send.ps1"
    }
}
