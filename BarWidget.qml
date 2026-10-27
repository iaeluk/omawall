import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// omaWall — widget da barra. Fino: todo o motor vive no Service.qml,
// aqui só espelhamos o estado e abrimos o painel de controle.
BarWidget {
  id: root
  moduleName: "iaeluk.omawall"

  readonly property var wallService: (bar && bar.shell) ? bar.shell.serviceFor("iaeluk.omawall") : null
  readonly property bool hasService: wallService !== null
  readonly property bool paused: hasService ? !!wallService.effectivePaused : false
  readonly property string currentName: hasService ? Model.fileName(String(wallService.currentFile || "")) : ""
  readonly property int total: hasService ? wallService.queue.length : 0
  readonly property int index: hasService ? wallService.slideIndex : -1
  readonly property bool showCounter: setting("showCounter", false) === true
  readonly property bool showFilename: setting("showFilename", false) === true

  property bool popupOpen: false
  function close() { popupOpen = false; }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: " "
    fixedWidth: 30
    active: root.hasService && !root.paused
    dimmed: root.paused
    Rectangle {
      anchors.centerIn: parent
      width: 12
      height: 12
      radius: 3
      color: "transparent"
      border.color: button.active && button.useActiveColor ? button.activeColor : button.foreground
      border.width: 2
    }
    tooltipText: {
      if (!root.hasService) return "omaWall: ative o serviço iaeluk.omawall";
      var t = root.currentName !== "" ? root.currentName : "omaWall";
      var c = Model.prettyCounter(root.index, root.total);
      if (c !== "") t += "  ·  " + c;
      if (root.hasService) {
        t += "  ·  " + (root.paused ? "pausado" : "próxima em " + Model.formatCountdown(wallService.remainingSeconds));
      }
      return t;
    }
    onPressed: function (mouseButton) {
      if (mouseButton === Qt.RightButton) {
        if (root.hasService) root.wallService.goNext(true);
        else root.warnNoService();
      } else if (mouseButton === Qt.MiddleButton) {
        if (root.hasService) root.wallService.togglePause();
        else root.warnNoService();
      } else {
        root.popupOpen = !root.popupOpen;
      }
    }
    onWheelMoved: function (delta) {
      if (!root.hasService) return;
      if (delta > 0) root.wallService.goPrevious(true);
      else if (delta < 0) root.wallService.goNext(true);
    }
  }

  Text {
    visible: root.showCounter && root.total > 0
    anchors.left: button.right
    anchors.leftMargin: 2
    anchors.verticalCenter: parent.verticalCenter
    text: Model.prettyCounter(root.index, root.total)
    color: root.bar ? root.bar.barForeground : "#fff"
    font.pixelSize: 11
  }

  function warnNoService() {
    noServiceProc.command = ["omarchy-notification-send", "-g", "⚠", "omaWall: serviço inativo",
      "Adicione {\"id\": \"iaeluk.omawall\"} em plugins[] no shell.json e reinicie o shell.", "-t", "4000"];
    noServiceProc.running = true;
  }

  Process { id: noServiceProc }

  OmawallCard {
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    svc: root.wallService
    widget: root
    onRequestClose: root.popupOpen = false
  }
}
