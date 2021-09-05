
/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
import QtQml.Models 2.11

import org.videolan.vlc 0.1

import "qrc:///style/"
import "qrc:///widgets/" as Widgets

import org.videolan.vlc 0.1

Control {
    id: control

    property var path
    signal homeButtonClicked

    property var _contentModel
    property var _menuModel

    readonly property int maximumWidth: VLCStyle.bannerTabButton_width_large * 4
    readonly property int minimumWidth: VLCStyle.bannerTabButton_width_large

    onPathChanged: createContentModel()
    onAvailableWidthChanged: createContentModel()
    implicitWidth: VLCStyle.bannerTabButton_width_large * 4
    implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
    focus: true
    onActiveFocusChanged: if (activeFocus)
                              contentItem.forceActiveFocus()

    function changeTree(newTree) {
        history.push(["mc", "network", {
                          "tree": newTree
                      }])
    }

    function createContentModel() {
        var contentModel = []
        var menuModel = []
        if (path.length < 1)
            return
        var leftWidth = control.availableWidth
        var i = path.length
        while (--i >= 0) {
            var textWidth = fontMetrics.advanceWidth(path[i].display)
                    + (i !== path.length - 1 ? iconMetrics.advanceWidth(
                                                    VLCIcons.back) : 0) + VLCStyle.margin_xsmall * 4

            if (i < path.length - 1 && textWidth > leftWidth)
                menuModel.push(path[i])
            else
                contentModel.unshift(path[i])
            leftWidth -= textWidth
        }
        control._contentModel = contentModel
        control._menuModel = menuModel
    }

    background: Rectangle {
        border.width: VLCStyle.dp(1, VLCStyle.scale)
        border.color: VLCStyle.colors.setColorAlpha(VLCStyle.colors.text, .4)
        color: VLCStyle.colors.bg
    }

    contentItem: RowLayout {
        spacing: VLCStyle.margin_xxsmall
        width: control.availableWidth
        onActiveFocusChanged: if (activeFocus)
                                  homeButton.forceActiveFocus()

        AddressbarButton {
            id: homeButton

            text: VLCIcons.home

            Layout.fillHeight: true

            Navigation.parentItem: control
            Navigation.rightAction: function () {
                if (menuButton.visible)
                        menuButton.forceActiveFocus()
                else
                    contentRepeater.itemAt(0).forceActiveFocus()
            }
            Keys.priority: Keys.AfterItem
            Keys.onPressed: Navigation.defaultKeyAction(event)

            onClicked: control.homeButtonClicked()
        }

        AddressbarButton {
            id: menuButton

            visible: !!control._menuModel && control._menuModel.length > 0
            text: VLCIcons.back + VLCIcons.back
            font.pixelSize: VLCIcons.pixelSize(VLCStyle.icon_small)

            Layout.fillHeight: true

            Navigation.parentItem: control
            Navigation.leftItem: homeButton
            Navigation.rightAction: function () {
                contentRepeater.itemAt(0).forceActiveFocus()
            }
            Keys.priority: Keys.AfterItem
            Keys.onPressed: Navigation.defaultKeyAction(event)

            onClicked: popup.show()
        }

        Repeater {
            id: contentRepeater
            model: control._contentModel
            delegate: RowLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.maximumWidth: implicitWidth
                focus: true
                spacing: VLCStyle.margin_xxxsmall
                onActiveFocusChanged: {
                    if (activeFocus)
                                btn.forceActiveFocus()
                }

                Navigation.parentItem: control
                Navigation.leftAction: function() {
                    if (index !== 0)
                        contentRepeater.itemAt(index - 1).forceActiveFocus()
                    else if (menuButton.visible)
                        menuButton.forceActiveFocus()
                    else
                        homeButton.forceActiveFocus()
                }

                Navigation.rightAction: function () {
                    if (index !== contentRepeater.count - 1)
                        contentRepeater.itemAt(index + 1).forceActiveFocus()
                    else
                        control.Navigation.defaultNavigationRight()
                }

                Keys.priority: Keys.AfterItem
                Keys.onPressed: Navigation.defaultKeyAction(event)

                AddressbarButton {
                    id: btn

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: modelData.display
                    onlyIcon: false
                    highlighted: index === contentRepeater.count - 1

                    onClicked: changeTree(modelData.tree)
                }

                Widgets.IconLabel {
                    Layout.fillHeight: true
                    visible: index !== contentRepeater.count - 1
                    text: VLCIcons.back
                    rotation: 180
                    font.pixelSize: VLCIcons.pixelSize(VLCStyle.icon_small)
                    color: VLCStyle.colors.text
                    opacity: .6
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    FontMetrics {
        id: fontMetrics
        font.pixelSize: VLCStyle.fontSize_large
    }

    FontMetrics {
        id: iconMetrics
        font {
            pixelSize: VLCStyle.fontSize_large
            family: VLCIcons.fontFamily
        }
    }

    StringListMenu {
        id: popup

        function show() {
            var model = control._menuModel.map(function (modelData) {
                return modelData.display
            })

            var point = control.mapToGlobal(0, menuButton.height + VLCStyle.margin_xxsmall)

            popup.popup(point, model)
        }

        onSelected: {
            changeTree(control._menuModel[index].tree)
        }
    }
}
