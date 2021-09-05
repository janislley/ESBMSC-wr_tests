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
import org.videolan.vlc 0.1
import QtQml.Models 2.11

import "qrc:///style/"
import "qrc:///widgets/" as Widgets
import "qrc:///menus/" as Menus
import "qrc:///util/Helpers.js" as Helpers

FocusScope {
    id: root

    height: VLCStyle.applicationVerticalMargin
            + (menubar.visible ? menubar.height : 0)
            + VLCStyle.globalToolbar_height
            + VLCStyle.localToolbar_height


    property int selectedIndex: 0
    property int subSelectedIndex: 0

    signal itemClicked(int index)

    property alias sortModel: sortControl.model
    property var contentModel
    property alias isViewMultiView: list_grid_btn.visible
    property alias model: pLBannerSources.model
    signal toogleMenu()

    property var extraLocalActions: undefined
    property alias localMenuDelegate: localMenuGroup.sourceComponent

    // Triggered when the toogleView button is selected
    function toggleView () {
        mainInterface.gridView = !mainInterface.gridView
    }

    function search() {
        if (searchBox.visible)
            searchBox.expanded = true
    }

    Rectangle {
        id: pLBannerSources

        anchors.fill: parent

        color: VLCStyle.colors.banner
        property alias model: globalMenuGroup.model

        Column {
            id: col
            anchors {
                fill: parent
                topMargin: VLCStyle.applicationVerticalMargin
            }

            Item {
                id: globalToolbar
                width: parent.width
                height: VLCStyle.globalToolbar_height
                    + (menubar.visible ? menubar.height : 0)
                anchors.rightMargin: VLCStyle.applicationHorizontalMargin

                property bool colapseTabButtons: globalToolbar.width  > (Math.max(globalToolbarLeft.width, globalToolbarRight.width) + VLCStyle.applicationHorizontalMargin)* 2
                                                 + globalMenuGroup.model.count * VLCStyle.bannerTabButton_width_large

                //drag and dbl click the titlebar in CSD mode
                Loader {
                    anchors.fill: parent
                    active: mainInterface.clientSideDecoration
                    source: "qrc:///widgets/CSDTitlebarTapNDrapHandler.qml"
                }

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: VLCStyle.applicationHorizontalMargin
                    anchors.rightMargin: VLCStyle.applicationHorizontalMargin

                    Menus.Menubar {
                        id: menubar
                        width: parent.width
                        height: implicitHeight
                        visible: mainInterface.hasToolbarMenu
                    }

                    Item {
                        width: parent.width
                        height: VLCStyle.globalToolbar_height

                        RowLayout {
                            id: globalToolbarLeft
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: VLCStyle.margin_xsmall
                            spacing: VLCStyle.margin_xxxsmall

                            Widgets.IconToolButton {
                                 id: history_back
                                 size: VLCStyle.banner_icon_size
                                 iconText: VLCIcons.topbar_previous
                                 text: i18n.qtr("Previous")
                                 height: VLCStyle.bannerButton_height
                                 width: VLCStyle.bannerButton_width
                                 colorDisabled: VLCStyle.colors.textDisabled
                                 onClicked: history.previous()
                                 enabled: !history.previousEmpty

                                 Navigation.parentItem: root
                                 Navigation.rightItem: globalMenuGroup
                                 Navigation.downItem: localMenuGroup.visible ? localMenuGroup : localToolbarBg
                             }

                            Image {
                                sourceSize.width: VLCStyle.icon_small
                                sourceSize.height: VLCStyle.icon_small
                                source: "qrc:///logo/cone.svg"
                                enabled: false
                            }

                        }

                        /* Button for the sources */
                        Widgets.NavigableRow {
                            id: globalMenuGroup

                            anchors {
                                top: parent.top
                                bottom: parent.bottom
                                horizontalCenter: parent.horizontalCenter
                            }

                            focus: true

                            Navigation.parentItem: root
                            Navigation.leftItem: history_back.enabled ? history_back : null
                            Navigation.downItem: localMenuGroup.visible ?  localMenuGroup : playlistGroup

                            delegate: Widgets.BannerTabButton {
                                iconTxt: model.icon
                                showText: globalToolbar.colapseTabButtons
                                selected: model.index === selectedIndex
                                onClicked: root.itemClicked(model.index)
                                height: globalMenuGroup.height
                            }
                        }
                    }
                }

                Loader {
                    id: globalToolbarRight
                    anchors {
                        top: parent.top
                        right: parent.right
                        rightMargin: VLCStyle.applicationHorizontalMargin
                    }
                    height: VLCStyle.globalToolbar_height
                    active: mainInterface.clientSideDecoration
                    source: "qrc:///widgets/CSDWindowButtonSet.qml"
                }
            }

            FocusScope {
                id: localToolbar

                width: parent.width
                height: VLCStyle.localToolbar_height

                onActiveFocusChanged: {
                    if (activeFocus) {
                        // sometimes when view changes, one of the "focusable" object will become disabled
                        // but because of focus chainning, FocusScope still tries to force active focus on the object
                        // but that will fail, manually assign focus in such cases
                        var focusable = [localContextGroup, localMenuGroup, playlistGroup]
                        if (!focusable.some(function (obj) { return obj.activeFocus; })) {
                            // no object has focus
                            localToolbar.nextItemInFocusChain(true).forceActiveFocus()
                        }
                    }
                }

                Rectangle {
                    id: localToolbarBg
                    color: VLCStyle.colors.bg
                    anchors.fill: parent
                }

                Rectangle {
                    anchors.left : localToolbarBg.left
                    anchors.right: localToolbarBg.right
                    anchors.top  : localToolbarBg.bottom

                    height: VLCStyle.border

                    color: VLCStyle.colors.bannerBorder
                }

                Widgets.NavigableRow {
                    id: localContextGroup
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        leftMargin: VLCStyle.applicationHorizontalMargin + VLCStyle.margin_xsmall
                    }
                    enabled: list_grid_btn.visible || sortControl.visible

                    model: ObjectModel {
                        id: localContextModel

                        property int countExtra: 0

                        Widgets.IconToolButton {
                            id: list_grid_btn

                            width: VLCStyle.bannerButton_width
                            height: VLCStyle.bannerButton_height
                            size: VLCStyle.banner_icon_size
                            iconText: mainInterface.gridView ? VLCIcons.list : VLCIcons.grid
                            text: i18n.qtr("List/Grid")
                            onClicked: mainInterface.gridView = !mainInterface.gridView
                            enabled: true
                        }

                        Widgets.SortControl {
                            id: sortControl

                            textRole: "text"
                            criteriaRole: "criteria"

                            width: VLCStyle.bannerButton_width
                            height: VLCStyle.bannerButton_height
                            iconSize: VLCStyle.banner_icon_size

                            visible: root.sortModel !== undefined && root.sortModel.length > 1
                            enabled: visible

                            onSortSelected: {
                                if (contentModel !== undefined) {
                                    contentModel.sortCriteria = type
                                }
                            }

                            onSortOrderSelected: {
                                if (contentModel !== undefined) {
                                    contentModel.sortOrder = type
                                }
                            }

                            sortKey: contentModel ? contentModel.sortCriteria : PlaylistControllerModel.SORT_KEY_NONE
                            sortOrder: contentModel ? contentModel.sortOrder : undefined
                        }
                    }

                    Connections {
                        target: root
                        onExtraLocalActionsChanged : {
                            for (var i = 0; i < localContextModel.countExtra; i++) {
                                localContextModel.remove(localContextModel.count - localContextModel.countExtra, localContextModel.countExtra)
                            }

                            if (root.extraLocalActions && root.extraLocalActions instanceof ObjectModel) {
                                for (i = 0; i < root.extraLocalActions.count; i++)
                                    localContextModel.append(root.extraLocalActions.get(i))
                                localContextModel.countExtra = root.extraLocalActions.count
                            } else {
                                localContextModel.countExtra = 0
                            }
                        }
                    }

                    Navigation.parentItem: root
                    Navigation.rightItem: localMenuGroup.visible ? localMenuGroup : playlistGroup
                    Navigation.upItem: globalMenuGroup
                }

                Flickable {
                    id: localMenuView

                    readonly property int availableWidth: parent.width
                                                          - (localContextGroup.width + playlistGroup.width)
                                                          - (VLCStyle.applicationHorizontalMargin * 2)
                                                          - (VLCStyle.margin_xsmall * 2)
                                                          - (VLCStyle.margin_xxsmall * 2)
                    readonly property bool _alignHCenter: ((localToolbar.width - contentWidth) / 2) + contentWidth < playlistGroup.x

                    width: Math.min(contentWidth, availableWidth)
                    height: VLCStyle.localToolbar_height
                    clip: true
                    contentWidth: localMenuGroup.width
                    contentHeight: VLCStyle.localToolbar_height // don't allow vertical flickering
                    anchors.rightMargin: VLCStyle.margin_xxsmall // only applied when right aligned

                    on_AlignHCenterChanged: {
                        if (_alignHCenter) {
                            anchors.horizontalCenter = localToolbar.horizontalCenter
                            anchors.right = undefined
                        } else {
                            anchors.horizontalCenter = undefined
                            anchors.right = playlistGroup.left
                        }
                    }

                    Loader {
                        id: localMenuGroup

                        focus: !!item && item.focus && item.visible
                        visible: !!item
                        enabled: status === Loader.Ready
                        y: status === Loader.Ready ? (VLCStyle.localToolbar_height - item.height) / 2 : 0
                        width: !!item
                               ? Helpers.clamp(localMenuView.availableWidth,
                                               localMenuGroup.item.minimumWidth || localMenuGroup.item.implicitWidth,
                                               localMenuGroup.item.maximumWidth || localMenuGroup.item.implicitWidth)
                               : 0

                        onVisibleChanged: {
                            //reset the focus on the global group when the local group is hidden,
                            //this avoids losing the focus if the subview changes
                            if (!visible && localMenuGroup.focus) {
                                localMenuGroup.focus = false
                                globalMenuGroup.focus = true
                            }
                        }

                        onItemChanged: {
                            if (!item)
                                return
                            item.Navigation.parentItem = root
                            item.Navigation.leftItem = Qt.binding(function(){ return localContextGroup.enabled ? localContextGroup : null})
                            item.Navigation.rightItem = Qt.binding(function(){ return playlistGroup.enabled ? playlistGroup : null})
                            item.Navigation.upItem = globalMenuGroup
                        }
                    }
                }

                Widgets.NavigableRow {
                    id: playlistGroup
                    anchors {
                        verticalCenter: parent.verticalCenter
                        right: parent.right
                        rightMargin: VLCStyle.applicationHorizontalMargin + VLCStyle.margin_xsmall
                    }
                    spacing: VLCStyle.margin_xxxsmall

                    model: ObjectModel {

                        Widgets.SearchBox {
                            id: searchBox
                            contentModel: root.contentModel
                            visible: root.contentModel !== undefined
                            enabled: visible
                            height: VLCStyle.bannerButton_height
                            buttonWidth: VLCStyle.bannerButton_width
                        }

                        Widgets.IconToolButton {
                            id: playlist_btn

                            size: VLCStyle.banner_icon_size
                            iconText: VLCIcons.playlist
                            text: i18n.qtr("Playlist")
                            width: VLCStyle.bannerButton_width
                            height: VLCStyle.bannerButton_height
                            highlighted: mainInterface.playlistVisible

                            onClicked:  mainInterface.playlistVisible = !mainInterface.playlistVisible
                        }

                        Widgets.IconToolButton {
                            id: menu_selector

                            size: VLCStyle.banner_icon_size
                            iconText: VLCIcons.ellipsis
                            text: i18n.qtr("Menu")
                            width: VLCStyle.bannerButton_width
                            height: VLCStyle.bannerButton_height

                            onClicked: contextMenu.popup(this.mapToGlobal(0, height))

                            QmlGlobalMenu {
                                id: contextMenu
                                ctx: mainctx
                            }
                        }
                    }

                    Navigation.parentItem: root
                    Navigation.leftItem: localMenuGroup.visible ? localMenuGroup : localContextGroup
                    Navigation.upItem: globalMenuGroup
                }
            }
        }

        Keys.priority: Keys.AfterItem
        Keys.onPressed: root.Navigation.defaultKeyAction(event)
    }
}
