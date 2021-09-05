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

import QtQuick          2.11
import QtQuick.Controls 2.4
import QtQuick.Layouts  1.3
import QtQml.Models     2.2

import org.videolan.medialib 0.1
import org.videolan.vlc 0.1

import "qrc:///widgets/" as Widgets
import "qrc:///main/"    as MainInterface
import "qrc:///util/"    as Util
import "qrc:///style/"

FocusScope {
    id: root

    //---------------------------------------------------------------------------------------------
    // Properties
    //---------------------------------------------------------------------------------------------

    readonly property int currentIndex: currentItem.currentIndex

    property bool isMusic: false

    property int initialIndex: 0

    property var sortModel: [{ text: i18n.qtr("Alphabetic"), criteria: "title" }]

    //---------------------------------------------------------------------------------------------
    // Private

    property int _width: (isMusic) ? VLCStyle.gridItem_music_width
                                   : VLCStyle.gridItem_video_width

    property int _height: (isMusic) ? VLCStyle.gridItem_music_height
                                    : VLCStyle.gridItem_video_height

    property int _widthCover: (isMusic) ? VLCStyle.gridCover_music_width
                                        : VLCStyle.gridCover_video_width

    property int _heightCover: (isMusic) ? VLCStyle.gridCover_music_height
                                         : VLCStyle.gridCover_video_height

    //---------------------------------------------------------------------------------------------
    // Alias
    //---------------------------------------------------------------------------------------------

    property alias model: model

    property alias currentItem: view.currentItem

    //---------------------------------------------------------------------------------------------
    // Signals
    //---------------------------------------------------------------------------------------------

    signal showList(variant model)


    //---------------------------------------------------------------------------------------------
    // Events
    //---------------------------------------------------------------------------------------------

    // NOTE: Define the initial position and selection. This is done on activeFocus rather than
    //       Component.onCompleted because modelSelect.selectedGroup update itself after this
    //       event.
    onActiveFocusChanged: {
        if (activeFocus == false || model.count === 0 || modelSelect.hasSelection) return;

        var initialIndex = 0;

        if (currentItem.currentIndex !== -1) {
            initialIndex = currentItem.currentIndex;
        }

        modelSelect.select(model.index(initialIndex, 0), ItemSelectionModel.ClearAndSelect);

        currentItem.currentIndex = initialIndex;
    }

    onInitialIndexChanged: resetFocus()

    //---------------------------------------------------------------------------------------------
    // Connections
    //---------------------------------------------------------------------------------------------

    Connections {
        target: mainInterface

        onGridViewChanged: {
            if (mainInterface.gridView) view.replace(grid);
            else                        view.replace(table);
        }
    }

    //---------------------------------------------------------------------------------------------
    // Functions
    //---------------------------------------------------------------------------------------------

    function resetFocus() {
        if (model.count === 0) return;

        var initialIndex = root.initialIndex;

        if (initialIndex >= model.count)
            initialIndex = 0;

        modelSelect.select(model.index(initialIndex, 0), ItemSelectionModel.ClearAndSelect);

        if (currentItem)
            currentItem.positionViewAtIndex(initialIndex, ItemView.Contain);
    }

    //---------------------------------------------------------------------------------------------
    // Private

    function _actionAtIndex() {
        if (modelSelect.selectedIndexes.length > 1) {
            medialib.addAndPlay(model.getIdsForIndexes(modelSelect.selectedIndexes));
        } else if (modelSelect.selectedIndexes.length === 1) {
            var index = modelSelect.selectedIndexes[0];
            showList(model.getDataAt(index));
        }
    }

    function _getCount(model)
    {
        var count = model.count;

        if (count < 100)
            return count;
        else
            return i18n.qtr("99+");
    }

    function _onNavigationCancel() {
        if (root.currentItem.currentIndex <= 0) {
            root.Navigation.defaultNavigationCancel()
        } else {
            root.currentItem.currentIndex = 0;
            root.currentItem.positionViewAtIndex(0, ItemView.Contain);
        }
    }

    //---------------------------------------------------------------------------------------------
    // Childs
    //---------------------------------------------------------------------------------------------

    MLPlaylistListModel {
        id: model

        ml: medialib

        coverSize: (isMusic) ? Qt.size(512, 512)
                             : Qt.size(1024, 640)

        coverDefault: (isMusic) ? ":/noart_album.svg" : ":/noart_videoCover.svg"

        coverPrefix: (isMusic) ? "playlist-music" : "playlist-video"

        onCountChanged: {
            if (count === 0 || modelSelect.hasSelection) return;

            resetFocus();
        }
    }

    Widgets.StackViewExt {
        id: view

        anchors.fill: parent

        initialItem: (mainInterface.gridView) ? grid : table

        focus: (model.count !== 0)
    }

    Widgets.DragItem {
        id: dragItemPlaylist

        //---------------------------------------------------------------------------------------------
        // DragItem implementation

        function updateComponents(maxCovers) {
            var items = modelSelect.selectedIndexes.slice(0, maxCovers).map(function (x){
                return model.getDataAt(x.row);
            })

            var covers = items.map(function (item) {
                return { artwork: item.thumbnail || VLCStyle.noArtCover };
            })

            var title = items.map(function (item) {
                return item.name
            }).join(", ");

            return {
                covers: covers,
                title: title,
                count: modelSelect.selectedIndexes.length
            };
        }

        function getSelectedInputItem() {
            return model.getItemsForIndexes(modelSelect.selectedIndexes);
        }
    }

    Util.SelectableDelegateModel {
        id: modelSelect

        model: root.model
    }

    PlaylistListContextMenu {
        id: contextMenu

        model: root.model
    }

    // TBD: Refactor this with MusicGenres ?
    Component {
        id: grid

        MainInterface.MainGridView {
            id: gridView

            //-------------------------------------------------------------------------------------
            // Settings

            cellWidth : _width
            cellHeight: _height

            topMargin: VLCStyle.margin_large

            model: root.model

            delegateModel: modelSelect

            Navigation.parentItem: root

            Navigation.cancelAction: root._onNavigationCancel

            focus: true

            delegate: VideoGridItem {
                //---------------------------------------------------------------------------------
                // Properties

                property var model: ({})

                property int index: -1

                //---------------------------------------------------------------------------------
                // Settings

                pictureWidth : _widthCover
                pictureHeight: _heightCover

                title: (model.name) ? model.name
                                    : i18n.qtr("Unknown title")

                labels: (model.count > 1) ? [ i18n.qtr("%1 Tracks").arg(_getCount(model)) ]
                                          : [ i18n.qtr("%1 Track") .arg(_getCount(model)) ]

                // NOTE: We don't want to show the new indicator for a playlist.
                showNewIndicator: false

                dragItem: dragItemPlaylist

                selectedUnderlay  : shadows.selected
                unselectedUnderlay: shadows.unselected

                //---------------------------------------------------------------------------------
                // Events

                onItemClicked: gridView.leftClickOnItem(modifier, index)

                onItemDoubleClicked: showList(model)

                onPlayClicked: if (model.id) medialib.addAndPlay(model.id)

                onContextMenuButtonClicked: {
                    gridView.rightClickOnItem(index);

                    contextMenu.popup(modelSelect.selectedIndexes, globalMousePos);
                }

                //---------------------------------------------------------------------------------
                // Animations

                Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_faster } }
            }

            //-------------------------------------------------------------------------------------
            // Events

            // NOTE: Define the initial position and selection. This is done on activeFocus rather
            //       than Component.onCompleted because modelSelect.selectedGroup update itself
            //       after this event.
            onActiveFocusChanged: {
                if (activeFocus == false || model.count === 0 || modelSelect.hasSelection) return;

                modelSelect.select(model.index(0,0), ItemSelectionModel.ClearAndSelect)
            }

            onSelectAll: modelSelect.selectAll()

            onSelectionUpdated: modelSelect.updateSelection(keyModifiers, oldIndex, newIndex)

            onActionAtIndex: _actionAtIndex()

            //-------------------------------------------------------------------------------------
            // Childs

            Widgets.GridShadows {
                id: shadows

                coverWidth : _widthCover
                coverHeight: _heightCover
            }
        }
    }

    Component {
        id: table

        MainInterface.MainTableView {
            id: tableView

            //-------------------------------------------------------------------------------------
            // Properties

            property int _widthName:
                Math.max(VLCStyle.gridColumnsForWidth(tableView.availableRowWidth
                                                      - VLCStyle.listAlbumCover_width
                                                      - VLCStyle.column_margin_width) - 1, 1)

            //-------------------------------------------------------------------------------------
            // Settings

            rowHeight: VLCStyle.tableCoverRow_height

            headerTopPadding: VLCStyle.margin_normal

            model: root.model

            selectionDelegateModel: modelSelect

            dragItem: dragItemPlaylist

            focus: true

            headerColor: VLCStyle.colors.bg

            sortModel: [{
                isPrimary: true,
                criteria: "thumbnail",

                width: VLCStyle.listAlbumCover_width,

                headerDelegate: columns.titleHeaderDelegate,
                colDelegate   : columns.titleDelegate
            }, {
                criteria: "name",

                width: VLCStyle.colWidth(_widthName),

                text: i18n.qtr("Name")
            }, {
                criteria: "count",

                width: VLCStyle.colWidth(1),

                text: i18n.qtr("Tracks")
            }]

            Navigation.parentItem: root
            Navigation.cancelAction: root._onNavigationCancel

            //-------------------------------------------------------------------------------------
            // Events

            onActionForSelection: _actionAtIndex()

            onItemDoubleClicked: showList(model)

            onContextMenuButtonClicked: contextMenu.popup(modelSelect.selectedIndexes,
                                                          menuParent.mapToGlobal(0,0))

            onRightClick: contextMenu.popup(modelSelect.selectedIndexes, globalMousePos)

            //-------------------------------------------------------------------------------------
            // Childs

            Widgets.TableColumns {
                id: columns

                showTitleText: false

                //---------------------------------------------------------------------------------
                // NOTE: When it's music we want the cover to be square

                titleCover_width: (isMusic) ? VLCStyle.trackListAlbumCover_width
                                            : VLCStyle.listAlbumCover_width

                titleCover_height: (isMusic) ? VLCStyle.trackListAlbumCover_heigth
                                             : VLCStyle.listAlbumCover_height

                titleCover_radius: (isMusic) ? VLCStyle.trackListAlbumCover_radius
                                             : VLCStyle.listAlbumCover_radius

                //---------------------------------------------------------------------------------

                // NOTE: This makes sure we display the playlist count on the item.
                function titlecoverLabels(model) {
                    return [ _getCount(model) ];
                }
            }
        }
    }

    EmptyLabel {
        anchors.fill: parent

        visible: (model.count === 0)

        focus: visible

        text: i18n.qtr("No playlists found")

        cover: VLCStyle.noArtAlbumCover

        Navigation.parentItem: root
    }
}
