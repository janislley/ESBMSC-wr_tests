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

    // NOTE: Specify an optionnal header for the view.
    property Component header: undefined

    property Item headerItem: (currentItem) ? currentItem.headerItem : undefined

    readonly property int currentIndex: currentItem.currentIndex

    property int initialIndex: 0

    property var model: MLVideoModel { ml: medialib }

    property var sortModel: [
        { text: i18n.qtr("Alphabetic"), criteria: "title"          },
        { text: i18n.qtr("Duration"),   criteria: "duration" }
    ]

    //---------------------------------------------------------------------------------------------
    // Aliases
    //---------------------------------------------------------------------------------------------

    property alias currentItem: view.currentItem

    //---------------------------------------------------------------------------------------------

    property alias dragItem: dragItem

    //---------------------------------------------------------------------------------------------
    // Events
    //---------------------------------------------------------------------------------------------

    onModelChanged: resetFocus()

    onInitialIndexChanged: resetFocus()

    //---------------------------------------------------------------------------------------------
    // Connections
    //---------------------------------------------------------------------------------------------

    Connections {
        target: mainInterface

        onGridViewChanged: {
            if (mainInterface.gridView) view.replace(grid);
            else                        view.replace(list);
        }
    }

    Connections {
        target: model

        onCountChanged: {
            if (model.count === 0 || modelSelect.hasSelection) return;

            resetFocus();
        }
    }

    //---------------------------------------------------------------------------------------------
    // Functions
    //---------------------------------------------------------------------------------------------

    function setCurrentItemFocus() { listView.currentItem.forceActiveFocus() }

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
    // Private

    function _actionAtIndex() {
        g_mainDisplay.showPlayer();

        medialib.addAndPlay(model.getIdsForIndexes(modelSelect.selectedIndexes));
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

    Widgets.StackViewExt {
        id: view

        anchors.fill: parent

        initialItem: (mainInterface.gridView) ? grid : list

        focus: (model.count !== 0)
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

    VideoContextMenu {
        id: contextMenu

        model: root.model
    }

    Component {
        id: grid

        MainInterface.MainGridView {
            id: gridView

            //-------------------------------------------------------------------------------------
            // Properties

            property Item currentItem: Item{}

            //-------------------------------------------------------------------------------------
            // Settings

            cellWidth : VLCStyle.gridItem_video_width
            cellHeight: VLCStyle.gridItem_video_height

            model: root.model

            delegateModel: modelSelect

            headerDelegate: root.header

            activeFocusOnTab: true

            Navigation.parentItem: root
            Navigation.upItem: (headerItem) ? headerItem.focusItem : null
            //cancelAction takes a *function* pass it directly
            Navigation.cancelAction: root._onNavigationCancel

            expandDelegate: VideoInfoExpandPanel {
                width: gridView.width

                x: 0

                Navigation.parentItem: gridView

                Navigation.cancelAction: function() { gridView.retract() }
                Navigation.upAction    : function() { gridView.retract() }
                Navigation.downAction  : function() { gridView.retract() }

                onRetract: gridView.retract()
            }

            //---------------------------------------------------------------------------------
            // Shadows

            Widgets.GridShadows {
                id: shadows

                coverWidth: VLCStyle.gridCover_video_width
                coverHeight: VLCStyle.gridCover_video_height
            }

            delegate: VideoGridItem {
                id: gridItem

                //---------------------------------------------------------------------------------
                // properties required by ExpandGridView

                property var model: ({})
                property int index: -1

                //---------------------------------------------------------------------------------
                // Settings

                opacity: (gridView.expandIndex !== -1
                          &&
                          gridView.expandIndex !== gridItem.index) ? 0.7 : 1

                dragItem: root.dragItem
                unselectedUnderlay: shadows.unselected
                selectedUnderlay: shadows.selected

                //---------------------------------------------------------------------------------
                // Events

                onItemClicked: gridView.leftClickOnItem(modifier, index)

                onItemDoubleClicked: g_mainDisplay.play(medialib, model.id)

                onContextMenuButtonClicked: {
                    gridView.rightClickOnItem(index);

                    contextMenu.popup(modelSelect.selectedIndexes, globalMousePos,
                                      { "information" : index });
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
            // Connections

            Connections {
                target: contextMenu

                onShowMediaInformation: gridView.switchExpandItem(index)
            }
        }
    }

    Component {
        id: list

        VideoListDisplay
        {
            id: listView

            //-------------------------------------------------------------------------------------
            // Settings

            model: root.model

            selectionDelegateModel: modelSelect

            dragItem: root.dragItem

            header: root.header

            headerTopPadding: VLCStyle.margin_normal

            headerPositioning: ListView.InlineHeader

            Navigation.parentItem: root
            Navigation.upItem: (headerItem) ? headerItem.focus : null
            //cancelAction takes a *function* pass it directly
            Navigation.cancelAction: root._onNavigationCancel

            //-------------------------------------------------------------------------------------
            // Events

            onActionForSelection: _actionAtIndex()

            onItemDoubleClicked: g_mainDisplay.play(medialib, model.id)

            onContextMenuButtonClicked: contextMenu.popup(modelSelect.selectedIndexes,
                                                          menuParent.mapToGlobal(0,0))

            onRightClick: contextMenu.popup(modelSelect.selectedIndexes, globalMousePos)
        }
    }

    EmptyLabel {
        anchors.fill: parent

        coverWidth : VLCStyle.dp(182, VLCStyle.scale)
        coverHeight: VLCStyle.dp(114, VLCStyle.scale)

        visible: (model.count === 0)

        text: i18n.qtr("No video found\nPlease try adding sources, by going to the Network tab")

        cover: VLCStyle.noArtVideoCover

        Navigation.parentItem: root

        focus: visible
    }
}
