/**
 * 学习通播放器防暂停脚本
 *
 * 用途：注入到学习通播放页，让视频在后台/失焦/鼠标离开时也不会暂停。
 *
 * 用法：
 *   1. 在豆包的任务模式里，让 Agent 执行这段 JS
 *   2. 或者在浏览器控制台粘贴执行
 *   3. 或者在 Tampermonkey 里作为用户脚本运行
 *
 * 关键点：
 *   - 学习通嵌了多层 iframe，必须递归找 video 元素
 *   - 必须废掉 HTMLMediaElement.prototype.pause
 *   - 倍速必须是 1，不能加速（服务端按真实观看秒数算，加速会白刷）
 */

(function () {
  'use strict';

  // ============ 配置 ============
  // 播放倍速。必须是 1！
  // 实测：2 倍速播 20 分钟，服务端只记录 51% 的观看时长，任务点不通过。
  var RATE = 1;

  // 最多递归几层 iframe（学习通一般 3-4 层）
  var MAX_DEPTH = 5;

  // 每隔多少毫秒检查一次播放状态
  var KICK_INTERVAL = 1000;
  // =============================

  /**
   * 递归查找 video 元素
   * @param {Window} w  窗口对象
   * @param {number} d  当前深度
   * @returns {HTMLVideoElement|null}
   */
  function findVideo(w, d) {
    if (d > MAX_DEPTH) return null;
    try {
      var v = w.document.querySelector('video');
      if (v) return v;
      for (var i = 0; i < w.frames.length; i++) {
        var r = findVideo(w.frames[i], d + 1);
        if (r) return r;
      }
    } catch (e) {
      // 跨域 iframe 会抛异常，忽略继续找
    }
    return null;
  }

  var video = findVideo(window, 0);
  if (!video) {
    console.warn('[chaoxing-autoplay] 没找到 video 元素');
    return 'novideo';
  }

  // 暴露到全局，方便外部查询状态
  window.__V = video;

  // ============ 1. 废掉 pause() ============
  // 学习通会调用 video.pause() 来暂停，这里直接让它失效
  var proto = video.ownerDocument.defaultView.HTMLMediaElement.prototype;
  if (!proto.__chaoxingPatched) {
    proto.__chaoxingPatched = true;
    proto.pause = function () {
      // 什么都不做，直接返回
      return;
    };
  }

  // ============ 2. 每秒"踢"一脚 ============
  // 万一还有别的路径能暂停（比如直接改 paused 属性），这里主动拉回来
  function kick() {
    if (!video.duration || video.ended) return;

    // 暂停了就重新播
    if (video.paused) {
      video.muted = true;   // 静音，避免后台播放被策略拦截
      try {
        video.play();
      } catch (e) {
        // play() 返回 Promise，被拒时会有 Uncaught (in promise)，这里吞掉
      }
    }

    // 倍速被改了拉回来
    if (video.playbackRate !== RATE) {
      try {
        video.playbackRate = RATE;
      } catch (e) {}
    }
  }

  if (!window.__chaoxingKickBound) {
    window.__chaoxingKickBound = true;
    video.addEventListener('timeupdate', kick);
    video.addEventListener('play', kick);
    video.addEventListener('ratechange', kick);
    setInterval(kick, KICK_INTERVAL);
  }

  kick();

  return JSON.stringify({
    t: Math.round(video.currentTime),
    dur: Math.round(video.duration || 0),
    paused: video.paused,
    rate: video.playbackRate
  });
})();
