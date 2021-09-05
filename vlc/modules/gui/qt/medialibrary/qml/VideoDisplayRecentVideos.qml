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

import org.videolan.medialib 0.1
import org.videolan.vlc 0.1

import "qrc:///widgets/" as Widgets
import "qrc:///util/" as Util
import "qrc:///util/Helpers.js" as Helpers
import "qrc:///style/"

FocusScope {
    id: root

    property Item focusItem: recentVideosListView
    implicitHeight: recentVideosColumn.height

    property int leftPadding: VLCStyle.margin_xlarge
    property int rightPadding: VLCStyle.margin_xlarge

    property int currentIndex: -1

    property var model: undefined;

    onCurrentIndexChanged: {
        recentVideoListView.currentIndex = _currentIndex
    }

    function _actionAtIndex(index, model, selectionModel) {
        g_mainDisplay.showPlayer()
        medialib.addAndPlay( model.getIdsForIndexes( selectionModel.selectedIndexes ), [":restore-playback-pos=2"] )
    }

    onFocusChanged: {
        if (activeFocus && root.currentIndex === -1 && root.model.count > 0)
            root.currentIndex = 0
    }


    Util.SelectableDelegateModel {
        id: recentVideoSelection
        model: root.model
    }

    Column {
        id: recentVideosColumn

        width: root.width
        spacing: VLCStyle.margin_xsmall

        Widgets.SubtitleLabel {
            id: continueWatchingLabel
            leftPadding: VLCStyle.margin_xlarge
            width: parent.width
            text: i18n.qtr("Continue Watching")
        }

        Widgets.KeyNavigableListView {
            id: recentVideosListView

            width: parent.width
            implicitHeight: VLCStyle.gridItem_video_height_large + VLCStyle.gridItemSelectedBorder + VLCStyle.margin_xlarge
            spacing: VLCStyle.column_margin_width
            orientation: ListView.Horizontal

            focus: true
            Navigation.parentItem: root
            Navigation.downAction: function() {
                recentVideosListView.focus = false
                view.currentItem.setCurrentItemFocus()
            }

            model: root.model

            header: Item {
                width: VLCStyle.margin_xlarge
            }

            delegate: VideoGridItem {
                id: recentVideoGridItem

                focus: true
                x: selectedBorderWidth
                y: selectedBorderWidth
                pictureWidth: VLCStyle.gridCover_video_width_large
                pictureHeight: VLCStyle.gridCover_video_height_large
                unselectedUnderlay: shadows.unselected
                selectedUnderlay: shadows.selected

                onItemDoubleClicked: recentVideoGridItem.play()

                onItemClicked: {
                    recentVideoSelection.updateSelection( modifier , root.model.currentIndex, index )
                    recentVideosListView.currentIndex = index
                    recentVideosListView.forceActiveFocus()
                }

                Connections {
                    target: recentVideoSelection

                    onSelectionChanged: selected = recentVideoSelection.isSelected(root.model.index(index, 0))
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: VLCStyle.duration_faster
                    }
                }

                function play() {
                    if (model.id !== undefined) {
                        g_mainDisplay.showPlayer()
                        medialib.addAndPlay( model.id, [":restore-playback-pos=2"] )
                    }
                }
            }

            footer: Item {
                width: VLCStyle.margin_xlarge
            }

            onSelectionUpdated: recentVideoSelection.updateSelection( keyModifiers, oldIndex, newIndex )
            onActionAtIndex: {
                g_mainDisplay.showPlayer()
                medialib.addAndPlay( model.getIdsForIndexes( recentVideoSelection.selectedIndexes ), [":restore-playback-pos=2"] )
            }

            Widgets.GridShadows {
                id: shadows

                coverWidth: VLCStyle.gridCover_video_width_large
                coverHeight: VLCStyle.gridCover_video_height_large
            }
        }
    }
}
