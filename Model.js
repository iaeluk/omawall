// omaWall — lógica compartilhada (pura, sem dependência de QML).
// Espelha o comportamento de fila do Az Wallpaper (Wallpaper Slideshow GNOME).

function defaultConfig(home) {
  return {
    directory: home + "/Pictures/omawall",
    intervalSeconds: 600,
    sortOrder: "random",
    reshuffleOnComplete: true,
    paused: false,
    pauseOnFullscreen: false,
    notifications: true,
    includeSubfolders: false,
    mode: "custom",
    bingEnabled: false,
    bingInclude: true,
    bingDir: home + "/Pictures/Bing Wallpapers",
    bingMarket: "Automatic",
    bingResolution: "UHD",
    bingCount: 4
  };
}

function parseConfig(text, home) {
  var cfg = defaultConfig(home);
  if (!text) return cfg;
  try {
    var parsed = JSON.parse(text);
    for (var k in cfg) {
      if (parsed[k] !== undefined && parsed[k] !== null) cfg[k] = parsed[k];
    }
  } catch (e) {}
  if (typeof cfg.intervalSeconds !== "number" || isNaN(cfg.intervalSeconds)) cfg.intervalSeconds = 600;
  cfg.intervalSeconds = Math.max(5, Math.min(604800, Math.round(cfg.intervalSeconds)));
  var orders = ["random", "az", "za", "newest", "oldest"];
  if (orders.indexOf(cfg.sortOrder) < 0) cfg.sortOrder = "random";
  if (cfg.mode !== "hybrid") cfg.mode = "custom";
  cfg.bingCount = Math.max(1, Math.min(8, Number(cfg.bingCount) || 4));
  return cfg;
}

function fileName(path) {
  var i = String(path).lastIndexOf("/");
  return i >= 0 ? String(path).slice(i + 1) : String(path);
}

function shuffle(arr) {
  for (var i = arr.length - 1; i > 0; i--) {
    var j = Math.floor(Math.random() * (i + 1));
    var tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp;
  }
  return arr;
}

function compareItems(a, b, order) {
  if (order === "az") {
    if (a.name < b.name) return -1;
    if (a.name > b.name) return 1;
    return 0;
  }
  if (order === "za") {
    if (a.name > b.name) return -1;
    if (a.name < b.name) return 1;
    return 0;
  }
  if (order === "newest") return (Number(b.mtime) || 0) - (Number(a.mtime) || 0);
  if (order === "oldest") return (Number(a.mtime) || 0) - (Number(b.mtime) || 0);
  return 0;
}

function sortItems(items, order) {
  if (order === "random") return shuffle(items.slice());
  // Inserção ordenada manual (sem Array.sort: determinístico em qualquer engine).
  var out = [];
  for (var i = 0; i < items.length; i++) {
    var pos = insertPosition(out, items[i], order);
    if (pos < 0) pos = out.length;
    out.splice(pos, 0, items[i]);
  }
  return out;
}

// Posição de inserção ordenada (estilo Az: arquivos novos entram no lugar
// certo sem reconstruir a fila). Retorna -1 para random ( embaralha depois ).
function insertPosition(queue, item, order) {
  if (order === "random") return -1;
  var low = 0, high = queue.length;
  while (low < high) {
    var mid = Math.floor((low + high) / 2);
    if (compareItems(queue[mid], item, order) < 0) low = mid + 1;
    else high = mid;
  }
  return low;
}

function indexOfPath(queue, path) {
  for (var i = 0; i < queue.length; i++) {
    if (queue[i].path === path) return i;
  }
  return -1;
}

// Restaura a ordem exata salva (modo random): mantém os arquivos conhecidos
// na posição salva e acrescenta os novos embaralhados no fim.
function restoreOrder(files, savedPaths) {
  var byPath = {};
  var i;
  for (i = 0; i < files.length; i++) byPath[files[i].path] = files[i];
  var out = [];
  var seen = {};
  if (savedPaths instanceof Array) {
    for (i = 0; i < savedPaths.length; i++) {
      var f = byPath[savedPaths[i]];
      if (f && !seen[f.path]) {
        seen[f.path] = true;
        out.push(f);
      }
    }
  }
  var fresh = [];
  for (i = 0; i < files.length; i++) {
    if (!seen[files[i].path]) fresh.push(files[i]);
  }
  shuffle(fresh);
  return out.concat(fresh);
}

function formatCountdown(totalSeconds) {
  var s = Math.max(0, Math.round(totalSeconds));
  var h = Math.floor(s / 3600);
  var m = Math.floor((s % 3600) / 60);
  var r = s % 60;
  function pad(n) { return (n < 10 ? "0" : "") + n; }
  if (h > 0) return h + ":" + pad(m) + ":" + pad(r);
  return m + ":" + pad(r);
}

function prettyCounter(index, total) {
  if (total <= 0 || index < 0) return "";
  return (index + 1) + "/" + total;
}

var ORDER_LABELS = {
  "random": "Aleatória",
  "az": "A–Z",
  "za": "Z–A",
  "newest": "Recentes",
  "oldest": "Antigas"
};

var ORDER_CYCLE = ["random", "az", "za", "newest", "oldest"];

function orderLabel(order) {
  return ORDER_LABELS[order] || ORDER_LABELS["random"];
}
