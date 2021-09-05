/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
 *
 * Authors: Benjamin Arnaud <bunjee@omega.gg>
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

import QtQuick      2.11
import QtQml.Models 2.11

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

    property int initialIndex: 0

    property var sortModel: [
        { text: i18n.qtr("Alphabetic"), criteria: "name" },
        { text: i18n.qtr("Date"),       criteria: "date" }
    ]

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

    //---------------------------------------------------------------------------------------------
    // Functions
    //---------------------------------------------------------------------------------------------

    function setCurrentItemFocus() { listView.currentItem.forceActiveFocus() }

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
            g_mainDisplay.play(medialib, model.getIdsForIndexes(modelSelect.selectedIndexes));
        } else if (modelSelect.selectedIndexes.length === 1) {
            var index = modelSelect.selectedIndexes[0];
            _showList(model.getDataAt(index));
        }
    }

    function _showList(model)
    {
        // NOTE: If the count is 1 we consider the group is a media.
        if (model.count == 1)
            g_mainDisplay.play(medialib, model.id);
        else
            showList(model);
    }

    function _onNavigationCancel() {
        if (root.currentItem.currentIndex > 0) {
            root.currentItem.currentIndex = 0;

            root.currentItem.positionViewAtIndex(0, ItemView.Contain);
        } else {
            root.Navigation.defaultNavigationCancel();
        }
    }

    function _getLabels(model, string)
    {
        var count = model.count;

        if (count === 1) {
            return [
                model.resolution_name || "",
                model.channel         || ""
            ].filter(function(a) { return a !== "" });
        } else {
            if (count < 100)
                return [ string.arg(count) ];
            else
                return [ string.arg("99+") ];
        }
    }

    //---------------------------------------------------------------------------------------------
    // Childs
    //---------------------------------------------------------------------------------------------

    MLGroupListModel {
        id: model

        ml: medialib

        onCountChanged: {
            if (count === 0 || modelSelect.hasSelection) return;

            resetFocus();
        }
    }

    Util.SelectableDelegateModel {
        id: modelSelect

        model: root.model
    }

    Widgets.StackViewExt {
        id: view

        anchors.fill: parent

        initialItem: (mainInterface.gridView) ? grid : list

        focus: (model.count !== 0)
    }

    GroupListContextMenu {
        id: contextMenu

        model: root.model
    }

    Widgets.DragItem {
        id: dragItemGroup

        function updateComponents(maxCovers) {
            var items = modelSelect.selectedIndexes.slice(0, maxCovers).map(function (x){
                return model.getDataAt(x.row);
            })

            var covers = items.map(function (item) {
                return { artwork: item.thumbnail || VLCStyle.noArtCover }
            });

            var name = items.map(function (item) {
                return item.name
            }).join(", ");

            return {
                covers: covers,
                title: name,
                count: modelSelect.selectedIndexes.length
            }
        }

        function getSelectedInputItem() {
            return model.getItemsForIndexes(modelSelect.selectedIndexes);
        }
    }

    //---------------------------------------------------------------------------------------------
    // Components

    Component {
        id: grid

        MainInterface.MainGridView {
            id: gridView

            //-------------------------------------------------------------------------------------
            // Settings

            cellWidth : VLCStyle.gridItem_video_width
            cellHeight: VLCStyle.gridItem_video_height

            topMargin: VLCStyle.margin_large

            model: root.model

            delegateModel: modelSelect

            activeFocusOnTab: true

            Navigation.parentItem: root
            //cancelAction takes a *function* pass it directly
            Navigation.cancelAction: root._onNavigationCancel

            expandDelegate: VideoInfoExpandPanel {
                width: gridView.width

                x: 0

                Navigation.parentItem: gridView

                Navigation.upAction    : function() { gridView.retract() }
                Navigation.downAction  : function() { gridView.retract() }
                Navigation.cancelAction: function() { gridView.retract() }

                onRetract: gridView.retract()
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

                title: (model.name) ? model.name
                                    : i18n.qtr("Unknown title")

                labels: _getLabels(model, i18n.qtr("%1 Videos"))

                // NOTE: We don't want to show the indicator for a group.
                showNewIndicator: (model.count === 1)

                dragItem: dragItemGroup

                selectedUnderlay  : shadows.selected
                unselectedUnderlay: shadows.unselected

                //---------------------------------------------------------------------------------
                // Events

                onItemClicked: gridView.leftClickOnItem(modifier, index)

                onItemDoubleClicked: _showList(model)

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

                // FIXME: We need to implement this in qml_menu_wrapper.
                //onShowMediaInformation: gridView.switchExpandItem(index)
            }

            //-------------------------------------------------------------------------------------
            // Childs

            Widgets.GridShadows {
                id: shadows

                coverWidth : VLCStyle.gridCover_video_width
                coverHeight: VLCStyle.gridCover_video_height
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

            mainCriteria: "name"

            selectionDelegateModel: modelSelect

            dragItem: dragItemGroup

            headerTopPadding: VLCStyle.margin_normal

            headerPositioning: ListView.InlineHeader

            Navigation.parentItem: root
            //cancelAction takes a *function* pass it directly
            Navigation.cancelAction: root._onNavigationCancel

            //-------------------------------------------------------------------------------------
            // Events

            onActionForSelection: _actionAtIndex()

            onContextMenuButtonClicked: contextMenu.popup(modelSelect.selectedIndexes,
                                                          menuParent.mapToGlobal(0,0))

            onRightClick: contextMenu.popup(modelSelect.selectedIndexes, globalMousePos)

            //-------------------------------------------------------------------------------------
            // Functions

            function onLabels(model) {
                return _getLabels(model, "%1");
            }
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
