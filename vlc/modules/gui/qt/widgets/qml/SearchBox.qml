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

import org.videolan.vlc 0.1

import "qrc:///style/"
import "qrc:///widgets/" as Widgets

FocusScope {
    id: root

    width: content.width

    property variant contentModel
    property alias buttonWidth: icon.width

    property bool expanded: false

    onExpandedChanged: {
        if (expanded) {
            searchBox.forceActiveFocus()
            icon.Navigation.rightItem = searchBox
            animateExpand.start()
        }
        else {
            searchBox.placeholderText = ""
            searchBox.text = ""
            icon.focus = true
            searchBox.focus = false
            icon.Navigation.rightItem = null
            animateRetract.start()
        }
    }

    onActiveFocusChanged: {
        if (!activeFocus && searchBox.text == "")
            expanded = false
    }

    SmoothedAnimation {
        id: animateExpand;
        target: searchBoxRect;
        properties: "width"
        duration: VLCStyle.ms125
        to: VLCStyle.widthSearchInput
        easing.type: Easing.InSine
        onStopped: {
            searchBox.placeholderText = i18n.qtr("filter")
        }
    }

    SmoothedAnimation {
        id: animateRetract;
        target: searchBoxRect;
        properties: "width"
        duration: VLCStyle.ms125
        to: 0
        easing.type: Easing.OutSine
    }


    Row {
        id: content

        Widgets.IconToolButton {
            id: icon

            size: VLCStyle.banner_icon_size
            iconText: VLCIcons.search
            text: i18n.qtr("Filter")
            height: root.height

            focus: true

            onClicked: {
                if (searchBox.text == "")
                    expanded = !expanded
                else {
                    searchBox.clear()
                    expanded = !expanded
                }
            }

            Navigation.parentItem: root
            Keys.priority: Keys.AfterItem
            Keys.onPressed: Navigation.defaultKeyAction(event)
        }

        Rectangle {
            id: searchBoxRect
            color: VLCStyle.colors.button

            anchors.verticalCenter: parent.verticalCenter

            width: 0
            implicitHeight: searchBox.height

            border.color: {
                if ( searchBox.text.length < 3 && searchBox.text.length !== 0 )
                    return VLCStyle.colors.alert
                else if ( searchBox.activeFocus )
                    return VLCStyle.colors.accent
                else
                    return VLCStyle.colors.buttonBorder
            }

            TextField {
                id: searchBox

                enabled: root.expanded

                anchors.fill: searchBoxRect
                anchors.rightMargin: clearButton.visible ? (VLCStyle.margin_xxsmall + clearButton.width) : 0

                font.pixelSize: VLCStyle.fontSize_normal

                palette.text: VLCStyle.colors.buttonText
                palette.highlight: VLCStyle.colors.bgHover
                palette.highlightedText: VLCStyle.colors.bgHoverText

                selectByMouse: true

                background: Rectangle { color: "transparent" }

                onTextChanged: {
                    if (contentModel !== undefined)
                        contentModel.searchPattern = text;
                }

                Navigation.parentItem: root
                Navigation.leftItem: icon
                Navigation.rightItem: clearButton.visible ? clearButton : null
                Keys.priority: Keys.AfterItem
                Keys.onPressed: {
                    //don't use KeyHelper.matchCancel here as we don't want to match Backspace
                    if (event.key === Qt.Key_Back
                        || event.key === Qt.Key_Cancel
                        || event.matches(StandardKey.Back)
                        || event.matches(StandardKey.Cancel))
                    {
                        event.accepted = true
                    }
                    Navigation.defaultKeyAction(event)
                }

                Keys.onReleased: {
                    //don't use KeyHelper.matchCancel here as we don't want to match Backspace
                    if (event.key === Qt.Key_Back
                        || event.key === Qt.Key_Cancel
                        || event.matches(StandardKey.Back)
                        || event.matches(StandardKey.Cancel))
                    {
                        text = ""
                        expanded = false
                        event.accepted = true
                    }
                    Navigation.defaultKeyReleaseAction(event)
                }
            }

            Widgets.IconToolButton {
                id: clearButton

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.margin_xxsmall

                size: VLCStyle.icon_small
                iconText: VLCIcons.close

                visible: ( expanded && searchBox.text.length > 0 )
                enabled: visible

                onClicked: {
                    searchBox.clear()
                }

                Navigation.parentItem: root
                Navigation.leftItem: searchBox
                Keys.priority: Keys.AfterItem
                Keys.onPressed: Navigation.defaultKeyAction(event)
            }
        }
    }
}
