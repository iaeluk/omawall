#!/bin/bash
# omaWall — baixa o wallpaper do dia do Bing (lógica portada do Az Wallpaper).
# Uso: bing-fetch.sh <pasta-destino> <quantidade 1-8> <resolução> <mercado>
# Resolução: UHD, 1920x1200, 1920x1080, 1366x768, 1280x768, 1280x720, 1024x768, 800x600
# Mercado: Automatic (sem filtro) ou código como pt-BR, en-US...
set -uo pipefail

dest=${1:?destino obrigatório}
count=${2:-4}
resolution=${3:-UHD}
market=${4:-Automatic}

mkdir -p "$dest"

case $resolution in
  UHD|1920x1200|1920x1080|1366x768|1280x768|1280x720|1024x768|800x600) ;;
  *) resolution=UHD ;;
esac

if ! [[ $count =~ ^[1-8]$ ]]; then
  count=4
fi

api_url="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=${count}&mbl=1"
if [[ -n $market && $market != "Automatic" ]]; then
  api_url="${api_url}&mkt=${market}"
fi

export OMAWALL_DEST="$dest" OMAWALL_RES="$resolution"
json=$(curl -fsSL --max-time 60 -A "Mozilla/5.0 (Linux) omaWall/0.1.0" "$api_url") || {
  echo "omawall: falha ao consultar API do Bing" >&2
  exit 1
}

python3 - "$json" <<'EOF'
import json, os, sys, urllib.request

data = json.loads(sys.argv[1])
dest = os.environ["OMAWALL_DEST"]
res = os.environ["OMAWALL_RES"]
downloaded, skipped = 0, 0

for img in data.get("images", []):
    urlbase = img.get("urlbase", "")
    if not urlbase:
        continue
    pretty = urlbase.split("/")[-1].replace("th?id=OHR.", "").split("_")[0] or "bing"
    name = "%s-%s.jpg" % (pretty, res)
    path = os.path.join(dest, name)
    if os.path.exists(path):
        skipped += 1
        continue
    url = "https://bing.com%s_%s.jpg" % (urlbase, res)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Linux) omaWall/0.1.0"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r, open(path, "wb") as f:
            f.write(r.read())
        downloaded += 1
        print("baixado: %s" % name)
    except Exception as e:
        print("falha %s: %s" % (name, e), file=sys.stderr)

print("omawall bing: %d novos, %d já existiam" % (downloaded, skipped))
EOF
