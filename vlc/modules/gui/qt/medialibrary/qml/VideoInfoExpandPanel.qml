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
import QtQml.Models 2.11
import QtQuick.Layouts 1.3

import org.videolan.medialib 0.1
import org.videolan.controls 0.1

import org.videolan.vlc 0.1

import "qrc:///widgets/" as Widgets
import "qrc:///util/Helpers.js" as Helpers
import "qrc:///style/"

FocusScope {
    id: expandRect

    property int currentId: -1
    property var model : ({})
    property bool _showMoreInfo: false
    signal retract()

    implicitHeight: contentRect.implicitHeight

    Rectangle{
        id: contentRect

        implicitHeight: contentLayout.implicitHeight + ( VLCStyle.margin_normal * 2 )
        width: parent.width
        color: VLCStyle.colors.bgAlt

        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            color: VLCStyle.colors.buttonBorder
            height: VLCStyle.expandDelegate_border
        }

        Rectangle {
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }
            color: VLCStyle.colors.buttonBorder
            height: VLCStyle.expandDelegate_border
        }

        RowLayout {
            id: contentLayout

            anchors.fill: parent
            anchors.margins: VLCStyle.margin_normal
            implicitHeight: artAndControl.implicitHeight
            spacing: VLCStyle.margin_normal

            FocusScope {
                id: artAndControl

                focus: true

                implicitHeight: artAndControlLayout.implicitHeight
                implicitWidth: artAndControlLayout.implicitWidth

                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                Layout.alignment: Qt.AlignTop

                Column {
                    id: artAndControlLayout

                    spacing: VLCStyle.margin_normal

                    Item {
                        height: VLCStyle.gridCover_video_height
                        width: VLCStyle.gridCover_video_width

                        /* A bigger cover for the album */
                        RoundImage {
                            id: expand_cover_id

                            anchors.fill: parent
                            source: model.thumbnail || VLCStyle.noArtCover
                            radius: VLCStyle.gridCover_radius
                        }

                        Widgets.ListCoverShadow {
                            anchors.fill: expand_cover_id
                            source: expand_cover_id
                        }
                    }

                    Widgets.NavigableRow {
                        id: actionButtons

                        focus: true
                        spacing: VLCStyle.margin_large

                        model: ObjectModel {
                            Widgets.ActionButtonPrimary {
                                id: playActionBtn

                                iconTxt: VLCIcons.play_outline
                                text: i18n.qtr("Play")
                                onClicked: medialib.addAndPlay( model.id )
                            }

                            Widgets.TabButtonExt {
                                id: enqueueActionBtn

                                iconTxt: VLCIcons.enqueue
                                text: i18n.qtr("Enqueue")
                                onClicked: medialib.addToPlaylist( model.id )
                            }
                        }

                        Navigation.parentItem: expandRect
                    }
                }
            }


            Column {
                id: expand_infos_id

                spacing: 0
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop

                RowLayout {
                    width: parent.width

                    Widgets.SubtitleLabel {
                        text: model.title || i18n.qtr("Unknown title")

                        Layout.fillWidth: true
                    }

                    Widgets.IconLabel {
                        text: VLCIcons.close

                        MouseArea {
                            anchors.fill: parent
                            onClicked: expandRect.retract()
                        }
                    }
                }

                Widgets.CaptionLabel {
                    text: Helpers.msToString(model.duration)
                    color: VLCStyle.colors.text
                    width: parent.width
                }

                Row {
                    width: parent.width
                    topPadding: VLCStyle.margin_normal
                    spacing: VLCStyle.margin_xlarge

                    Column {
                        width: audioTrackInfo.visible ? expand_infos_id.width / 2 : expand_infos_id.width

                        Widgets.MenuCaption {
                            text: "<b>" + i18n.qtr("File Name:") + "</b> " + expandRect.model.title
                            width: parent.width
                        }

                        Widgets.MenuCaption {
                            text: "<b>" + i18n.qtr("Path:") + "</b> " + expandRect.model.display_mrl
                            topPadding: VLCStyle.margin_xsmall
                            width: parent.width
                        }

                        MouseArea {
                            width: childrenRect.width
                            height: childrenRect.height

                            onClicked: _showMoreInfo = !_showMoreInfo

                            Row {
                                topPadding: VLCStyle.margin_large
                                spacing: VLCStyle.margin_xsmall

                                Widgets.IconLabel {
                                    text: VLCIcons.back
                                    rotation: _showMoreInfo ? 270 : 90

                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: VLCStyle.duration_faster
                                        }
                                    }
                                }

                                Widgets.CaptionLabel {
                                    text: _showMoreInfo ? i18n.qtr("View Less") : i18n.qtr("View More")
                                    color: VLCStyle.colors.text
                                }
                            }
                        }

                        Column {
                            topPadding: VLCStyle.margin_xxlarge
                            visible: _showMoreInfo && expandRect.model.videoDesc.length > 0
                            opacity: visible ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: VLCStyle.duration_faster
                                }
                            }

                            Widgets.MenuCaption {
                                text: i18n.qtr("Video track:")
                                font.bold: true
                                bottomPadding: VLCStyle.margin_small
                            }

                            Repeater {
                                model: expandRect.model.videoDesc

                                delegate: Repeater {
                                    model: [
                                        {text: i18n.qtr("Codec:"), data: modelData.codec },
                                        {text: i18n.qtr("Language:"), data: modelData.language },
                                        {text: i18n.qtr("FPS:"), data: modelData.fps }
                                    ]

                                    delegate: Widgets.MenuCaption {
                                        text: modelData.text + " " + modelData.data
                                        bottomPadding: VLCStyle.margin_xsmall
                                    }

                                }
                            }
                        }
                    }

                    Column {
                        id: audioTrackInfo

                        visible: _showMoreInfo && expandRect.model.audioDesc.length > 0
                        opacity: visible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: VLCStyle.duration_faster
                            }
                        }

                        Widgets.MenuCaption {
                            text: i18n.qtr("Audio track:")
                            font.bold: true
                            bottomPadding: VLCStyle.margin_small
                        }

                        Repeater {
                            model: expandRect.model.audioDesc

                            delegate: Repeater {
                                model: [
                                    {text: i18n.qtr("Codec:"), data: modelData.codec },
                                    {text: i18n.qtr("Language:"), data: modelData.language },
                                    {text: i18n.qtr("Channel:"), data: modelData.nbchannels }
                                ]

                                delegate: Widgets.MenuCaption {
                                    text: modelData.text + " " + modelData.data
                                    bottomPadding: VLCStyle.margin_xsmall
                                }
                            }
                        }

                    }
                }
            }
        }
    }
}
