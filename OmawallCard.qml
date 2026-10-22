import QtQuick
import Quickshell
import qs.Ui
import qs.Commons
import "Model.js" as Model

// omaWall — painel de controle (popup da barra).
// Visual Quiet Dark minimalista: cabeçalho só texto, grupos com respiro,
// sem degradê e sem imagem. Só layout: as ações e a ordem das opções são
// as mesmas de antes, nenhuma lógica muda aqui.
PopupCard {
  id: card

  property var svc: null
  property var widget: null
  signal requestClose()

  function intervalLabel(sec) {
    var s = Math.round(Number(sec) || 0);
    if (s < 3600) return Math.max(1, Math.round(s / 60)) + " min";
    var h = Math.floor(s / 3600);
    var m = Math.round((s % 3600) / 60);
    if (h >= 24) {
      var d = Math.floor(h / 24);
      var rh = h % 24;
      return d + "d" + (rh > 0 ? " " + rh + "h" : "");
    }
    return m > 0 ? h + "h " + m + "m" : h + "h";
  }

  function stepHours(delta) {
    if (!card.svc) return;
    var cur = card.svc.intervalSeconds();
    var next;
    if (delta > 0) next = cur < 3600 ? 3600 : cur + 3600;
    else next = cur <= 3600 ? 3600 : cur - 3600;
    if (next < 5) next = 5;
    if (next > 604800) next = 604800;
    card.svc.updateConfig({ intervalSeconds: next });
  }

  contentWidth: 360
  contentHeight: 540

  Flickable {
    anchors.fill: parent
    anchors.margins: 14
    contentWidth: width
    contentHeight: col.implicitHeight
    clip: true

    Column {
      id: col
      width: parent.width
      spacing: 0

      Item {
        width: parent.width
        height: 26
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "omaWall"
          color: Color.foreground
          font.pixelSize: Style.font.title
          font.bold: true
        }
        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          visible: card.svc && card.svc.queue.length > 0
          width: counterText.implicitWidth + 18
          height: 22
          radius: 999
          color: "transparent"
          border.color: Color.popups.border
          border.width: 1
          Text {
            id: counterText
            anchors.centerIn: parent
            text: card.svc ? Model.prettyCounter(card.svc.slideIndex, card.svc.queue.length) : ""
            color: Color.foreground
            opacity: 0.7
            font.pixelSize: Style.font.caption
            font.family: "monospace"
          }
        }
      }

      Text {
        width: parent.width
        maximumLineCount: 1
        elide: Text.ElideRight
        text: card.svc && card.svc.currentFile !== "" ? Model.fileName(String(card.svc.currentFile)) : "nenhum wallpaper ainda"
        color: Color.foreground
        opacity: 0.7
        font.pixelSize: Style.font.body
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: if (card.svc) card.svc.showInFiles()
        }
      }

      Item {
        width: parent.width
        height: 26
        visible: card.svc !== null
        Rectangle {
          id: statusDot
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: 7
          height: 7
          radius: 4
          color: (card.svc && card.svc.effectivePaused) ? "#fbbf24" : "#34d399"
        }
        Text {
          anchors.left: statusDot.right
          anchors.leftMargin: 7
          anchors.verticalCenter: parent.verticalCenter
          text: {
            if (!card.svc) return "";
            if (card.svc.effectivePaused) return "pausado";
            return Model.formatCountdown(card.svc.remainingSeconds) + " até a próxima";
          }
          color: Color.foreground
          opacity: 0.7
          font.pixelSize: Style.font.caption
          font.family: "monospace"
        }
      }

      SectionLabel { text: "Transporte" }
      Row {
        width: parent.width
        spacing: 8
        CardBtn { label: "◀◀"; tip: "Anterior"; flex3: true; compact: true; onClicked: if (card.svc) card.svc.goPrevious(true) }
        CardBtn { label: card.svc && card.svc.effectivePaused ? "▶" : "❚❚"; tip: "Pausar/retomar"; flex3: true; compact: true; highlighted: card.svc && card.svc.effectivePaused; onClicked: if (card.svc) card.svc.togglePause() }
        CardBtn { label: "▶▶"; tip: "Próximo"; flex3: true; compact: true; onClicked: if (card.svc) card.svc.goNext(true) }
      }

      SectionLabel { text: "Intervalo" }
      Rectangle {
        width: parent.width
        height: 36
        radius: 10
        color: "transparent"
        border.color: Color.popups.border
        border.width: 1
        clip: true
        Row {
          anchors.fill: parent
          anchors.margins: 1
          spacing: 0
          SegCell { label: "1m"; seconds: 60; selected: card.svc && card.svc.intervalSeconds() === 60; onClicked: if (card.svc) card.svc.updateConfig({intervalSeconds: 60}) }
          SegCell { label: "15m"; seconds: 900; selected: card.svc && card.svc.intervalSeconds() === 900; onClicked: if (card.svc) card.svc.updateConfig({intervalSeconds: 900}) }
          SegCell { label: "30m"; seconds: 1800; selected: card.svc && card.svc.intervalSeconds() === 1800; onClicked: if (card.svc) card.svc.updateConfig({intervalSeconds: 1800}) }
          SegCell { label: "1h"; seconds: 3600; selected: card.svc && card.svc.intervalSeconds() === 3600; onClicked: if (card.svc) card.svc.updateConfig({intervalSeconds: 3600}) }
          SegCell { label: "24h"; seconds: 86400; selected: card.svc && card.svc.intervalSeconds() === 86400; onClicked: if (card.svc) card.svc.updateConfig({intervalSeconds: 86400}) }
        }
      }
      Item { width: parent.width; height: 8 }
      Row {
        width: parent.width
        spacing: 8
        CardBtn { label: "−"; small: true; onClicked: card.stepHours(-1) }
        Text {
          width: parent.width - 48 - 48 - 16
          anchors.verticalCenter: parent.verticalCenter
          horizontalAlignment: Text.AlignHCenter
          text: "atual: " + card.intervalLabel(card.svc ? card.svc.intervalSeconds() : 0)
          color: Color.foreground
          opacity: 0.7
          font.pixelSize: Style.font.caption
          font.family: "monospace"
        }
        CardBtn { label: "+"; small: true; onClicked: card.stepHours(1) }
      }

      SectionLabel { text: "Fila" }
      Rectangle {
        width: parent.width
        height: filaCol.implicitHeight
        radius: 12
        color: "transparent"
        border.color: Color.popups.border
        border.width: 1
        Column {
          id: filaCol
          width: parent.width
          CycleRow {
            label: "Ordem"
            value: card.svc ? Model.orderLabel(String(card.svc.cfg("sortOrder", "random"))) : "—"
            showDivider: false
            onClicked: {
              if (!card.svc) return;
              var cur = String(card.svc.cfg("sortOrder", "random"));
              var i = (Model.ORDER_CYCLE.indexOf(cur) + 1) % Model.ORDER_CYCLE.length;
              card.svc.updateConfig({ sortOrder: Model.ORDER_CYCLE[i] });
            }
          }
          SwitchRow {
            label: "Reembaralhar ao concluir"
            on: card.svc && card.svc.cfg("reshuffleOnComplete", true)
            showDivider: true
            onClicked: if (card.svc) card.svc.updateConfig({reshuffleOnComplete: !card.svc.cfg("reshuffleOnComplete", true)})
          }
          SwitchRow {
            label: "Incluir subpastas"
            on: card.svc && card.svc.cfg("includeSubfolders", false)
            showDivider: true
            onClicked: if (card.svc) card.svc.updateConfig({includeSubfolders: !card.svc.cfg("includeSubfolders", false)})
          }
        }
      }

      SectionLabel { text: "Fonte" }
      Rectangle {
        width: parent.width
        height: fonteCol.implicitHeight
        radius: 12
        color: "transparent"
        border.color: Color.popups.border
        border.width: 1
        Column {
          id: fonteCol
          width: parent.width
          CycleRow {
            label: "Origem"
            value: card.svc && String(card.svc.cfg("mode", "custom")) === "hybrid" ? "Pasta + tema" : "Só pasta"
            showDivider: false
            onClicked: {
              if (!card.svc) return;
              var m = String(card.svc.cfg("mode", "custom")) === "hybrid" ? "custom" : "hybrid";
              card.svc.updateConfig({ mode: m });
            }
          }
          SwitchRow {
            label: "Bing do dia"
            on: card.svc && card.svc.cfg("bingEnabled", false)
            showDivider: true
            onClicked: if (card.svc) card.svc.updateConfig({bingEnabled: !card.svc.cfg("bingEnabled", false)})
          }
        }
      }

      SectionLabel { text: "Avisos" }
      Rectangle {
        width: parent.width
        height: avisosCol.implicitHeight
        radius: 12
        color: "transparent"
        border.color: Color.popups.border
        border.width: 1
        Column {
          id: avisosCol
          width: parent.width
          SwitchRow {
            label: "Pausar em fullscreen"
            on: card.svc && card.svc.cfg("pauseOnFullscreen", false)
            showDivider: false
            onClicked: if (card.svc) card.svc.updateConfig({pauseOnFullscreen: !card.svc.cfg("pauseOnFullscreen", false)})
          }
          SwitchRow {
            label: "Notificações"
            on: card.svc && card.svc.cfg("notifications", true)
            showDivider: true
            onClicked: if (card.svc) card.svc.updateConfig({notifications: !card.svc.cfg("notifications", true)})
          }
        }
      }

      SectionLabel { text: "Pasta" }
      Text {
        width: parent.width
        maximumLineCount: 1
        elide: Text.ElideMiddle
        text: card.svc ? String(card.svc.cfg("directory", "")) : ""
        color: Color.foreground
        opacity: 0.65
        font.pixelSize: Style.font.caption
        font.family: "monospace"
      }
      Item { width: parent.width; height: 8 }
      Row {
        width: parent.width
        spacing: 8
        CardBtn { label: "Trocar pasta…"; wide: true; highlighted: true; onClicked: if (card.svc) card.svc.pickDirectory() }
        CardBtn { label: "Abrir"; wide: true; onClicked: if (card.svc) card.svc.openDirectory() }
      }

      Item { width: parent.width; height: 14 }
      CardBtn { label: "Fechar"; fullRow: true; onClicked: card.requestClose() }
    }
  }

  component SectionLabel: Item {
    property string text: ""
    width: parent.width
    height: 32
    Text {
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 7
      text: parent.text
      color: Color.foreground
      opacity: 0.45
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }
  }

  component CardBtn: Rectangle {
    id: btn
    property string label: ""
    property string tip: ""
    property bool small: false
    property bool wide: false
    property bool fullRow: false
    property bool flex3: false
    property bool compact: false
    property bool highlighted: false
    signal clicked()
    width: fullRow ? parent.width : (wide ? (parent.width - 8) / 2 : (flex3 ? (parent.width - 16) / 3 : (small ? 48 : 44)))
    height: fullRow ? 36 : (small ? 32 : (compact ? 36 : 40))
    radius: 10
    color: highlighted ? Color.urgent : "transparent"
    border.color: highlighted ? Color.urgent : Color.popups.border
    border.width: 1
    Text {
      anchors.centerIn: parent
      text: btn.label
      color: btn.highlighted ? "#fff" : Color.foreground
      font.pixelSize: (btn.small || btn.compact) ? Style.font.caption : Style.font.body
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.clicked()
    }
  }

  component SegCell: Rectangle {
    id: cell
    property string label: ""
    property int seconds: 0
    property bool selected: false
    signal clicked()
    width: parent.width / 5
    height: 34
    radius: 9
    color: selected ? Color.urgent : "transparent"
    Text {
      anchors.centerIn: parent
      text: cell.label
      color: cell.selected ? "#fff" : Color.foreground
      opacity: cell.selected ? 1 : 0.8
      font.pixelSize: Style.font.caption
      font.family: "monospace"
      font.bold: cell.selected
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: cell.clicked()
    }
  }

  component CycleRow: Item {
    id: cy
    property string label: ""
    property string value: ""
    property bool showDivider: false
    signal clicked()
    width: parent.width
    height: 40
    Rectangle {
      anchors.top: parent.top
      width: parent.width
      height: 1
      visible: cy.showDivider
      color: Color.popups.border
      opacity: 0.5
    }
    Text {
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - cyclePill.width - 32
      elide: Text.ElideRight
      text: cy.label
      color: Color.foreground
      font.pixelSize: Style.font.body
    }
    Rectangle {
      id: cyclePill
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      width: cycleText.implicitWidth + 20
      height: 24
      radius: 999
      color: "transparent"
      border.color: Color.popups.border
      border.width: 1
      Text {
        id: cycleText
        anchors.centerIn: parent
        text: cy.value + "  ›"
        color: Color.foreground
        opacity: 0.7
        font.pixelSize: Style.font.caption
      }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: cy.clicked()
    }
  }

  component SwitchRow: Item {
    id: sw
    property string label: ""
    property bool on: false
    property bool showDivider: false
    signal clicked()
    width: parent.width
    height: 40
    Rectangle {
      anchors.top: parent.top
      width: parent.width
      height: 1
      visible: sw.showDivider
      color: Color.popups.border
      opacity: 0.5
    }
    Text {
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 34 - 30
      elide: Text.ElideRight
      text: sw.label
      color: Color.foreground
      font.pixelSize: Style.font.body
    }
    Rectangle {
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      width: 34
      height: 20
      radius: 999
      color: sw.on ? Color.urgent : "transparent"
      border.color: sw.on ? Color.urgent : Color.popups.border
      border.width: 1
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: sw.on ? parent.width - 18 : 2
        width: 16
        height: 16
        radius: 8
        color: sw.on ? "#fff" : Color.foreground
        opacity: sw.on ? 1 : 0.5
      }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: sw.clicked()
    }
  }
}
