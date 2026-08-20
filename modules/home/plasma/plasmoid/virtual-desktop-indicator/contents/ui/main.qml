import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    // @accent@ gets substituted from the accent binding in plasma/default.nix
    // at build time, so this file isn't loadable directly from the repo.
    readonly property color activeColor: "@accent@"
    readonly property color inactiveColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)

    // Mirrors the numpad layer of my gkey Vibraphone keyboard:
    //
    //   https://github.com/gplusplus314/gkey
    //     456
    //     1230
    //     789
    //
    // Rows use 0-based indices; the top and bottom rows leave the fourth
    // column empty.
    readonly property var positions: [
        { desktop: 4,  col: 0, row: 0 },
        { desktop: 5,  col: 1, row: 0 },
        { desktop: 6,  col: 2, row: 0 },
        { desktop: 1,  col: 0, row: 1 },
        { desktop: 2,  col: 1, row: 1 },
        { desktop: 3,  col: 2, row: 1 },
        { desktop: 10, col: 3, row: 1 },
        { desktop: 7,  col: 0, row: 2 },
        { desktop: 8,  col: 1, row: 2 },
        { desktop: 9,  col: 2, row: 2 }
    ]

    TaskManager.VirtualDesktopInfo {
        id: vdi
    }

    readonly property int currentPosition:
        (vdi.desktopIds && vdi.currentDesktop !== undefined)
            ? vdi.desktopIds.indexOf(vdi.currentDesktop) + 1
            : 0

    preferredRepresentation: fullRepresentation

    fullRepresentation: Item {
        readonly property real cell: Math.min(width / 4, height / 3)
        readonly property real dot: Math.max(3, Math.floor(cell * 0.85))

        Layout.fillHeight: true
        Layout.preferredWidth: Math.round(height / 3 * 4)
        Layout.minimumWidth: 12

        Repeater {
            model: root.positions
            delegate: Rectangle {
                required property var modelData
                width: parent.dot
                height: parent.dot
                radius: width / 2
                x: modelData.col * parent.cell + (parent.cell - width) / 2
                y: modelData.row * parent.cell + (parent.cell - height) / 2
                color: modelData.desktop === root.currentPosition
                    ? root.activeColor
                    : root.inactiveColor
            }
        }
    }
}
