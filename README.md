# omaWall — slideshow de wallpapers para Omarchy

Equivalente ao **Az Wallpaper (Wallpaper Slideshow)** do GNOME, reconstruído
como plugin de shell do Omarchy (`iaeluk.omawall`). Visual conforme
`DESIGN.md` (omaWall Quiet Dark, lint limpo: 0 erros, 0 avisos).

## Funcionalidades (paridade com o Az)

| Az Wallpaper (GNOME) | omaWall (Omarchy) |
|---|---|
| Pasta do slideshow | `directory` — botão quadrado ou "Trocar pasta…" abre o seletor de pastas do sistema |
| Duração do slide (h/m/s) | `intervalSeconds` — presets 1m/15m/30m/1h/24h + stepper −/+ de 1h até 168h (5s até 7 dias; trocar reinicia a contagem) |
| Ordem: Random, A–Z, Z–A, Newest, Oldest | `sortOrder` — as 5 ordens, botão cíclico (troca reconstrói a fila) |
| Reembaralhar ao concluir | `reshuffleOnComplete` |
| Pausar / retomar | Botão, scroll do meio, `omarchy-shell omawall toggle` |
| Pausar em fullscreen | `pauseOnFullscreen` (sonda `hyprctl activewindow` a cada 10s) |
| Notificar pausar/retomar | `notifications` |
| Anterior/próximo, mostrar na pasta | Botões ⏮ ⏭, clique no nome do arquivo revela na pasta |
| Detecta mudanças na pasta | Revarredura com diff incremental (mantém posição) |
| Fila salva, retoma onde parou | `~/.local/state/omarchy/omawall-state.json` (inclusive após restart) |
| Bing wallpaper do dia (mercado, resolução, qtd) | `bingEnabled`, `bingMarket`, `bingResolution` (UHD…800x600), `bingCount` 1–8; baixa na hora ao ativar e a cada 12h via `scripts/bing-fetch.sh` (com deduplicação e teto de 280s por fetch) |
| Menu no desktop (botão direito) | Widget na barra: botão direito = próximo, meio = pausar, scroll = navegar |

## Extras Omarchy

- **Modo "Só pasta" (padrão):** o serviço vigia o wallpaper atual a cada 15s —
  se uma troca de tema sobrescrever, o slide atual é reaplicado sozinho,
  exceto com pausa manual: pausado, o plugin nunca reaplica por cima do
  que você colocou.
- **Modo "Pasta + tema":** mistura sua pasta com os wallpapers do tema ativo.
- Contador `3/42`, countdown até a próxima troca e nome do arquivo no tooltip.
- Config em `~/.config/omarchy/omawall.json` (editável à mão; o serviço
  recarrega sozinho via watcher).

## Instalação

```bash
# 1. validar
omarchy plugin validate ~/.config/omarchy/plugins/iaeluk.omawall

# 2. widget na barra (lado direito)
omarchy plugin enable iaeluk.omawall --section right

# 3. motor do slideshow: adicione em ~/.config/omarchy/shell.json, no array "plugins":
#    { "id": "iaeluk.omawall" }

# 4. CLI de controle (symlink já criado em ~/.local/bin/omawallctl)
ln -sf ~/.config/omarchy/plugins/iaeluk.omawall/scripts/omawallctl ~/.local/bin/omawallctl

# 5. recarregar o shell
omarchy restart shell

# 6. conferir
omarchy-shell omawall status
```

## Comandos

Ações/consultas (IPC, sem argumentos):

```bash
omarchy-shell omawall status     # JSON com estado atual
omarchy-shell omawall next
omarchy-shell omawall previous
omarchy-shell omawall toggle     # pausa/retoma
omarchy-shell omawall pause
omarchy-shell omawall resume
omarchy-shell omawall refresh    # revarre a pasta
```

Ajustes (via `omawallctl` — o `qs ipc` 0.3.1 não resolve funções COM
argumentos, então os ajustes vão pelo arquivo de config com aplicação
imediata):

```bash
omawallctl interval 300
omawallctl order random|az|za|newest|oldest
omawallctl mode custom|hybrid
omawallctl directory ~/Pictures/wallpapers
omawallctl subfolders|reshuffle|fullscreen|notify|bing on|off
omawallctl get intervalSeconds
```

## Arquivos

- `manifest.json` — id `iaeluk.omawall`, kinds `service` + `bar-widget`
- `Service.qml` — motor: fila, timers, Bing, watchdog de tema, IPC
- `BarWidget.qml` — ícone na barra (espelha o serviço)
- `OmawallCard.qml` — painel de controle (popup, conforme `DESIGN.md`)
- `DESIGN.md` — spec visual (tokens + seções canônicas; lint limpo)
- `Model.js` — ordenação/fila (port da lógica do `slideshow.js` do Az;
  ordenação por inserção manual — o `Array.sort` do QML ignora comparador)
- `scripts/list-images.sh` — varredura (`mtime|path`, jpg/png/gif/bmp/webp/jxl/avif)
- `scripts/bing-fetch.sh` — Bing HPImageArchive → `<nome>-<RES>.jpg`
- `scripts/omawallctl` — CLI de ajustes pelo terminal

## Notas de desenvolvimento QML (custo de 3 bugs reais)

- Nunca dê a uma variável/parâmetro local o mesmo nome de um método do
  objeto (`var next` + `function next` = "Duplicate method name" no load).
- `Array.sort(comparador)` não é confiável no QML aqui — usar inserção manual.
- Dentro de `onLoaded: { var text = ... text() ... }` a declaração sombreia
  o método — chame `idDoFileView.text()` e dê outro nome ao local.
