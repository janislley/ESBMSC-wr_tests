/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
 *
 * Authors: Prince Gupta <guptaprince8832@gmail.com>
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

import "qrc:///style/"

Rectangle {
    id: root

    //---------------------------------------------------------------------------------------------
    // Settings
    //---------------------------------------------------------------------------------------------

    property bool active: activeFocus

    // background of this component changes, set it in binding, the changes will be animated
    property color backgroundColor: "transparent"

    // `foregroundColor` property is not used in this component but is
    // provided as a convienence as it gets animated with color property
    property color foregroundColor: {
        if (backgroundColor.a === 0)
            return VLCStyle.colors.text
        var brightness = backgroundColor.r*0.299 + backgroundColor.g*0.587 + backgroundColor.b*0.114
        return brightness > .6 ? "black" : "white"
    }

    property color activeBorderColor: VLCStyle.colors.bgFocus

    property int animationDuration: VLCStyle.duration_normal

    property bool backgroundAnimationRunning: false

    property bool borderColorAnimationRunning: false

    //---------------------------------------------------------------------------------------------
    // Implementation
    //---------------------------------------------------------------------------------------------

    color: backgroundColor

    border.color: root.active
                  ? root.activeBorderColor
                  : VLCStyle.colors.setColorAlpha(root.activeBorderColor, 0)

    //---------------------------------------------------------------------------------------------
    // Animations
    //---------------------------------------------------------------------------------------------

    Behavior on border.color {
        ColorAnimation {
            duration: root.animationDuration
            onRunningChanged: {
                root.borderColorAnimationRunning = running
                if (running && root.active) {
                    border.width = Qt.binding(function() { return VLCStyle.focus_border })
                } else if (!running && !root.active) {
                    border.width = 0
                }
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            id: bgAnimation

            duration: root.animationDuration
            onRunningChanged: root.backgroundAnimationRunning = running
        }
    }

    Behavior on foregroundColor {
        ColorAnimation {
            duration: root.animationDuration
        }
    }
}
