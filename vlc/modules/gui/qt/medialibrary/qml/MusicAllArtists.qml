/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import org.videolan.vlc 0.1

import "qrc:///util/" as Util
import "qrc:///widgets/" as Widgets
import "qrc:///main/" as MainInterface
import "qrc:///style/"

FocusScope {
    id: root

    readonly property int currentIndex: view.currentItem.currentIndex
    property int initialIndex: 0
    property alias model: artistModel

    onInitialIndexChanged: resetFocus()

    function requestArtistAlbumView() {
        console.assert(false, "must be reimplemented")
    }

    function resetFocus() {
        if (artistModel.count === 0)
            return

        var initialIndex = root.initialIndex
        if (initialIndex >= artistModel.count)
            initialIndex = 0
        selectionModel.select(artistModel.index(initialIndex, 0), ItemSelectionModel.ClearAndSelect)
        if (view.currentItem) {
            view.currentItem.currentIndex = initialIndex
            view.currentItem.positionViewAtIndex(initialIndex, ItemView.Contain)
        }
    }

    function _onNavigationCancel() {
        if (view.currentItem.currentIndex <= 0) {
            root.Navigation.defaultNavigationCancel()
        } else {
            view.currentItem.currentIndex = 0;
            view.currentItem.positionViewAtIndex(0, ItemView.Contain);
        }
    }

    MLArtistModel {
        id: artistModel
        ml: medialib

        onCountChanged: {
            if (artistModel.count > 0 && !selectionModel.hasSelection) {
                root.resetFocus()
            }
        }
    }

    Util.SelectableDelegateModel {
        id: selectionModel
        model: artistModel
    }

    ArtistContextMenu {
        id: contextMenu
        model: artistModel
    }

    Widgets.DragItem {
        id: artistsDragItem

        function updateComponents(maxCovers) {
          var items = selectionModel.selectedIndexes.slice(0, maxCovers).map(function (x){
            return artistModel.getDataAt(x.row)
          })
          var title = items.map(function (item){ return item.name}).join(", ")
          var covers = items.map(function (item) { return {artwork: item.cover || VLCStyle.noArtArtistSmall}})
          return {
            covers: covers,
            title: title,
            count: selectionModel.selectedIndexes.length
          }
        }

        function getSelectedInputItem() {
            return artistModel.getItemsForIndexes(selectionModel.selectedIndexes);
        }
    }

    Component {
        id: gridComponent

        MainInterface.MainGridView {
            id: artistGrid

            anchors.fill: parent
            topMargin: VLCStyle.margin_large
            delegateModel: selectionModel
            model: artistModel
            focus: true
            cellWidth: VLCStyle.colWidth(1)
            cellHeight: VLCStyle.gridItem_music_height

            Navigation.parentItem: root
            Navigation.cancelAction: root._onNavigationCancel

            onSelectAll: selectionModel.selectAll()
            onSelectionUpdated: selectionModel.updateSelection( keyModifiers, oldIndex, newIndex )
            onActionAtIndex: {
                if (selectionModel.selectedIndexes.length > 1) {
                    medialib.addAndPlay( artistModel.getIdsForIndexes( selectionModel.selectedIndexes ) )
                } else {
                    view.currentItem.currentIndex = index
                    requestArtistAlbumView()
                    medialib.addAndPlay( artistModel.getIdForIndex(index) )
                }
            }

            Widgets.GridShadows {
                id: shadows

                leftPadding: (VLCStyle.colWidth(1) - shadows.coverWidth) / 2 // GridItem's rect is horizontally centered
                coverWidth: VLCStyle.artistGridCover_radius
                coverHeight: VLCStyle.artistGridCover_radius
                coverRadius: VLCStyle.artistGridCover_radius
            }

            delegate: AudioGridItem {
                id: gridItem

                title: model.name || i18n.qtr("Unknown artist")
                subtitle: model.nb_tracks > 1 ? i18n.qtr("%1 songs").arg(model.nb_tracks) : i18n.qtr("%1 song").arg(model.nb_tracks)
                pictureRadius: VLCStyle.artistGridCover_radius
                pictureHeight: VLCStyle.artistGridCover_radius
                pictureWidth: VLCStyle.artistGridCover_radius
                playCoverBorderWidth: VLCStyle.dp(3, VLCStyle.scale)
                titleMargin: VLCStyle.margin_xlarge
                playIconSize: VLCStyle.play_cover_small
                textAlignHCenter: true
                width: VLCStyle.colWidth(1)
                dragItem: artistsDragItem
                unselectedUnderlay: shadows.unselected
                selectedUnderlay: shadows.selected


                onItemClicked: artistGrid.leftClickOnItem(modifier, index)

                onItemDoubleClicked: root.requestArtistAlbumView(model)

                onContextMenuButtonClicked: {
                    artistGrid.rightClickOnItem(index)
                    contextMenu.popup(selectionModel.selectedIndexes, globalMousePos)
                }
            }
        }
    }


    Component {
        id: tableComponent

        MainInterface.MainTableView {
            id: artistTable

            readonly property int _nbCols: VLCStyle.gridColumnsForWidth(artistTable.availableRowWidth)

            anchors.fill: parent
            selectionDelegateModel: selectionModel
            model: artistModel
            focus: true
            headerColor: VLCStyle.colors.bg
            dragItem: artistsDragItem
            rowHeight: VLCStyle.tableCoverRow_height
            headerTopPadding: VLCStyle.margin_normal

            Navigation.parentItem: root
            Navigation.cancelAction: root._onNavigationCancel

            onActionForSelection: {
                if (selection.length > 1) {
                    medialib.addAndPlay( artistModel.getIdsForIndexes( selection ) )
                } else if ( selection.length === 1) {
                    requestArtistAlbumView()
                    medialib.addAndPlay( artistModel.getIdForIndex( selection[0] ) )
                }
            }

            sortModel:  [
                { isPrimary: true, criteria: "name", width: VLCStyle.colWidth(Math.max(artistTable._nbCols - 1, 1)), text: i18n.qtr("Name"), headerDelegate: tableColumns.titleHeaderDelegate, colDelegate: tableColumns.titleDelegate },
                { criteria: "nb_tracks", width: VLCStyle.colWidth(1), text: i18n.qtr("Tracks") }
            ]

            onItemDoubleClicked: {
                root.requestArtistAlbumView(model)
            }
            onContextMenuButtonClicked: contextMenu.popup(selectionModel.selectedIndexes, menuParent.mapToGlobal(0,0))
            onRightClick: contextMenu.popup(selectionModel.selectedIndexes, globalMousePos)

            Widgets.TableColumns {
                id: tableColumns
            }
        }
    }

    Widgets.StackViewExt {
        id: view

        anchors.fill: parent
        visible: artistModel.count > 0
        focus: artistModel.count > 0
        initialItem: mainInterface.gridView ? gridComponent : tableComponent
    }

    Connections {
        target: mainInterface
        onGridViewChanged: {
            if (mainInterface.gridView) {
                view.replace(gridComponent)
            } else {
                view.replace(tableComponent)
            }
        }
    }

    EmptyLabel {
        anchors.fill: parent
        visible: artistModel.count === 0
        focus: artistModel.count === 0
        text: i18n.qtr("No artists found\nPlease try adding sources, by going to the Network tab")
        Navigation.parentItem: root
        cover: VLCStyle.noArtArtistCover
    }
}
