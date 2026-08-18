import QtQuick

Rectangle {
    id: root

    property alias text: label.text

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 6
    radius: 9999
    color: "#000000"
    border.color: "#ffffff"
    border.width: 1

    Text {
        id: label

        anchors.centerIn: parent
        color: "#ffffff"
        font.family: "Monocraft"
        font.pixelSize: 12
        font.weight: Font.Normal
    }
}
