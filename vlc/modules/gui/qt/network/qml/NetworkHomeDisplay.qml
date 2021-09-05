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
import QtQml.Models 2.2
import QtQml 2.11

import org.videolan.vlc 0.1

import "qrc:///widgets/" as Widgets
import "qrc:///main/" as MainInterface
import "qrc:///util/" as Util
import "qrc:///style/"

FocusScope {
    id: topFocusScope
    focus: true

    function _centerFlickableOnItem(minY, maxY) {
        if (maxY > flickable.contentItem.contentY + flickable.height) {
            flickable.contentItem.contentY = maxY - flickable.height
        } else if (minY < flickable.contentItem.contentY) {
            flickable.contentItem.contentY = minY
        }
    }

    function _actionAtIndex(index, model, selectionModel) {
        if (selectionModel.items.get(index).model.type === NetworkMediaModel.TYPE_DIRECTORY
                || selectionModel.items.get(index).model.type === NetworkMediaModel.TYPE_NODE)  {
            history.push(["mc", "network", { tree: selectionModel.items.get(index).model.tree }]);
        } else {
            model.addAndPlay( selectionModel.selectedIndexes )
        }
    }

    Label {
        anchors.centerIn: parent
        visible: (deviceSection.model.count === 0 && lanSection.model.count === 0 )
        font.pixelSize: VLCStyle.fontHeight_xxlarge
        color: topFocusScope.activeFocus ? VLCStyle.colors.accent : VLCStyle.colors.text
        text: i18n.qtr("No network shares found")
    }

    ScrollView {
        id: flickable
        anchors.fill: parent
        focus: true

        Column {
            width: parent.width
            height: implicitHeight

            topPadding: VLCStyle.margin_large
            spacing: VLCStyle.margin_small

            Widgets.SubtitleLabel {
                id: deviceLabel
                text: i18n.qtr("My Machine")
                width: flickable.width
                visible: deviceSection.model.count !== 0
                leftPadding: VLCStyle.margin_xlarge
            }

            NetworkHomeDeviceListView {
                id: deviceSection
                ctx: mainctx
                sd_source: NetworkDeviceModel.CAT_DEVICES

                width: flickable.width
                visible: deviceSection.model.count !== 0
                onVisibleChanged: topFocusScope.resetFocus()

                Navigation.parentItem: topFocusScope
                Navigation.downItem: lanSection.visible ?  lanSection : null

                onActiveFocusChanged: {
                    if (activeFocus)
                        _centerFlickableOnItem(deviceLabel.y, deviceSection.y + deviceSection.height)
                }
            }

            Widgets.SubtitleLabel {
                id: lanLabel
                text: i18n.qtr("My LAN")
                width: flickable.width
                visible: lanSection.model.count !== 0
                leftPadding: VLCStyle.margin_xlarge
                topPadding: deviceLabel.visible ? VLCStyle.margin_small : 0
            }

            NetworkHomeDeviceListView {
                id: lanSection
                ctx: mainctx
                sd_source: NetworkDeviceModel.CAT_LAN

                width: flickable.width
                visible: lanSection.model.count !== 0
                onVisibleChanged: topFocusScope.resetFocus()

                Navigation.parentItem: topFocusScope
                Navigation.upItem: deviceSection.visible ?  deviceSection : null

                onActiveFocusChanged: {
                    if (activeFocus)
                        _centerFlickableOnItem(lanLabel.y, lanSection.y + lanSection.height)
                }
            }
        }

    }

    Component.onCompleted: resetFocus()
    onActiveFocusChanged: resetFocus()
    function resetFocus() {
        var widgetlist = [deviceSection, lanSection]
        var i;
        for (i in widgetlist) {
            if (widgetlist[i].activeFocus && widgetlist[i].visible)
                return
        }

        var found  = false;
        for (i in widgetlist) {
            if (widgetlist[i].visible && !found) {
                widgetlist[i].focus = true
                found = true
            } else {
                widgetlist[i].focus = false
            }
        }
    }
}
