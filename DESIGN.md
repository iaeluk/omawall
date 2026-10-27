---
version: alpha
name: omaWall Quiet Dark
description: Calmo, nativo do tema e preciso — o slideshow some na barra e o painel de controle parece parte do Omarchy. Revisão minimalista: sem degradê, sem imagem, grupos com respiro.
colors:
  primary: "#F2F2F5"
  secondary: "#A8A8B3"
  accent: "#D63A41"
  surface: "#1E1E26"
  border: "#3A3A46"
  on-accent: "#FFFFFF"
typography:
  h1:
    fontFamily: system-ui
    fontSize: 17px
    fontWeight: 700
    lineHeight: 1.25
  body-md:
    fontFamily: system-ui
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.45
  label-sm:
    fontFamily: system-ui
    fontSize: 11px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "0.04em"
  mono-num:
    fontFamily: ui-monospace, monospace
    fontSize: 12px
    fontWeight: 600
    lineHeight: 1.3
rounded:
  sm: 8px
  md: 12px
  full: 999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
components:
  bar-icon:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    rounded: "{rounded.sm}"
  card-title:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    typography:
      fontFamily: system-ui
      fontSize: 17px
      fontWeight: 700
  section-label:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    typography:
      fontFamily: system-ui
      fontSize: 11px
      fontWeight: 600
  btn-transport:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    rounded: "{rounded.sm}"
    padding: 12px
  btn-transport-active:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.sm}"
    padding: 12px
  btn-preset:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    rounded: "{rounded.sm}"
    padding: 8px
  btn-preset-active:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.sm}"
    padding: 8px
  value-pill:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    rounded: "{rounded.full}"
    padding: 8px
  countdown-chip:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    rounded: "{rounded.full}"
    padding: 8px
  divider:
    backgroundColor: "{colors.border}"
    textColor: "{colors.secondary}"
    rounded: "{rounded.sm}"
  folder-path:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    rounded: "{rounded.sm}"
    padding: 8px
---

## Overview

omaWall é um slideshow de wallpapers que mora na barra do Omarchy. A
identidade é "Quiet Dark": superfícies escuras e neutras, um único acento
vermelho reservado ao estado ativo, tipografia do sistema e nada que brigue
com o tema — em runtime, cada token é ligado ao singleton de tema do shell
(`Color.*`, `Style.font`), e os valores hex aqui são a referência concreta
para lint de contraste.

## Colors

- **Primary (#F2F2F5):** texto principal — título, nome do arquivo, botões.
  Em runtime: `Color.foreground`.
- **Secondary (#A8A8B3):** texto de apoio — rótulos de seção, contadores,
  countdown, caminho da pasta. Em runtime: `Color.foreground` com opacidade.
- **Accent (#D63A41):** "omaWall Red" — o ÚNICO driver de ênfase: botão de
  transporte ativo (pausado/tocando) e preset de intervalo selecionado.
  Em runtime: `Color.urgent`.
- **Surface (#1E1E26):** fundo do card e dos botões em repouso.
  Em runtime: transparente sobre o popup do tema.
- **Border (#3A3A46):** bordas de botões e divisórias.
  Em runtime: `Color.popups.border`.
- **On-accent (#FFFFFF):** texto sobre o acento. Contraste 4.5+:1 contra o
  accent em uso normal de botão (verificação no lint).

## Typography

Tipografia do sistema em três papéis mais um numérico: `h1` só no título do
card com contador; `body-md` no nome do arquivo e nas linhas de alternância;
`label-sm` em caixa alta visual nos rótulos de seção (TRANSPORTE, INTERVALO,
FILA, FONTE, PASTA); `mono-num` no countdown até a próxima troca, para os
dígitos não dançarem.

## Layout

Card de 360px com respiro de 14px nas margens. Cabeçalho só texto
(título + contador, arquivo em linha única, status com bolinha).
Ordem vertical fixa: cabeçalho → transporte → seções rotuladas
em grupos (intervalo, fila, fonte, avisos) → pasta → fechar.
Grupos com divisórias internas de 1px; sem divisórias entre blocos.

## Elevation & Depth

Sem sombras próprias: o card herda a elevação do popup do shell. Hierarquia
se expressa por peso tipográfico e pelo acento único, nunca por sombra ou
brilho adicional.

## Shapes

Botões em 10px; grupos e trilho do segmentado em 10–12px; contador,
countdown e valores de alternância em pílula cheia (999px); switch em
trilho 34x20 com pastilha branca. Transporte em 3 botões flexíveis
iguais, 36px, glifos compactos (sem botão de pasta: trocar pasta já
existe na seção Pasta).

## Components

- `bar-icon`: quadrado vazado de 12px na barra (raio 3px) — borda de 2px
  na mesma cor dos ícones nativos (`foreground`, com cor de ativo quando
  rodando), interior transparente. Sem emoji, sem glifo de fonte: forma
  geométrica desenhada. Quando pausado, perde opacidade (45%); rodando, cheio.
- `bar-icon` usa `button.foreground` / `button.activeColor`: nunca hex
  fixo, sempre a mesma nuance dos ícones nativos.
- `card-title` + chip de contador (`3/42`) em pílula cheia.
- `section-label`: `label-sm` sobre `secondary`, sempre precedendo seu grupo.
- `btn-transport` / `btn-transport-active`: 36px de altura, glifos
  compactos ◀◀ ❚❚/▶ — o estado ativo (pausado) veste o acento;
  os demais ficam em repouso com borda.
- `seg-interval`: trilho único com 5 segmentos (1m/15m/30m/1h/24h em
  mono); só o segmento corrente veste o acento. Stepper −/+ com respiro
  de 8px acima e rótulo "atual:" em mono.
- `switch-row`: fileiras booleanas (reembaralhar, subpastas, Bing,
  fullscreen, notificações) com switch — trilho em acento quando ligado,
  pastilha branca; desligado transparente com borda.
- `cycle-row`: fileiras de escolha (ordem, origem) com o valor atual em
  pílula à direita + ›.
- `countdown-chip`: bolinha de status (verde rodando, âmbar pausado) +
  "9:41 até a próxima" em mono — sem emoji de ▶/⏸.
- `folder-path`: caminho em mono truncado no meio, sem emoji, com
  "Trocar pasta…" (ação primária, veste o acento) + "Abrir".

## Do's and Don'ts

- FAÇA: um único elemento em acento por vez na fileira de transporte.
- FAÇA: manter rótulos de seção curtos e sempre acima do grupo.
- NÃO FAÇA: introduzir segunda cor de destaque ou sombra própria.
- NÃO FAÇA: hex fixo fora do acento e dos semáforos de status — todo o
  resto reage ao tema (é o que faz o claro funcionar).
- NÃO FAÇA: renderizar string vinda do disco ou da config como rich text:
  nome de arquivo e caminho de pasta usam `textFormat: Text.PlainText`.
- NÃO FAÇA: texto corrido maior que 13px dentro do card.
- NÃO FAÇA: presets ou alternâncias sem indicar o valor corrente.
