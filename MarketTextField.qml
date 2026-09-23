import QtQuick
import qs.Commons
import qs.Ui

TextField {
    id: root

    placeholderTextColor: foreground

    background: Rectangle {
        color: Util.alpha(root.foreground, 0.05)
        radius: Style.cornerRadius
        border.color: root.foreground
        border.width: root.activeFocus ? 2 : 1
    }

}
