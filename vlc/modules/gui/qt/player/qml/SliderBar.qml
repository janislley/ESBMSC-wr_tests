/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick 2.11
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0

import "qrc:///widgets/" as Widgets
import "qrc:///style/"

Slider {
    id: control

    property int barHeight: VLCStyle.dp(5, VLCStyle.scale)
    property bool _isHold: false
    property bool _isSeekPointsShown: true

    property alias parentWindow: timeTooltip.parentWindow
    property alias backgroundColor: sliderRect.color
    property alias progressBarColor: progressRect.color

    property VLCColors colors: VLCStyle.colors

    Keys.onRightPressed: player.jumpFwd()
    Keys.onLeftPressed: player.jumpBwd()

    function showChapterMarks() {
        _isSeekPointsShown = true
        seekpointTimer.restart()
    }

    Timer {
        id: seekpointTimer
        running: player.hasChapters && !control.hovered && _isSeekPointsShown
        interval: 3000
        onTriggered: control._isSeekPointsShown = false
    }

    Widgets.PointingTooltip {
        id: timeTooltip

        visible: control.hovered

        text: player.length.scale(timeTooltip.position).toString() +
              (player.hasChapters ?
                   " - " + player.chapters.getNameAtPosition(timeTooltip.position) : "")

        mouseArea: sliderRectMouseArea

        colors: control.colors
    }

    Connections {    
        /* only update the control position when the player position actually change, this avoid the slider
         * to jump around when clicking
         */
        target: player
        enabled: !_isHold
        onPositionChanged: control.value = player.position
    }

    height: control.barHeight
    implicitHeight: control.barHeight

    topPadding: 0
    leftPadding: 0
    bottomPadding: 0
    rightPadding: 0

    stepSize: 0.01

    background: Rectangle {
        id: sliderRect
        width: control.availableWidth
        implicitHeight: control.implicitHeight
        height: implicitHeight
        color: control.colors.setColorAlpha( control.colors.playerFg, 0.2 )
        radius: implicitHeight

        MouseArea {
            id: sliderRectMouseArea
            property bool isEntered: false

            anchors.fill: parent
            hoverEnabled: true

            onPressed: function (event) {
                control.forceActiveFocus()
                control._isHold = true
                control.value = event.x / control.width
                player.position = control.value
            }
            onReleased: control._isHold = false
            onPositionChanged: function (event) {
                if (pressed) {
                    if (event.x < 0) event.x = 0;
                    else if (event.x > control.width) event.x = control.width;

                    control.value = event.x / control.width
                    player.position = control.value
                }
            }
            onEntered: {
                if(player.hasChapters)
                    control._isSeekPointsShown = true
            }
            onExited: {
                if(player.hasChapters)
                    seekpointTimer.restart()
            }
        }

        Rectangle {
            id: progressRect
            width: control.visualPosition * parent.width
            height: control.barHeight
            color: control.activeFocus ? control.colors.accent : control.colors.bgHover
            radius: control.barHeight
        }

        Rectangle {
            id: bufferRect
            property int bufferAnimWidth: VLCStyle.dp(100, VLCStyle.scale)
            property int bufferAnimPosition: 0
            property int bufferFrames: 1000
            property alias animateLoading: loadingAnim.running

            height: control.barHeight
            opacity: 0.4
            color: control.colors.buffer
            radius: control.barHeight

            states: [
                State {
                    name: "buffering not started"
                    when: player.buffering === 0
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: true
                        x: (bufferAnimPosition / bufferFrames) * (parent.width - bufferAnimWidth)
                        animateLoading: true
                    }
                },
                State {
                    name: "time to start playing known"
                    when: player.buffering < 1
                    PropertyChanges {
                        target: bufferRect
                        width: player.buffering * parent.width
                        visible: true
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "playing from buffer"
                    when: player.buffering === 1
                    PropertyChanges {
                        target: bufferRect
                        width: player.buffering * parent.width
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                }
            ]

            SequentialAnimation on bufferAnimPosition {
                id: loadingAnim
                running: bufferRect.animateLoading
                loops: Animation.Infinite
                PropertyAnimation {
                    from: 0.0
                    to: bufferRect.bufferFrames
                    duration: VLCStyle.ms2000
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.ms500
                }
                PropertyAnimation {
                    from: bufferRect.bufferFrames
                    to: 0.0
                    duration: VLCStyle.ms2000
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.ms500
                }
            }
        }

        Item {
            id: seekpointsRow

            width: parent.width
            height: control.barHeight
            visible: player.hasChapters

            Repeater {
                id: seekpointsRptr
                model: player.chapters
                Rectangle {
                    id: seekpointsRect
                    property real position: model.position === undefined ? 0.0 : model.position

                    color: control.colors.seekpoint
                    width: VLCStyle.dp(1, VLCStyle.scale)
                    height: control.barHeight
                    x: sliderRect.width * seekpointsRect.position
                }
            }

            OpacityAnimator on opacity {
                from: 1
                to: 0
                running: !control._isSeekPointsShown
            }
            OpacityAnimator on opacity{
                from: 0
                to: 1
                running: control._isSeekPointsShown
            }
        }
    }

    handle: Rectangle {
        id: sliderHandle

        visible: control.activeFocus
        x: (control.visualPosition * control.availableWidth) - width / 2
        y: (control.barHeight - width) / 2
        implicitWidth: VLCStyle.margin_small
        implicitHeight: VLCStyle.margin_small
        radius: VLCStyle.margin_small
        color: control.colors.accent

        transitions: [
            Transition {
                to: "hidden"
                SequentialAnimation {
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"

                        to: 0

                        duration: VLCStyle.duration_fast; easing.type: Easing.OutSine
                    }

                    PropertyAction { target: sliderHandle; property: "visible"; value: false; }
                }
            },
            Transition {
                to: "visible"
                SequentialAnimation {
                    PropertyAction { target: sliderHandle; property: "visible"; value: true; }

                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"

                        to: VLCStyle.margin_small

                        duration: VLCStyle.duration_fast; easing.type: Easing.InSine
                    }
                }
            }
        ]

        state: (control.hovered || control.activeFocus) ? "visible" : "hidden"
    }
}
