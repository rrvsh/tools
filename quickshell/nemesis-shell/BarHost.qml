pragma ComponentBehavior: Bound

// PanelWindow is creatable at runtime despite the Quickshell 0.3.0 qmltypes annotation.
// qmllint disable uncreatable-type

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root

    required property var modelData

    property bool revealRequested: false
    property bool powerMenuOpen: false
    property int hoveredControls: 0

    function setControlHovered(hovered) {
        hoveredControls += hovered ? 1 : -1;
        hoveredControls = Math.max(hoveredControls, 0);
        if (hoveredControls > 0) {
            hideTimer.stop();
            revealRequested = true;
        } else {
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer

        interval: 300
        onTriggered: {
            if (root.hoveredControls === 0) {
                root.powerMenuOpen = false;
                root.revealRequested = false;
            }
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    PanelWindow {
        id: edgeWindow

        screen: root.modelData
        implicitHeight: 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nemesis-shell-edge"

        anchors {
            top: true
            left: true
            right: true
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    root.revealRequested = true;
                } else {
                    hideTimer.restart();
                }
            }
        }
    }

    PanelWindow {
        id: barWindow

        screen: root.modelData
        visible: (Hyprland.monitorFor(root.modelData)?.activeWorkspace?.toplevels?.values.length ?? 0) === 0 || root.revealRequested || root.powerMenuOpen
        implicitHeight: root.powerMenuOpen ? 72 : 31
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        mask: Region {
            Region {
                item: currentTask
            }
            Region {
                item: currentTime
            }
            Region {
                item: power
            }
            Region {
                item: powerMenu
            }
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nemesis-shell-bar"

        anchors {
            top: true
            left: true
            right: true
        }

        Pill {
            id: currentTask

            text: {
                const minutes = clock.hours * 60 + clock.minutes;
                if (minutes >= 360 && minutes < 480)
                    return "chill";
                if (minutes >= 480 && minutes < 600)
                    return "study";
                if (minutes >= 600 && minutes < 840)
                    return "work";
                if (minutes >= 840 && minutes < 960)
                    return "chill";
                if (minutes >= 960 && minutes < 1080)
                    return "work";
                if (minutes >= 1080 && minutes < 1260)
                    return "chill";
                return "free";
            }
            anchors {
                top: parent.top
                left: parent.left
                topMargin: 4
            }

            HoverHandler {
                onHoveredChanged: root.setControlHovered(hovered)
            }
        }

        Pill {
            id: currentTime

            text: Qt.formatDateTime(clock.date, "HH:mm")
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: 4
            }

            HoverHandler {
                onHoveredChanged: root.setControlHovered(hovered)
            }
        }

        Pill {
            id: power

            text: "⏻"
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 4
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.powerMenuOpen = !root.powerMenuOpen;
                    if (root.powerMenuOpen) {
                        hideTimer.stop();
                        root.revealRequested = true;
                    } else {
                        hideTimer.restart();
                    }
                }
            }

            HoverHandler {
                onHoveredChanged: root.setControlHovered(hovered)
            }
        }

        Rectangle {
            id: powerMenu

            visible: root.powerMenuOpen
            implicitWidth: powerMenuLabel.implicitWidth + 16
            implicitHeight: powerMenuLabel.implicitHeight + 12
            radius: 8
            color: "#000000"
            border.color: "#ffffff"
            border.width: 1
            anchors {
                top: power.bottom
                right: parent.right
                topMargin: 6
            }

            Text {
                id: powerMenuLabel

                anchors.centerIn: parent
                text: "Reboot to Windows 11"
                color: "#ffffff"
                font.family: "Monocraft"
                font.pixelSize: 12
                font.weight: Font.Normal
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.powerMenuOpen = false;
                    Quickshell.execDetached(["/run/wrappers/bin/sudo", "@systemctl@", "reboot", "--boot-loader-entry", "windows_11-pro.conf"]);
                }
            }

            HoverHandler {
                onHoveredChanged: root.setControlHovered(hovered)
            }
        }
    }
}
