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
import QtQuick.Layouts 1.3
import QtQml 2.11
import QtGraphicalEffects 1.0

import org.videolan.vlc 0.1

import "qrc:///util/" as Util
import "qrc:///widgets/" as Widgets
import "qrc:///main/" as MainInterface
import "qrc:///style/"

FocusScope {
    id: root

    property alias model: filterModel
    property var providerModel
    property var contextMenu
    property var tree
    onTreeChanged: providerModel.tree = tree
    readonly property var currentIndex: view.currentItem.currentIndex
    //the index to "go to" when the view is loaded
    property var initialIndex: 0
    property var sortModel: [
        { text: i18n.qtr("Alphabetic"), criteria: "name"},
        { text: i18n.qtr("Url"), criteria: "mrl" }
    ]

    function changeTree(new_tree) {
        history.push(["mc", "network", { tree: new_tree }]);
    }

    function playSelected() {
        providerModel.addAndPlay(filterModel.mapIndexesToSource(selectionModel.selectedIndexes))
    }

    function playAt(index) {
        providerModel.addAndPlay(filterModel.mapIndexToSource(index))
    }

    Util.SelectableDelegateModel{
        id: selectionModel

        model: filterModel
    }

    SortFilterProxyModel {
        id: filterModel

        sourceModel: providerModel
        searchRole: "name"
    }

    Widgets.DragItem {
        id: networkDragItem

        function updateComponents(maxCovers) {
          var items = selectionModel.selectedIndexes.slice(0, maxCovers).map(function (x){
            return filterModel.getDataAt(x.row)
          })
          var title = items.map(function (item){ return item.name || i18n.qtr("Unknown share")}).join(", ")
          var covers = items.map(function (item) { return {artwork: item.artwork, cover: custom_cover, type: item.type}})
          return {
            covers: covers,
            title: title,
            count: selectionModel.selectedIndexes.length
          }
        }

        function getSelectedInputItem() {
            return providerModel.getItemsForIndexes(selectionModel.selectedIndexes);
        }

        Component {
            id: custom_cover

            NetworkCustomCover {
                networkModel: model
                iconSize: networkDragItem.coverSize / 2
                width: networkDragItem.coverSize / 2
                height: networkDragItem.coverSize / 2
            }
        }
    }

    function resetFocus() {
        var initialIndex = root.initialIndex
        if (initialIndex >= filterModel.count)
            initialIndex = 0
        selectionModel.select(filterModel.index(initialIndex, 0), ItemSelectionModel.ClearAndSelect)
        if (view.currentItem) {
            view.currentItem.currentIndex = initialIndex
            view.currentItem.positionViewAtIndex(initialIndex, ItemView.Contain)
        }
    }


    function _actionAtIndex(index) {
        if ( selectionModel.selectedIndexes.length > 1 ) {
            playSelected()
        } else {
            var data = filterModel.getDataAt(index)
            if (data.type === NetworkMediaModel.TYPE_DIRECTORY
                    || data.type === NetworkMediaModel.TYPE_NODE)  {
                changeTree(data.tree)
            } else {
                playAt(index)
            }
        }
    }

    Component{
        id: gridComponent

        MainInterface.MainGridView {
            id: gridView

            delegateModel: selectionModel
            model: filterModel

            headerDelegate: FocusScope {
                id: headerId

                width: view.width
                height: layout.implicitHeight + VLCStyle.margin_large + VLCStyle.margin_normal

                Navigation.navigable: btn.visible
                Navigation.parentItem: root
                Navigation.downAction: function() {
                    focus = false
                    gridView.forceActiveFocus()
                }

                RowLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.topMargin: VLCStyle.margin_large
                    anchors.bottomMargin: VLCStyle.margin_normal
                    anchors.rightMargin: VLCStyle.margin_small

                    Widgets.SubtitleLabel {
                        text: providerModel.name
                        leftPadding: gridView.rowX

                        Layout.fillWidth: true
                    }

                    Widgets.TabButtonExt {
                        id: btn

                        focus: true
                        iconTxt: providerModel.indexed ? VLCIcons.remove : VLCIcons.add
                        text:  providerModel.indexed ?  i18n.qtr("Remove from medialibrary") : i18n.qtr("Add to medialibrary")
                        visible: !providerModel.is_on_provider_list && !!providerModel.canBeIndexed
                        onClicked: providerModel.indexed = !providerModel.indexed

                        Layout.preferredWidth: implicitWidth

                        Navigation.parentItem: headerId
                    }
                }
            }

            cellWidth: VLCStyle.gridItem_network_width
            cellHeight: VLCStyle.gridCover_network_height + VLCStyle.margin_xsmall + VLCStyle.fontHeight_normal

            delegate: NetworkGridItem {
                id: delegateGrid

                property var model: ({})
                property int index: -1

                subtitle: ""
                height: VLCStyle.gridCover_network_height + VLCStyle.margin_xsmall + VLCStyle.fontHeight_normal
                dragItem: networkDragItem
                unselectedUnderlay: shadows.unselected
                selectedUnderlay: shadows.selected

                onPlayClicked: playAt(index)
                onItemClicked : gridView.leftClickOnItem(modifier, index)

                onItemDoubleClicked: {
                    if (model.type === NetworkMediaModel.TYPE_NODE || model.type === NetworkMediaModel.TYPE_DIRECTORY)
                        changeTree(model.tree)
                    else
                        playAt(index)
                }

                onContextMenuButtonClicked: {
                    gridView.rightClickOnItem(index)
                    contextMenu.popup(filterModel.mapIndexesToSource(selectionModel.selectedIndexes), globalMousePos)
                }
            }

            onSelectAll: selectionModel.selectAll()
            onSelectionUpdated: selectionModel.updateSelection( keyModifiers, oldIndex, newIndex )
            onActionAtIndex: _actionAtIndex(index)

            Navigation.parentItem: root
            Navigation.upItem: gridView.headerItem
            Navigation.cancelAction: function() {
                history.previous()
            }

            Widgets.GridShadows {
                id: shadows

                coverWidth: VLCStyle.gridCover_network_width
                coverHeight: VLCStyle.gridCover_network_height
            }
        }
    }

    Component{
        id: tableComponent

        MainInterface.MainTableView {
            id: tableView

            readonly property int _nbCols: VLCStyle.gridColumnsForWidth(tableView.availableRowWidth)
            readonly property int _nameColSpan: Math.max((_nbCols - 1) / 2, 1)
            property Component thumbnailHeader: Item {
                Widgets.IconLabel {
                    height: VLCStyle.listAlbumCover_height
                    width: VLCStyle.listAlbumCover_width
                    horizontalAlignment: Text.AlignHCenter
                    text: VLCIcons.album_cover
                    color: VLCStyle.colors.caption
                }
            }

            property Component thumbnailColumn: NetworkThumbnailItem {
                onPlayClicked: playAt(index)
            }

            dragItem: networkDragItem
            height: view.height
            width: view.width
            model: filterModel
            selectionDelegateModel: selectionModel
            focus: true
            headerColor: VLCStyle.colors.bg
            Navigation.parentItem: root
            Navigation.upItem: tableView.headerItem
            Navigation.cancelAction: function() {
                history.previous()
            }

            rowHeight: VLCStyle.tableCoverRow_height

            header: FocusScope {
                id: head

                width: view.width
                height: layout.implicitHeight + VLCStyle.margin_large + VLCStyle.margin_small

                Navigation.navigable: btn.visible

                RowLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.topMargin: VLCStyle.margin_large
                    anchors.bottomMargin: VLCStyle.margin_small
                    anchors.rightMargin: VLCStyle.margin_small

                    Widgets.SubtitleLabel {
                        text: providerModel.name
                        leftPadding: VLCStyle.margin_large

                        Layout.fillWidth: true
                    }

                    Widgets.TabButtonExt {
                        id: btn

                        focus: true
                        iconTxt: providerModel.indexed ? VLCIcons.remove : VLCIcons.add
                        text:  providerModel.indexed ?  i18n.qtr("Remove from medialibrary") : i18n.qtr("Add to medialibrary")
                        visible: !providerModel.is_on_provider_list && !!providerModel.canBeIndexed
                        onClicked: providerModel.indexed = !providerModel.indexed

                        Navigation.parentItem: root
                        Navigation.downAction: function() {
                            head.focus = false
                            tableView.forceActiveFocus()
                        }

                        Layout.preferredWidth: implicitWidth
                    }
                }
            }

            sortModel: [
                { criteria: "thumbnail", width: VLCStyle.colWidth(1), headerDelegate: tableView.thumbnailHeader, colDelegate: tableView.thumbnailColumn },
                { isPrimary: true, criteria: "name", width: VLCStyle.colWidth(tableView._nameColSpan), text: i18n.qtr("Name") },
                { criteria: "mrl", width: VLCStyle.colWidth(Math.max(tableView._nbCols - tableView._nameColSpan - 1), 1), text: i18n.qtr("Url"), showContextButton: true },
            ]

            onActionForSelection: _actionAtIndex(selection[0].row)
            onItemDoubleClicked: _actionAtIndex(index)
            onContextMenuButtonClicked: contextMenu.popup(filterModel.mapIndexesToSource(selectionModel.selectedIndexes), menuParent.mapToGlobal(0,0))
            onRightClick: contextMenu.popup(filterModel.mapIndexesToSource(selectionModel.selectedIndexes), globalMousePos)
        }
    }

    Widgets.StackViewExt {
        id: view

        anchors.fill:parent
        focus: true
        initialItem: mainInterface.gridView ? gridComponent : tableComponent

        Connections {
            target: mainInterface
            onGridViewChanged: {
                if (mainInterface.gridView)
                    view.replace(gridComponent)
                else
                    view.replace(tableComponent)
            }
        }

        Widgets.BusyIndicatorExt {
            runningDelayed: providerModel.parsingPending
            anchors.centerIn: parent
            z: 1
        }
    }
}
