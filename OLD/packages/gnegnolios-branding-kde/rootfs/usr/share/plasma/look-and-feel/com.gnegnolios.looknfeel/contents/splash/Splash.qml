import QtQuick 2.5

Rectangle {
    id: root
    color: "#0D0D0D"

    property int stage

    Image {
        anchors.centerIn: parent
        width: Math.min(root.width, root.height) * 0.3
        height: width
        source: "/usr/share/gnegnolios/logos/gnegnolios-mark.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Component.onCompleted: root.stage = 1
}
