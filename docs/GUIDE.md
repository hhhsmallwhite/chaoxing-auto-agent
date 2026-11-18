# 手机遥控 DSH、DSH 指挥豆包刷学习通 —— 完整操作手册

> 写给第一次接触的人。照着做就能复现：**人在外面用手机 → 指挥家里的 DSH → DSH 去催豆包 → 豆包自己刷学习通视频和章节测验**。

---

## 目录

- [0. 先看全局：这套东西由四层组成](#0-先看全局这套东西由四层组成)
- [第一部分：让豆包刷学习通视频](#第一部分让豆包刷学习通视频)
  - [1.1 需要准备什么](#11-需要准备什么)
  - [1.2 第一步：把课程链接和需求发给豆包](#12-第一步把课程链接和需求发给豆包)
  - [1.3 第二步：处理视频被暂停的问题（最关键）](#13-第二步处理视频被暂停的问题最关键)
  - [1.4 第三步：自动做章节测验](#14-第三步自动做章节测验)
  - [1.5 第四步：怎么确认一节的真实状态](#15-第四步怎么确认一节的真实状态)
  - [1.6 最重要的一点：豆包刷完一章就会停](#16-最重要的一点豆包刷完一章就会停)
  - [1.7 进度怎么查（不用看屏幕）](#17-进度怎么查不用看屏幕)
- [第二部分：远程操控 DSH](#第二部分远程操控-dsh)
  - [2.1 原理](#21-原理)
  - [2.2 电脑端配置（一次性）](#22-电脑端配置一次性)
  - [2.3 手机端配置](#23-手机端配置)
  - [2.4 手机上能做什么](#24-手机上能做什么)
  - [2.5 备用通道：QQ（可选）](#25-备用通道qq可选)
- [第三部分：把两边接起来](#第三部分把两边接起来手机上怎么指挥)
  - [3.1 实际对话长什么样](#31-实际对话长什么样)
  - [3.2 难点：怎么把字打进豆包](#32-难点怎么把字打进豆包)
  - [3.3 常用指令模板](#33-常用指令模板)
  - [3.4 无人值守：让它自己循环](#34-无人值守让它自己循环)
- [第四部分：故障排查](#第四部分故障排查)
  - [4.1 豆包不动了](#41-豆包不动了)
  - [4.2 视频不动 / 进度不涨](#42-视频不动--进度不涨)
  - [4.3 发消息发不进去](#43-发消息发不进去)
  - [4.4 手机连不上电脑](#44-手机连不上电脑)
  - [4.5 电脑睡着了](#45-电脑睡着了)
- [附录 A：完整发送脚本](#附录-a完整发送脚本)
- [附录 B：一页速查](#附录-b一页速查)
- [附录 C：状态检查脚本](#附录-c状态检查脚本)

---

## 0. 先看全局：这套东西由四层组成

```
┌──────────────┐   HTTPS 加密    ┌──────────────────┐   本机窗口消息   ┌──────────────┐
│  手机 / 平板  │ ─────────────► │  DSH（电脑上跑）  │ ─────────────► │  豆包桌面版   │
│  Remote App  │                │  智能体 + 工具    │                │  任务模式     │
└──────────────┘                └──────────────────┘                └──────────────┘
                                         │                                  │
                                         │ 读日志文件                        │ 浏览器自动化
                                         ▼                                  ▼
                                  trajectory.jsonl                  学习通网页（视频+测验）
```

四层的分工：

| 层 | 是什么 | 干什么 |
|---|---|---|
| **第一层** | 手机上的 DSH Remote（安卓 App 或网页） | 你在外面发一句话 |
| **第二层** | DSH（DeepSeek Harness 桌面版） | 收到话，理解意图，去操作豆包 |
| **第三层** | 豆包桌面版「任务模式」 | 真正干活的，它有自己的浏览器和沙箱 |
| **第四层** | 学习通网页 | 视频 + 章节测验 |

**关键认知**：DSH 和豆包都是"智能体"，DSH 不直接刷视频，它只负责**催豆包干活**。真正刷视频的是豆包。

---

# 第一部分：让豆包刷学习通视频

## 1.1 需要准备什么

| 项目 | 要求 |
|---|---|
| 豆包桌面版 | 装好并登录，版本 147.x 以上（自带「任务模式」/ Agent 模式） |
| 学习通账号 | 在豆包的浏览器里已登录 |
| 电脑 | **不能睡眠、不能关机**，屏幕可以锁着 |
| 网络 | 稳定，视频要连续播放几小时 |

> 实测：屏幕锁定状态不影响豆包干活。豆包走的是自己的浏览器进程，不需要你看着屏幕。

## 1.2 第一步：把课程链接和需求发给豆包

打开豆包，**切到「任务模式」**（不是普通聊天），然后发这段话（把链接换成你自己的）：

```
https://mooc2-ans.chaoxing.com/mooc2-ans/mycourse/stu?courseid=XXXXXX&clazzid=XXXXXX&cpi=XXXXXX&enc=XXXXXX&pageHeader=1&v=2&hideHead=0

你进去之后帮我刷视频。
每个小节里面有两部分：第一部分是视频，第二部分是章节测验。
每完成一个小节，先把视频看完，再把对应的测验做了，做完刷新一下页面确认这个节变成"已完成"，再点下一个节点。
一直挂在后台看着，一节一节往下推进。
```

**为什么这样写**：
- 学习通的章节是**串行解锁**的——上一节没完成，下一节点不进去。所以必须强调"按顺序"。
- 每节必须**视频 + 测验都完成**才算过，只刷视频不顶用。
- "刷新确认"这一步不能省，它是判断这一节真的过了的唯一可靠信号。

## 1.3 第二步：处理"视频被暂停"的问题（最关键）

学习通有反作弊机制：**页面切到后台、鼠标离开、窗口失焦，视频就会自动暂停**。

豆包会自己往页面里注入一段脚本解决这个问题。核心思路是**把播放器的暂停能力废掉**：

```javascript
(function(){
  // 1. 找到视频元素（学习通嵌了多层 iframe，要递归找）
  function walk(w, d){
    if (d > 4) return null;
    try {
      var v = w.document.querySelector('video');
      if (v) return v;
      for (var i = 0; i < w.frames.length; i++){
        var r = walk(w.frames[i], d + 1);
        if (r) return r;
      }
    } catch(e){}
    return null;
  }
  var v = walk(window, 0);
  if (!v) return 'novideo';
  window.__V = v;

  // 2. 废掉 pause()
  var proto = v.ownerDocument.defaultView.HTMLMediaElement.prototype;
  if (!proto.__np){
    proto.__np = true;
    proto.pause = function(){ return; };   // 谁调 pause 都没用
  }

  // 3. 每秒钟"踢"一脚：暂停了就重新播，倍速被改了拉回 1
  window.__RATE = 1;
  var kick = function(){
    if (!v.duration || v.ended) return;
    if (v.paused) { v.muted = true; try { v.play(); } catch(e){} }
    if (v.playbackRate !== window.__RATE) {
      try { v.playbackRate = window.__RATE; } catch(e){}
    }
  };
  if (!window.__kb){
    window.__kb = true;
    v.addEventListener('timeupdate', kick);
    setInterval(kick, 1000);
  }
  kick();
  return JSON.stringify({ t: Math.round(v.currentTime), p: v.paused });
})()
```

### ⚠️ 倍速必须是 1 倍，不能加速

这是踩过的坑，一定要知道：

> 用 2 倍速播了 20 分钟，页面显示"已看完"，但**服务端只记录了 51% 的观看时长**，任务点不通过。

原因：学习通按**真实观看秒数**上报，服务端累加。你 2 倍速播 10 分钟，它只收到 5 分钟。所以 `window.__RATE` 必须设成 `1`。

### 如果页面还是会暂停：再补一层"可见性伪装"

有些情况下学习通读的是 `document.visibilityState`，还要把这一层也骗过去：

```javascript
(function(){
  function patch(w, d){
    if (d > 4) return;
    try {
      var doc = w.document;
      if (!doc.__vp){
        doc.__vp = true;
        try { Object.defineProperty(doc, 'hidden', { get: function(){ return false; }, configurable: true }); } catch(e){}
        try { Object.defineProperty(doc, 'visibilityState', { get: function(){ return 'visible'; }, configurable: true }); } catch(e){}
        try { doc.hasFocus = function(){ return true; }; } catch(e){}
        try { doc.addEventListener('visibilitychange', function(e){ e.stopImmediatePropagation(); }, true); } catch(e){}
        try { w.addEventListener('blur', function(e){ e.stopImmediatePropagation(); }, true); } catch(e){}
      }
      for (var i = 0; i < w.frames.length; i++){ patch(w.frames[i], d + 1); }
    } catch(e){}
  }
  patch(window, 0);
  return 'patched';
})()
```

## 1.4 第三步：自动做章节测验

学习通的测验页藏在**三层嵌套 iframe** 里，DOM 结构大致是：

```
document
└─ #iframe
   └─ iframe
      └─ iframe      ← 题目在这里
```

答题的关键选择器：

```javascript
// 进入最内层
var d1 = document.getElementById('iframe').contentDocument;
var s1 = d1.querySelector('iframe').contentDocument;
var s2 = s1.querySelector('iframe').contentDocument;

// 每道题的选项是 li[qid="题目ID"] 里的 .num_option
// 选项的答案标识在 data 属性里（A/B/C/D，判断题是 true/false）
s2.querySelectorAll('li[qid="405365386"]').forEach(function(li){
  var n = li.querySelector('.num_option, .num_option_dx');
  if (n && n.getAttribute('data') === 'B') li.click();
});
```

- 单选题：点一个 `.num_option`
- 多选题：点多个
- 判断题：`data` 是 `true` / `false`
- 选中后该元素会带上 `check_answer` 类名，可以用它回读确认

> 测验是**开卷**的，题目就在页面上。豆包读题、判断、点选、提交，全程自己做。

## 1.5 第四步：怎么确认一节的真实状态

别信页面上的绿色对勾，要看**侧边栏的隐藏字段**：

```javascript
(function(){
  var act = '', unf = null, all = [];
  document.querySelectorAll('div.posCatalog_select').forEach(function(s){
    var no  = (s.querySelector('.posCatalog_sbar') || {innerText:''}).innerText.trim();
    var inp = s.querySelector('input.jobUnfinishCount');   // ← 真正的未完成数
    var v   = inp ? parseInt(inp.value, 10) : 0;
    if (v > 0) all.push(no + ':' + v);
    if (s.className.indexOf('posCatalog_active') > -1) { act = no; unf = v; }
  });
  return JSON.stringify({ act: act, unf: unf, all: all.slice(0, 5) });
})()
```

**判读方法**：
- `unf: 0` → 这一节真的完成了
- `all: ["6.1:2"]` → 下一节已经解锁，还有 2 个任务点（视频 + 测验）
- 这是唯一可靠的信号，页面上显示"已完成"也可能是假的

## 1.6 ⚠️ 最重要的一点：豆包刷完一章就会停

这是**必须提前知道**的行为，否则你会以为它挂了：

> 豆包**不会一口气刷到底**。它每刷完一章（比如第 4 章 4.1–4.8 全部完成），就会停下来，输出一份总结表格，然后说：
> **"你回「继续」，我就接着从 5.1 开始。"**

它停下时：
- 沙箱里没有正在跑的 Python 任务
- 轨迹日志停止写入
- 界面上在等你的下一句话

**所以整个流程是：你（或 DSH）每隔 1–1.5 小时发一次「继续」。**

一节课的视频 13–20 分钟，一章 5–10 节，所以一章大约 1–2.5 小时。

## 1.7 进度怎么查（不用看屏幕）

豆包把每一步动作都写进一个日志文件：

```
C:\Users\<用户名>\AppData\Local\Doubao\User Data\Default\
  .doubao\agent_mode\workspace\.sessions\<会话ID>\agents\<代理ID>\system\trajectory.jsonl
```

每一行是一个 JSON，`title` 字段就是当前动作名，比如：

```json
{"title":"打开6.2并启动视频"}
{"title":"6.2视频监控1"}
{"title":"作答并提交6.2测验"}
{"title":"确认第6章完成"}
```

查最近在干嘛（PowerShell 一行）：

```powershell
# 把 <会话ID> <代理ID> 换成你自己目录里的实际名字（见 1.7 开头的目录说明）
$t = "$env:LOCALAPPDATA\Doubao\User Data\Default\.doubao\agent_mode\workspace\.sessions\<会话ID>\agents\<代理ID>\system\trajectory.jsonl"
(Get-Item $t).LastWriteTime            # 最后活动时间
Select-String -Path $t -Pattern '"title":"([^"]+)"' -AllMatches |
  ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } |
  Select-Object -Last 5                # 最近 5 个动作
```

**判断它是否还在干活**：

```powershell
(Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
  Where-Object { $_.CommandLine -like '*gac_runtime.runner*' } |
  Measure-Object).Count
```

- `1` → 正在跑
- `0` → 停下来了（要么这章刷完了，要么出错了）

---

# 第二部分：远程操控 DSH

## 2.1 原理

DSH 本身跑在你家里的电脑上，**不开放公网端口**。远程访问靠插件 `ds-harness-remote`：

```
手机 App ──加密隧道──► 中转服务器 (dsh.r2049.cn) ◄──主动外连── 你家电脑的 DSH
```

- 电脑**只主动往外连**，不监听公网端口，不用配路由器端口转发
- 端到端加密（Noise IK / X25519 / ChaCha20-Poly1305），中转服务器看不到内容
- 手机和电脑都要在**同一个账号**下，且电脑端要把手机设备"信任"一次

## 2.2 电脑端配置（一次性）

### 装插件

DSH 桌面版 → **扩展 / 插件管理** → 从 npm 安装：

```
ds-harness-remote@0.6.4
```

装完**重启 DSH**。

> 命令行方式（如果桌面版不方便）：
> ```sh
> dsh plugin --profile desktop add -w ds-harness-remote@0.6.4
> ```

### 开启 Host 模式

插件配置里这几项（一般装完就默认对）：

```yaml
enabled: true
role: host
serverUrl: https://dsh.r2049.cn
```

### 登录并生成配对码

DSH 界面 → **Remote 面板** → 用 GitHub 账号登录 → 生成配对二维码。

配对信息存在这里（**别外传，含令牌**）：

```
C:\Users\<用户名>\.dsh\ds-harness-remote\servers\<服务器ID>\host\
  ├─ device.json              本机身份
  ├─ device.key               私钥
  ├─ server-credentials.json  账号令牌
  ├─ host-pairing.json        配对会话（二维码内容在这）
  └─ trusted-peers.json       已信任的设备列表
```

## 2.3 手机端配置

两个选择，任选其一：

| 方式 | 地址 / 来源 | 适合 |
|---|---|---|
| **安卓 App** | GitHub Releases：`liguobao/ds-harness-remote` | 日常用，体验最好 |
| **网页版** | https://dsh.r2049.cn/app | 临时用，任何浏览器都行 |

### 配对步骤

1. 手机打开 App / 网页
2. 用**同一个账号**登录
3. 扫电脑上 Remote 面板显示的二维码（或在 App 里输入配对码）
4. 电脑端会弹"是否信任此设备" → **允许**
5. 手机端就能看到电脑上的工作区了

信任之后，设备会记在 `trusted-peers.json` 里，下次不用再配对：

```json
{
  "deviceId": "e09fa4d0-...",
  "name": "V2405A · DSH Remote",
  "platform": "android",
  "fingerprint": "F114 42F6 655D"
}
```

## 2.4 手机上能做什么

配对成功后，手机端就是 DSH 的**完整遥控器**：

| 能做的事 | 说明 |
|---|---|
| 看正在跑的会话 | 实时看它每一步在干什么 |
| 发消息 | 直接输入，就像坐在电脑前 |
| 回答提问 | DSH 问你问题时，手机上能答 |
| 批准权限 | 需要授权的操作，手机上点允许 |
| 打断 | 发现跑偏了，随时叫停 |
| 看文件 | 浏览工作区文件、看图片 |
| 开新会话 | 起一个新的任务 |

**关键**：手机端发的话，和你坐在电脑前打字**完全等价**。DSH 分不出来。

## 2.5 备用通道：QQ（可选）

如果嫌装 App 麻烦，还有一条路——**用 QQ 指挥**。

需要装两个插件：

| 插件 | 作用 |
|---|---|
| `dsh-napcat-keeper` | 自动拉起 NapCat（QQ 机器人后端） |
| `dsh-qq-link` | DSH ↔ QQ 双向转发 |

工作方式：
- 你在 QQ 里发消息 → 插件每 4 秒轮询一次 → 转进 DSH 会话 → DSH 开始干活
- DSH 说完最后一句 → 自动发回你的 QQ

配置文件：`C:\Users\<用户名>\.dsh\qq-bridge-config.json`

```json
{
  "总开关": true,
  "试运行": false,
  "私聊会话": "session-xxxx",
  "私聊QQ": "你的QQ号",
  "NapCat": "http://127.0.0.1:3000"
}
```

⚠️ 注意两点：
- **默认是关闭的**（`总开关: false`、`试运行: true`），要手动打开
- NapCat 必须在跑（`127.0.0.1:3000` 有监听），否则收发都不通

> 这条路的好处是**不用装 App、不用配对**，微信/QQ 就能指挥。
> 坏处是配置更麻烦，而且 QQ 号有被风控的风险。

---

# 第三部分：把两边接起来——手机上怎么指挥

## 3.1 实际对话长什么样

手机上打开 DSH Remote，进入那个正在刷课的会话，发一句：

```
看下豆包还在刷没，停了就让它继续
```

DSH 会做这几件事：

1. **读日志**判断豆包状态
   ```
   trajectory.jsonl 最后写入时间 + 最近动作 + 沙箱进程数
   ```
2. **判断**：还在跑 → 直接汇报；停了 → 往下走
3. **发消息给豆包**（这一步是技术难点，见 3.2）
4. **确认送达**：读回输入框内容 + 看日志里有没有出现 `{"role":"user","content":"继续"}`
5. **确认启动**：看沙箱进程数从 0 变成 1

## 3.2 难点：怎么把字"打"进豆包

正常情况下点一下输入框、打字、回车就行。但有个特殊场景：**电脑锁屏了**。

锁屏时：
- 截图全黑
- 鼠标点击无效
- `SendInput` 模拟键盘无效
- `SetForegroundWindow` 被拒绝

**解决办法**：绕过输入系统，直接往窗口投递消息。

### 三个坑，一个都不能踩

#### 坑 1：不能用 `SendInput` / `keybd_event`

锁屏时这些 API 全部失效——它们依赖输入桌面，而锁屏时输入桌面被 `LockApp` 占着。

#### 坑 2：`WM_CHAR` 的 wParam 不是 Unicode 码点

这是最阴的一个。Chromium 收到 `WM_CHAR` 后，会按**当前代码页（GBK）**去解释 wParam 的低 16 位。

所以直接发码点会变成乱码：

| 你发的 | 实际出现 |
|---|---|
| `U+7EE7`（继） | `鐍`（U+940D） |
| `U+7EED`（续） | `韣`（U+97E3） |

**正确做法**：先把字符编成 GBK 字节，再按 `低字节 + 高字节 × 256` 拼成 wParam。

```
"继" → GBK = BC CC → wParam = 0xCCBC
"续" → GBK = D0 F8 → wParam = 0xF8D0
```

#### 坑 3：要发给渲染窗口，不是顶层窗口

```
顶层窗口 (hwnd 263546, 类名 Chrome_WidgetWin_1)
  └─ Chrome_RenderWidgetHostHWND (hwnd 591574)   ← 发这里
  └─ Intermediate D3D Window
```

### 完整脚本

已经写好了，直接跑：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts/send-jixu.ps1"
```

脚本逻辑（简化版）：

```powershell
# 1. 用 UIA 找到豆包窗口和输入框
$pm = <class 匹配 'tiptap ProseMirror' 的元素>
$pm.SetFocus()

# 2. 找到 Chrome_RenderWidgetHostHWND
[void][Dbx]::EnumChildWindows($hwndTop, $cb, [IntPtr]::Zero)

# 3. 清空输入框（连按 80 次退格）
for ($i = 0; $i -lt 80; $i++) {
    [void][Dbx]::SendMessage($rw, 0x0100, [IntPtr]0x08, [IntPtr]0x000E0001)  # WM_KEYDOWN
    [void][Dbx]::SendMessage($rw, 0x0101, [IntPtr]0x08, [IntPtr]0xC00E0001)  # WM_KEYUP
}

# 4. GBK 打包后逐字投递
$gbk = [Text.Encoding]::GetEncoding(936)
$bytes = $gbk.GetBytes("继续")
# ... 拼 wParam，SendMessage($rw, 0x0102, [IntPtr]$w, [IntPtr]1)

# 5. 读回校验（UIA TextPattern）
$tp.DocumentRange.GetText(-1)  # 必须等于 "继续"，否则中止

# 6. 回车发送
[void][Dbx]::SendMessage($rw, 0x0100, [IntPtr]0x0D, [IntPtr]0x001C0001)
[void][Dbx]::SendMessage($rw, 0x0101, [IntPtr]0x0D, [IntPtr]0xC01C0001)
```

> **PowerShell 7 补充**：`[Text.Encoding]::GetEncoding(936)` 在 PS7 里默认会返回 null，要先注册：
> ```powershell
> [Text.Encoding]::RegisterProvider([Text.CodePagesEncodingProvider]::Instance)
> ```

### 成功的样子

```
WIN  hwnd=263546  title=刷超星学习通课程视频及测试 - 豆包
TYPED=[继续]
SENT
```

然后日志里会出现：

```json
{"role":"user","content":"继续"}
```

沙箱进程数从 `0` 变 `1` —— 它开始干活了。

## 3.3 常用指令模板

在手机上直接发这些：

| 你说 | DSH 会做 |
|---|---|
| `看下豆包还在刷没` | 读日志，汇报当前章节和进度 |
| `停了就让它继续` | 判断状态，停了就发「继续」 |
| `让它继续刷` | 直接发「继续」 |
| `刷到第几章了` | 读日志 + 算剩余章节 |
| `让它停下来` | 中断当前任务 |
| `豆包卡住了，看看怎么回事` | 查进程、查日志、查报错 |

## 3.4 无人值守：让它自己循环

### 方式一：让 DSH 盯着（不用写代码）

在手机或电脑上跟 DSH 说：

```
你盯着豆包的日志，每 20 分钟检查一次：
如果沙箱进程数是 0 且最后活动超过 5 分钟，说明它刷完一章停了，
就给它发「继续」。一直循环，直到整个课程刷完。
每完成一章跟我汇报一次。
```

⚠️ 现实提醒：
- DSH 的会话有上下文长度限制，跑十几小时会需要压缩
- 更稳的做法是**每次你主动问一句**，而不是指望它自己跑一整夜
- 建议每次只让它负责 1–2 章，你再问一次

### 方式二：跑看门狗脚本（推荐，最省心）

`scripts/watchdog.ps1` 是个常驻脚本，不占用 DSH 的上下文，可以跑一整天。

```powershell
# 后台常驻
Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','watchdog.ps1' -WindowStyle Hidden

# 或者前台跑，看实时输出
powershell -ExecutionPolicy Bypass -File scripts/watchdog.ps1 -Verbose
```

判定逻辑（三个条件同时满足才发）：

```
每 60 秒检查一次
  ├─ 沙箱进程数 = 0 ?          没在干活
  ├─ 日志静默 > 3 分钟 ?        确实停了
  │    （豆包的视频监控约 2 分钟写一次日志，所以 3 分钟是安全阈值）
  └─ 距上次发送 > 10 分钟 ?     冷却中，防止狂发
        ↓ 三个都满足
     调用 send-jixu.ps1 发「继续」
        ↓ 等 90 秒
     确认沙箱进程数变 1 → 记 OK
     否则 → 记 ERROR 并提示排查
```

可调参数：

| 参数 | 默认 | 说明 |
|---|---|---|
| `-IntervalSec` | 60 | 检查间隔（秒） |
| `-IdleMinutes` | 3.0 | 静默多久算停下 |
| `-ConfirmSec` | 90 | 发完等多久确认 |
| `-CooldownMin` | 10.0 | 两次发送的最小间隔 |
| `-MaxLoops` | 0 | 最多循环几次，0 = 无限 |
| `-LogFile` | watchdog.log | 日志路径 |

所有动作写进 `watchdog.log`，可以事后查：

```
2026-11-18 13:01:29 [INFO] ===== 看门狗启动 =====
2026-11-18 13:01:30 [DEBUG] 状态: 沙箱=1 静默=0.6min 动作=[6.4视频监控8] 进度=72%
2026-11-18 14:05:12 [ACTION] → 判定需要发送「继续」：沙箱=0 且静默 4.2min
2026-11-18 14:05:15 [ACTION] 发送输出: WIN hwnd=263546 ... TYPED=[继续] SENT
2026-11-18 14:06:45 [OK] ✓ 确认启动！沙箱=1 当前动作=[打开7.1并启动视频]
```

### 方式三：两者结合

看门狗负责保活，DSH 负责汇报和异常处理：

```
（电脑上跑着 watchdog.ps1）

手机发：看下现在刷到哪了
DSH：读日志 → "第 7 章 7.2，刚过 40%，看门狗在跑，一切正常"
```

这样既有自动兜底，又能随时问进度。

---

# 第四部分：故障排查

## 4.1 豆包不动了

**症状**：日志不再更新，沙箱进程数 0

| 排查 | 方法 |
|---|---|
| 是不是刷完一章了？ | 看日志最后一条是不是"确认第X章完成" |
| 是不是在等你说「继续」？ | 看最后一条 assistant 消息有没有"你回继续" |
| 豆包崩了吗？ | `Get-Process Doubao` 还在不在 |
| 浏览器被关了吗？ | 学习通的窗口还在不在（豆包刷课依赖那个窗口） |

**最常见的**：它就是刷完一章在等你。发「继续」即可。

## 4.2 视频不动 / 进度不涨

| 症状 | 原因 | 解决 |
|---|---|---|
| 视频暂停 | 反作弊触发 | 重新注入 1.3 的防暂停脚本 |
| 视频在播但任务点不涨 | 用了倍速 | 改回 1 倍速，重新播这一节 |
| 显示"已完成"但没解锁下一节 | 服务端没收到上报 | 刷新页面，重新播最后 30 秒 |

## 4.3 发消息发不进去

| 现象 | 原因 | 解决 |
|---|---|---|
| 输入框里出现乱码「鐍韣」 | wParam 用了 Unicode 码点 | 改成 GBK 打包（见 3.2 坑 2） |
| `TYPED=[]` 空的 | 焦点没抢到 | 多重试几次 `SetFocus()`，或先点一下窗口 |
| 回车没反应 | 发错窗口了 | 确认发给了 `Chrome_RenderWidgetHostHWND` |
| 报 `You cannot call a method on a null-valued expression` | PS7 没有 GBK | 注册 `CodePagesEncodingProvider` |

## 4.4 手机连不上电脑

| 现象 | 原因 | 解决 |
|---|---|---|
| 手机看不到电脑 | 电脑端 DSH 没开 / Host 模式没开 | 检查 DSH 在跑，Remote 面板显示在线 |
| 配对失败 | 不在同一账号 | 两边都用同一个 GitHub 账号登录 |
| 连上了但看不到会话 | 工作区没选对 | 手机上切换工作区 |
| 令牌过期 | accessToken 有效期约 10 分钟 | 会自动用 refreshToken 续期，重启 DSH 即可 |

## 4.5 电脑睡着了

**这是最容易忽略的杀手**。刷课要跑 8–10 小时，电脑一睡全完。

关掉睡眠：

```powershell
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 0
```

> 屏幕可以关（省电），但**系统不能睡**。上面第三条是关显示器，前两条是关睡眠/休眠。

---

# 附录 A：完整发送脚本

见 [`scripts/send-jixu.ps1`](../scripts/send-jixu.ps1)。

# 附录 B：一页速查

```
┌─ 手机 ────────────────────────────────────────┐
│ 1. 打开 DSH Remote App / dsh.r2049.cn/app     │
│ 2. 进到刷课那个会话                            │
│ 3. 发："看下豆包还在刷没，停了就让它继续"        │
└───────────────────────────────────────────────┘
                    ↓
┌─ DSH（电脑）──────────────────────────────────┐
│ 读 trajectory.jsonl → 判断状态                 │
│ 停了 → 跑 send-jixu.ps1 发「继续」             │
│ 查沙箱进程数 → 确认启动                        │
└───────────────────────────────────────────────┘
                    ↓
┌─ 豆包 ────────────────────────────────────────┐
│ 打开下一节 → 注入防暂停脚本 → 1倍速播完        │
│ → 读题 → 答题 → 提交 → 刷新确认 → 下一节       │
│ → 刷完一章 → 停下来等人说「继续」               │
└───────────────────────────────────────────────┘
```

## 三个必须记住的数字

| 项目 | 值 |
|---|---|
| 倍速 | **1**（不能加速，服务端按真实时长算） |
| 每章耗时 | 约 1–2.5 小时（5–10 节 × 13–20 分钟） |
| 检查间隔 | 每 20–30 分钟看一次 |

## 三个必须避开的坑

| 坑 | 后果 |
|---|---|
| 用了 2 倍速 | 任务点不通过，白刷 |
| 电脑睡眠 | 全部中断 |
| 豆包刷完一章没发「继续」 | 干等几小时 |

# 附录 C：状态检查脚本

见 [`scripts/check-doubao.ps1`](../scripts/check-doubao.ps1)。

> **编码提示**：这些脚本含中文，必须存成 **UTF-8 with BOM**。
> Windows PowerShell 5.1 按系统代码页（GBK）读无 BOM 的 UTF-8，会把中文变成乱码并报语法错误。
> 转换方法：
> ```powershell
> $txt = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
> $enc = New-Object System.Text.UTF8Encoding($true)   # $true = 带 BOM
> [IO.File]::WriteAllText($f, $txt, $enc)
> ```
