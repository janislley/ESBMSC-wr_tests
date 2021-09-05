﻿/*****************************************************************************
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
import QtQuick.Controls 2.4
import QtQuick 2.11
import QtQml.Models 2.2
import QtQuick.Layouts 1.3

import org.videolan.medialib 0.1
import org.videolan.controls 0.1
import org.videolan.vlc 0.1

import "qrc:///util/" as Util
import "qrc:///util/Helpers.js" as Helpers
import "qrc:///widgets/" as Widgets
import "qrc:///main/" as MainInterface
import "qrc:///style/"

FocusScope {
    id: root

    property alias model: artistModel
    property var sortModel: [
        { text: i18n.qtr("Alphabetic"),  criteria: "title" }
    ]

    property alias currentIndex: artistList.currentIndex
    property alias currentAlbumIndex: albumSubView.currentIndex
    property int initialIndex: 0
    property int initialAlbumIndex: 0
    property alias currentArtist: albumSubView.artist

    onInitialAlbumIndexChanged: resetFocus()
    onInitialIndexChanged: resetFocus()
    onCurrentIndexChanged: currentArtist = model.getDataAt(currentIndex)

    function resetFocus() {
        if (artistModel.count === 0) {
            return
        }
        var initialIndex = root.initialIndex
        if (initialIndex >= artistModel.count)
            initialIndex = 0
        if (initialIndex !== artistList.currentIndex) {
            selectionModel.select(artistModel.index(initialIndex, 0), ItemSelectionModel.ClearAndSelect)
            if (artistList) {
                artistList.currentIndex = initialIndex
                artistList.positionViewAtIndex(initialIndex, ItemView.Contain)
            }
        }
    }

    function _actionAtIndex(index) {
        albumSubView.forceActiveFocus()
    }

    MLArtistModel {
        id: artistModel
        ml: medialib

        onCountChanged: {
            if (artistModel.count > 0 && !selectionModel.hasSelection) {
                var initialIndex = root.initialIndex
                if (initialIndex >= artistModel.count)
                    initialIndex = 0
                artistList.currentIndex = initialIndex
            }
        }

        onDataChanged: {
            if (topLeft.row <= currentIndex && bottomRight.row >= currentIndex)
                currentArtist = artistModel.getDataAt(currentIndex)
        }
    }

    Util.SelectableDelegateModel {
        id: selectionModel
        model: artistModel
    }

    FocusScope {
        visible: artistModel.count > 0
        focus: visible
        anchors.fill: parent

        Rectangle {
            width: artistList.width
            height: artistList.height
            color: VLCStyle.colors.bgAlt
            opacity: .8
        }

        Row {
            anchors.fill: parent

            Widgets.KeyNavigableListView {
                id: artistList

                spacing: 4
                model: artistModel
                currentIndex: -1
                z: 1
                height: parent.height
                width: Helpers.clamp(root.width / resizeHandle.widthFactor,
                                     VLCStyle.colWidth(1) + VLCStyle.column_margin_width,
                                     root.width * .5)

                focus: true
                displayMarginEnd: miniPlayer.height // to get blur effect while scrolling in mainview
                Navigation.parentItem: root
                Navigation.rightItem: albumSubView
                Navigation.cancelAction: function() {
                    if (artistList.currentIndex <= 0)
                        root.Navigation.defaultNavigationCancel()
                    else
                        artistList.currentIndex = 0;
                }

                header: Widgets.SubtitleLabel {
                    text: i18n.qtr("Artists")
                    font.pixelSize: VLCStyle.fontSize_large
                    leftPadding: VLCStyle.margin_normal
                    bottomPadding: VLCStyle.margin_small
                    topPadding: VLCStyle.margin_xlarge
                }

                delegate: Widgets.AnimatedBackground {
                    id: item

                    property bool _highlighted: mouseArea.containsMouse || this.activeFocus

                    height: VLCStyle.play_cover_small + (VLCStyle.margin_xsmall * 2)
                    width: artistList.width
                    active: false
                    backgroundColor: _highlighted ? VLCStyle.colors.bgHover : "transparent"
                    foregroundColor: _highlighted ? VLCStyle.colors.bgHoverText : VLCStyle.colors.text

                    Widgets.CurrentIndicator {
                       visible: item.ListView.isCurrentItem
                    }

                    RowLayout {
                        spacing: VLCStyle.margin_xsmall
                        anchors {
                            fill: parent
                            leftMargin: VLCStyle.margin_normal
                            rightMargin: VLCStyle.margin_normal
                            topMargin: VLCStyle.margin_xsmall
                            bottomMargin: VLCStyle.margin_xsmall
                        }

                        RoundImage {
                            source: model.cover || VLCStyle.noArtArtistSmall
                            height: VLCStyle.play_cover_small
                            width: VLCStyle.play_cover_small
                            radius: VLCStyle.play_cover_small

                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: VLCStyle.play_cover_small
                                border.width: VLCStyle.dp(1, VLCStyle.scale)
                                border.color: !_highlighted ? VLCStyle.colors.roundPlayCoverBorder : VLCStyle.colors.accent
                            }
                        }

                        Widgets.ListLabel {
                            text: model.name || i18n.qtr("Unknown artist")
                            color: item.foregroundColor

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                    }

                    MouseArea {
                        id: mouseArea

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            selectionModel.updateSelection( mouse.modifiers , artistList.currentIndex, index)
                            artistList.currentIndex = index
                            artistList.forceActiveFocus()
                        }

                        onDoubleClicked: {
                            if (mouse.buttons === Qt.LeftButton)
                                medialib.addAndPlay( model.id )
                            else
                                albumSubView.forceActiveFocus()
                        }

                        drag.axis: Drag.XAndYAxis
                        drag.target: Widgets.DragItem {
                            function updateComponents(maxCovers) {
                                return {
                                    covers: [{artwork: model.cover || VLCStyle.noArtArtistSmall}],
                                    title: model.name || i18n.qtr("Unknown artist"),
                                    count: 1
                                }
                            }

                            function getSelectedInputItem() {
                                return artistModel.getItemsForIndexes([artistModel.index(index, 0)])
                            }
                        }

                        drag.onActiveChanged: {
                            var dragItem = drag.target

                            if (!drag.active)
                                dragItem.Drag.drop()

                            dragItem.Drag.active = drag.active
                        }

                        onPositionChanged: {
                            if (drag.active) {
                                var pos = drag.target.parent.mapFromItem(item, mouseX, mouseY)
                                drag.target.x = pos.x + 12
                                drag.target.y = pos.y + 12
                            }
                        }
                    }
                }

                Behavior on width {
                    SmoothedAnimation {
                        easing.type: Easing.InSine
                        duration: VLCStyle.ms10
                    }
                }

                Widgets.HorizontalResizeHandle {
                    id: resizeHandle

                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right

                        rightMargin: -(width / 2)
                    }
                    sourceWidth: root.width
                    targetWidth: artistList.width
                }
            }

            MusicArtist {
                id: albumSubView

                height: parent.height
                width: root.width - artistList.width
                focus: true
                initialIndex: root.initialAlbumIndex
                Navigation.parentItem: root
                Navigation.leftItem: artistList
            }
        }
    }

    EmptyLabel {
        anchors.fill: parent
        visible: artistModel.count === 0
        focus: visible
        text: i18n.qtr("No artists found\nPlease try adding sources, by going to the Network tab")
        Navigation.parentItem: root
    }
}
