import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// omaWall — motor do slideshow (serviço). Equivalente ao slideshow.js +
// bingWallpaperDownloader.js do Az Wallpaper, adaptado ao Omarchy:
// o wallpaper é aplicado via `omarchy-theme-bg-set` (symlink do tema +
// IPC do shell), então a pasta do slideshow vence a troca de tema.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string configPath: home + "/.config/omarchy/omawall.json"
  readonly property string statePath: home + "/.local/state/omarchy/omawall-state.json"
  readonly property string currentBgLink: home + "/.local/state/omarchy/current/background"
  readonly property string themeNamePath: home + "/.local/state/omarchy/current/theme.name"
  readonly property string themeStageBgDir: home + "/.local/state/omarchy/current/theme/backgrounds"
  readonly property string userBgBase: home + "/.config/omarchy/backgrounds"
  readonly property string pluginDir: (manifest && manifest.__sourceDir) ? String(manifest.__sourceDir) : (home + "/.config/omarchy/plugins/iaeluk.omawall")
  readonly property string listScript: pluginDir + "/scripts/list-images.sh"
  readonly property string bingScript: pluginDir + "/scripts/bing-fetch.sh"

  property var config: Model.defaultConfig(home)
  property var queue: []
  property int slideIndex: -1
  property string currentFile: ""
  property bool manualPaused: false
  property bool fullscreenActive: false
  property bool effectivePaused: manualPaused || (cfg("pauseOnFullscreen", false) && fullscreenActive)
  property int remainingSeconds: 0
  property string themeName: ""
  property string scanKey: ""
  property string builtOrder: ""
  property bool bingWasEnabled: false
  property int lastAppliedInterval: 0
  property var pendingState: null
  property bool booted: false
  property string lastConfigText: ""
  property bool scanPending: false
  property int tickCount: 0
  property bool emptyNotified: false

  function cfg(key, fb) {
    var v = config ? config[key] : undefined;
    return (v === undefined || v === null) ? fb : v;
  }

  function notify(head, body) {
    if (!cfg("notifications", true)) return;
    var cmd = ["omarchy-notification-send", "-g", "🖼", String(head)];
    if (body) cmd.push(String(body));
    cmd.push("-t", "2500");
    notifyProc.command = cmd;
    notifyProc.running = true;
  }

  // ---- configuração ----

  function updateConfig(patch) {
    var merged = {};
    for (var k in config) merged[k] = config[k];
    for (var p in patch) merged[p] = patch[p];
    config = merged;
    var text = JSON.stringify(merged, null, 2) + "\n";
    lastConfigText = text;
    configFile.setText(text);
    applyConfig(merged);
  }

  function applyConfig(incoming) {
    manualPaused = incoming.paused === true;
    var newIv = Math.max(5, Math.min(604800, Math.round(Number(incoming.intervalSeconds) || 600)));
    if (newIv !== lastAppliedInterval) {
      lastAppliedInterval = newIv;
      remainingSeconds = newIv;
    }
    var key = String(incoming.directory || "") + "|" + String(incoming.sortOrder) + "|" +
      String(incoming.mode) + "|" + String(incoming.includeSubfolders) + "|" +
      String(incoming.bingEnabled && incoming.bingInclude ? incoming.bingDir : "");
    if (key !== scanKey) {
      scanKey = key;
      startScan();
    } else {
      updateSlideTimer();
    }
    bingTimer.running = incoming.bingEnabled === true;
    if (incoming.bingEnabled === true && !bingWasEnabled) {
      console.warn("omawall: bing ativado, agendando fetch em 10s");
      bingStarter.restart();
    }
    bingWasEnabled = incoming.bingEnabled === true;
  }

  function currentScanDirs() {
    var dirs = [];
    var d = String(cfg("directory", "") || "");
    if (d !== "") dirs.push(d);
    if (cfg("bingEnabled", false) && cfg("bingInclude", true)) {
      var bd = String(cfg("bingDir", "") || "");
      if (bd !== "" && dirs.indexOf(bd) < 0) dirs.push(bd);
    }
    if (cfg("mode", "custom") === "hybrid") {
      if (themeStageBgDir !== "") dirs.push(themeStageBgDir);
      if (themeName !== "") dirs.push(userBgBase + "/" + themeName);
    }
    return dirs;
  }

  // ---- varredura da pasta (detecta adições/remoções como o Az) ----

  function startScan() {
    var dirs = currentScanDirs();
    if (dirs.length === 0) {
      onScanOutput("");
      return;
    }
    var cmd = ["mkdir", "-p"];
    for (var i = 0; i < dirs.length; i++) cmd.push(dirs[i]);
    mkdirProc.command = cmd;
    mkdirProc.running = true;
  }

  function onScanOutput(text) {
    var files = [];
    var seen = {};
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (line === "") continue;
      var sep = line.indexOf("|");
      if (sep < 0) continue;
      var path = line.slice(sep + 1);
      if (path === "" || seen[path]) continue;
      seen[path] = true;
      files.push({ path: path, name: Model.fileName(path), mtime: parseFloat(line.slice(0, sep)) || 0 });
    }
    mergeQueue(files);
  }

  function mergeQueue(files) {
    var order = String(cfg("sortOrder", "random") || "random");
    var currentPath = (slideIndex >= 0 && slideIndex < queue.length) ? queue[slideIndex].path : currentFile;

    // Troca de ordem (como no Az): reconstrói a fila já ordenada.
    if (order !== builtOrder) {
      builtOrder = order;
      var rebuilt;
      if (order === "random" && pendingState && pendingState.queue instanceof Array && pendingState.queue.length > 0) {
        rebuilt = Model.restoreOrder(files, pendingState.queue);
      } else {
        rebuilt = Model.sortItems(files, order);
      }
      queue = rebuilt;
      if (queue.length === 0) {
        slideIndex = -1;
        currentFile = "";
        updateSlideTimer();
        saveState();
        return;
      }
      // Retoma de onde parou (restart) antes de manter a posição atual.
      var resumePath = currentPath;
      if (pendingState && pendingState.file) {
        resumePath = pendingState.file;
        pendingState = null;
      }
      var at = Model.indexOfPath(queue, resumePath);
      slideIndex = at >= 0 ? at : 0;
      if (!booted) {
        booted = true;
        applyWallpaper(queue[slideIndex].path, false);
      } else {
        currentFile = queue[slideIndex].path;
        updateSlideTimer();
        saveState();
      }
      emptyNotified = false;
      return;
    }

    var pathSet = {};
    var i;
    for (i = 0; i < files.length; i++) pathSet[files[i].path] = files[i];

    var nextQueue = [];
    for (i = 0; i < queue.length; i++) {
      if (pathSet[queue[i].path]) nextQueue.push(queue[i]);
    }
    for (i = 0; i < files.length; i++) {
      if (Model.indexOfPath(nextQueue, files[i].path) < 0) {
        var pos = Model.insertPosition(nextQueue, files[i], order);
        if (pos < 0) nextQueue.push(files[i]);
        else nextQueue.splice(pos, 0, files[i]);
      }
    }
    if (order === "random" && queue.length === 0 && nextQueue.length > 0) {
      Model.shuffle(nextQueue);
    }
    queue = nextQueue;

    if (queue.length === 0) {
      slideIndex = -1;
      currentFile = "";
      updateSlideTimer();
      saveState();
      if (!emptyNotified) {
        emptyNotified = true;
        notify("omaWall: pasta sem imagens", "Adicione imagens em " + String(cfg("directory", "")));
      }
      return;
    }
    emptyNotified = false;

    var idx = Model.indexOfPath(queue, currentPath);
    if (pendingState && pendingState.file) {
      var saved = Model.indexOfPath(queue, pendingState.file);
      if (saved >= 0) idx = saved;
      pendingState = null;
    }
    if (idx < 0) {
      if (order === "random") idx = Math.floor(Math.random() * queue.length);
      else idx = 0;
    }
    slideIndex = idx;

    if (!booted) {
      booted = true;
      applyWallpaper(queue[slideIndex].path, false);
    } else {
      currentFile = queue[slideIndex].path;
      updateSlideTimer();
      saveState();
    }
  }

  // ---- troca de wallpaper ----

  function intervalSeconds() {
    return Math.max(5, Number(cfg("intervalSeconds", 600)) || 600);
  }

  function updateSlideTimer() {
    slideTimer.interval = intervalSeconds() * 1000;
    if (!effectivePaused && queue.length > 0 && slideIndex >= 0) {
      if (remainingSeconds <= 0) remainingSeconds = intervalSeconds();
      if (!slideTimer.running) slideTimer.restart();
    } else {
      slideTimer.stop();
    }
  }

  function applyWallpaper(path, manual) {
    if (!path) return;
    setProc.command = ["omarchy-theme-bg-set", path];
    setProc.running = true;
    pendingApplyPath = path;
    pendingApplyManual = !!manual;
  }

  property string pendingApplyPath: ""
  property bool pendingApplyManual: false

  function onWallpaperApplied(ok) {
    if (!pendingApplyPath) return;
    var path = pendingApplyPath;
    pendingApplyPath = "";
    if (!ok) return;
    currentFile = path;
    slideIndex = Model.indexOfPath(queue, path);
    remainingSeconds = intervalSeconds();
    updateSlideTimer();
    saveState();
    if (pendingApplyManual) {
      notify("omaWall — " + Model.fileName(path), Model.prettyCounter(slideIndex, queue.length));
    }
    pendingApplyManual = false;
  }

  function step(delta, manual) {
    if (queue.length === 0) {
      startScan();
      if (manual) notify("omaWall", "Pasta sem imagens — verifique a pasta do slideshow");
      return;
    }
    var order = String(cfg("sortOrder", "random") || "random");
    var target = slideIndex + delta;
    if (target >= queue.length) {
      target = 0;
      if (order === "random" && cfg("reshuffleOnComplete", true)) {
        var cur = queue[slideIndex].path;
        Model.shuffle(queue);
        queue = queue.slice();
        target = 0;
        if (queue[target].path === cur && queue.length > 1) target = 1;
      }
    } else if (target < 0) {
      target = queue.length - 1;
    }
    slideIndex = target;
    applyWallpaper(queue[slideIndex].path, manual);
  }

  function goNext(manual) { step(1, manual === true); }
  function goPrevious(manual) { step(-1, manual === true); }

  function togglePause() { setPaused(!manualPaused); }

  function setPaused(p) {
    manualPaused = !!p;
    if (!manualPaused && queue.length > 0) remainingSeconds = intervalSeconds();
    updateSlideTimer();
    updateConfig({ paused: manualPaused });
    notify(manualPaused ? "omaWall pausado" : "omaWall retomado",
      manualPaused ? "" : Model.fileName(currentFile));
  }

  function refresh() { startScan(); }

  function pickDirectory() {
    pickProc.command = ["omarchy", "file", "select", "--directory", "--title", "Pasta do slideshow omaWall"];
    pickProc.running = true;
  }

  function openDirectory() {
    var d = String(cfg("directory", "") || "");
    if (d === "") return;
    openProc.command = ["xdg-open", d];
    openProc.running = true;
  }

  function showInFiles() {
    if (!currentFile) return;
    var dir = currentFile.slice(0, currentFile.lastIndexOf("/"));
    openProc.command = ["xdg-open", dir || home];
    openProc.running = true;
  }

  function statusJson() {
    return JSON.stringify({
      current: currentFile,
      name: Model.fileName(currentFile),
      index: slideIndex,
      total: queue.length,
      paused: effectivePaused,
      interval: intervalSeconds(),
      remaining: remainingSeconds,
      directory: cfg("directory", ""),
      order: cfg("sortOrder", "random"),
      mode: cfg("mode", "custom")
    });
  }

  function saveState() {
    var paths = [];
    for (var i = 0; i < queue.length; i++) paths.push(queue[i].path);
    stateFile.setText(JSON.stringify({ file: currentFile, index: slideIndex, queue: paths }) + "\n");
  }

  // ---- processos, arquivos e timers ----

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var content = String(configFile.text() || "");
      if (content === "") {
        var fresh = JSON.stringify(Model.defaultConfig(root.home), null, 2) + "\n";
        root.lastConfigText = fresh;
        configFile.setText(fresh);
        root.config = Model.defaultConfig(root.home);
        root.applyConfig(root.config);
        return;
      }
      if (content === root.lastConfigText) return;
      root.lastConfigText = content;
      root.config = Model.parseConfig(content, root.home);
      root.applyConfig(root.config);
    }
    onLoadFailed: {
      root.config = Model.defaultConfig(root.home);
      root.applyConfig(root.config);
    }
    onFileChanged: reload()
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    printErrors: false
    onLoaded: {
      try {
        var s = JSON.parse(String(text() || ""));
        if (s && s.file) root.pendingState = s;
      } catch (e) {}
    }
  }

  Process {
    id: mkdirProc
    onExited: {
      var dirs = root.currentScanDirs();
      if (dirs.length === 0) {
        root.onScanOutput("");
        return;
      }
      var cmd = [root.listScript];
      if (root.cfg("includeSubfolders", false)) cmd.push("-r");
      for (var i = 0; i < dirs.length; i++) cmd.push(dirs[i]);
      scanProc.command = cmd;
      scanProc.running = true;
    }
  }

  Process {
    id: scanProc
    stdout: StdioCollector {
      onStreamFinished: root.onScanOutput(String(text || ""))
    }
  }

  Process {
    id: setProc
    onExited: function (exitCode) { root.onWallpaperApplied(exitCode === 0); }
  }

  Process { id: notifyProc }
  Process { id: openProc }

  Process {
    id: pickProc
    stdout: StdioCollector {
      onStreamFinished: {
        var dir = String(text || "").trim();
        if (dir !== "") {
          root.updateConfig({ directory: dir });
          root.notify("omaWall", "Pasta: " + dir);
        }
      }
    }
  }

  Process {
    id: readlinkProc
    stdout: StdioCollector {
      onStreamFinished: {
        var bg = String(text || "").trim();
        // Modo pasta: se uma troca de tema sobrescreveu o wallpaper,
        // retoma o slide atual sem notificar. Pausa manual é ordem do
        // usuário: nunca reaplicar por cima do que ele colocou.
        if (!root.manualPaused && root.cfg("mode", "custom") === "custom" && root.currentFile !== "" && bg !== "" && bg !== root.currentFile) {
          root.applyWallpaper(root.currentFile, false);
        }
      }
    }
  }

  Process {
    id: themeProc
    stdout: StdioCollector {
      onStreamFinished: {
        var name = String(text || "").trim();
        if (name !== "" && name !== root.themeName) {
          root.themeName = name;
          if (root.cfg("mode", "custom") === "hybrid") root.startScan();
        }
      }
    }
  }

  Process {
    id: fullscreenProc
    command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null | grep -Eq '\"fullscreen\": *(true|[12])'"]
    onExited: function (exitCode) {
      var active = exitCode === 0;
      if (active !== root.fullscreenActive) {
        var was = root.effectivePaused;
        root.fullscreenActive = active;
        if (was !== root.effectivePaused) {
          if (root.cfg("notifications", true)) {
            root.notify(root.effectivePaused ? "omaWall pausado (fullscreen)" : "omaWall retomado", "");
          }
        }
        root.updateSlideTimer();
      }
    }
  }

  Process {
    id: bingProc
    stdout: StdioCollector {
      onStreamFinished: root.startScan()
    }
    onExited: root.startScan()
  }

  Timer {
    id: slideTimer
    interval: 600000
    repeat: true
    onTriggered: {
      if (root.effectivePaused) return;
      root.remainingSeconds = root.intervalSeconds();
      root.step(1, false);
    }
  }

  Timer {
    id: tickTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      root.tickCount += 1;
      if (!root.effectivePaused && root.remainingSeconds > 0) root.remainingSeconds -= 1;
      if (root.tickCount % 10 === 0 && root.cfg("pauseOnFullscreen", false)) {
        if (!fullscreenProc.running) fullscreenProc.running = true;
      }
      if (root.tickCount % 15 === 0 && root.currentFile !== "") {
        if (!readlinkProc.running) {
          readlinkProc.command = ["readlink", "-f", root.currentBgLink];
          readlinkProc.running = true;
        }
      }
      if (root.tickCount % 60 === 0) {
        if (!themeProc.running) {
          themeProc.command = ["cat", root.themeNamePath];
          themeProc.running = true;
        }
      }
      if (root.tickCount >= 60000) root.tickCount = 0;
    }
  }

  Timer {
    id: bingTimer
    interval: 43200000
    repeat: true
    running: false
    onTriggered: root.runBing()
  }

  // Az baixa o wallpaper do dia logo ao ativar (com pequeno atraso),
  // não só no ciclo de 12h.
  Timer {
    id: bingStarter
    interval: 10000
    repeat: false
    onTriggered: root.runBing()
  }

  function runBing() {
    console.warn("omawall: iniciando fetch do Bing em " + String(root.cfg("bingDir", "")));
    if (bingProc.running) {
      console.warn("omawall: fetch anterior ainda rodando, pulando");
      return;
    }
    // `timeout` garante que um download travado nunca prenda o serviço.
    bingProc.command = ["timeout", "280", root.bingScript, String(root.cfg("bingDir", root.home + "/Pictures/Bing Wallpapers")),
      String(root.cfg("bingCount", 4)), String(root.cfg("bingResolution", "UHD")), String(root.cfg("bingMarket", "Automatic"))];
    bingProc.running = true;
  }

  IpcHandler {
    target: "omawall"
    function next(): string { root.goNext(true); return "ok"; }
    function previous(): string { root.goPrevious(true); return "ok"; }
    function toggle(): string { root.togglePause(); return root.effectivePaused ? "paused" : "running"; }
    function pause(): string { root.setPaused(true); return "paused"; }
    function resume(): string { root.setPaused(false); return "running"; }
    function refresh(): string { root.refresh(); return "ok"; }
    function status(): string { return root.statusJson(); }
    // Ajustes (intervalo, ordem, pasta, modo…): use o CLI `omawallctl`,
    // que edita ~/.config/omarchy/omawall.json e o serviço aplica na hora.
    // (Funções IPC COM argumentos não são resolvidas pelo qs 0.3.1.)
  }

  Component.onCompleted: {
    themeProc.command = ["cat", themeNamePath];
    themeProc.running = true;
  }
  Component.onDestruction: saveState()
}
