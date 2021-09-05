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

    readonly property bool isViewMultiView: false

    readonly property int currentIndex: currentItem.currentIndex

    property int     initialIndex: 0
    property variant initialId
    property string  initialName

    // NOTE: Specify an optionnal header for the view.
    property Component header: undefined

    property Item headerItem: (currentItem) ? currentItem.headerItem : undefined

    //---------------------------------------------------------------------------------------------
    // Aliases
    //---------------------------------------------------------------------------------------------

    // NOTE: This is used to determine which media(s) shall be displayed.
    property alias parentId: model.parentId

    // NOTE: The name of the playlist.
    property alias name: label.text

    property alias model: model

    property alias currentItem: view

    property alias dragItem: dragItem

    //---------------------------------------------------------------------------------------------
    // Events
    //---------------------------------------------------------------------------------------------

    onModelChanged: resetFocus()

    onInitialIndexChanged: resetFocus()

    //---------------------------------------------------------------------------------------------
    // Functions
    //---------------------------------------------------------------------------------------------

    function setCurrentItemFocus() { view.currentItem.forceActiveFocus() }

    function resetFocus() {
        if (model.count === 0) return

        var initialIndex = root.initialIndex

        if (initialIndex >= model.count)
            initialIndex = 0

        modelSelect.select(model.index(initialIndex, 0), ItemSelectionModel.ClearAndSelect);

        if (currentItem)
            currentItem.positionViewAtIndex(initialIndex, ItemView.Contain);
    }

    //---------------------------------------------------------------------------------------------
    // Events

    function onDelete()
    {
        var indexes = modelSelect.selectedIndexes;

        if (indexes.length === 0)
            return;

        model.remove(indexes);
    }

    //---------------------------------------------------------------------------------------------
    // Childs
    //---------------------------------------------------------------------------------------------

    MLPlaylistModel {
        id: model

        ml: medialib

        parentId: initialId

        onCountChanged: {
            // NOTE: We need to cancel the Drag item manually when resetting. Should this be called
            //       from 'onModelReset' only ?
            dragItem.Drag.cancel();

            if (count === 0 || modelSelect.hasSelection) return;

            resetFocus();
        }
    }

    Widgets.SubtitleLabel {
        id: label

        anchors.top: parent.top

        anchors.topMargin: VLCStyle.margin_normal

        width: root.width

        leftPadding  : VLCStyle.margin_xlarge
        bottomPadding: VLCStyle.margin_xsmall

        text: initialName
    }

    Widgets.DragItem {
        id: dragItem

        function updateComponents(maxCovers) {
            var items = modelSelect.selectedIndexes.slice(0, maxCovers).map(function (x){
                return model.getDataAt(x.row);
            })

            var covers = items.map(function (item) {
                return { artwork: item.thumbnail || VLCStyle.noArtCover }
            });

            var title = items.map(function (item) {
                return item.title
            }).join(", ");

            return {
                covers: covers,
                title: title,
                count: modelSelect.selectedIndexes.length
            }
        }

        function getSelectedInputItem() {
            return model.getItemsForIndexes(modelSelect.selectedIndexes);
        }
    }

    Util.SelectableDelegateModel {
        id: modelSelect

        model: root.model
    }

    PlaylistMediaContextMenu {
        id: contextMenu

        model: root.model
    }

    PlaylistMedia
    {
        id: view

        //-----------------------------------------------------------------------------------------
        // Settings

        anchors.left  : parent.left
        anchors.right : parent.right
        anchors.top   : label.bottom
        anchors.bottom: parent.bottom

        clip: true

        focus: (model.count !== 0)

        model: root.model

        selectionDelegateModel: modelSelect

        dragItem: root.dragItem

        header: root.header

        headerTopPadding: VLCStyle.margin_normal

        headerPositioning: ListView.InlineHeader

        Navigation.parentItem: root
        Navigation.upItem: (headerItem) ? headerItem.focus : null
        Navigation.cancelAction: function () {
            if (view.currentIndex <= 0) {
                root.Navigation.defaultNavigationCancel()
            } else {
                view.currentIndex = 0;
                view.positionViewAtIndex(0, ItemView.Contain);
            }
        }

        //-----------------------------------------------------------------------------------------
        // Events

        onContextMenuButtonClicked: contextMenu.popup(modelSelect.selectedIndexes,
                                                      menuParent.mapToGlobal(0,0))

        onRightClick: contextMenu.popup(modelSelect.selectedIndexes, globalMousePos)

        Keys.onDeletePressed: onDelete()
    }

    EmptyLabel {
        anchors.fill: parent

        visible: (model.count === 0)

        focus: visible

        text: i18n.qtr("No media found")

        cover: VLCStyle.noArtAlbumCover

        Navigation.parentItem: root
    }
}
