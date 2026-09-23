import QtQuick
import qs.Commons
import qs.Ui

Button {
    id: root

    focusable: true
    color: activeFocus || selected || hot ? Util.alpha(foreground, 0.09) : "transparent"
    borderSpec: activeFocus ? Border.flat(foreground, 2) : Border.none()
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText || text
    Accessible.onPressAction: root.clicked()
}
