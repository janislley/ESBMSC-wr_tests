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

#if HAVE_CONFIG_H
# include "config.h"
#endif

#include "mlplaylistlistmodel.hpp"

// VLC includes
#include <vlc_media_library.h>
#include <qt.hpp>

// MediaLibrary includes
#include "mlhelper.hpp"
#include "mlplaylist.hpp"

//-------------------------------------------------------------------------------------------------
// Static variables

// NOTE: We multiply by 2 to cover most dpi settings.
static const int MLPLAYLISTMODEL_COVER_WIDTH  = 512 * 2; // 16 / 10 ratio
static const int MLPLAYLISTMODEL_COVER_HEIGHT = 320 * 2;

//=================================================================================================
// MLPlaylistListModel
//=================================================================================================

MLPlaylistListModel::MLPlaylistListModel(vlc_medialibrary_t * ml, QObject * parent)
    : MLBaseModel(parent)
    , m_coverDefault(":/noart_videoCover.svg")
{
    m_ml = ml;
}

/* explicit */ MLPlaylistListModel::MLPlaylistListModel(QObject * parent)
    : MLBaseModel(parent)
    , m_coverSize(MLPLAYLISTMODEL_COVER_WIDTH, MLPLAYLISTMODEL_COVER_HEIGHT) {}

//-------------------------------------------------------------------------------------------------

/* Q_INVOKABLE */ MLItemId MLPlaylistListModel::create(const QString & name)
{
    assert(m_ml);

    vlc_ml_playlist_t * playlist = vlc_ml_playlist_create(m_ml, qtu(name));

    if (playlist)
        return MLItemId(playlist->i_id, VLC_ML_PARENT_PLAYLIST);
    else
        return MLItemId();
}

/* Q_INVOKABLE */ bool MLPlaylistListModel::append(const MLItemId     & playlistId,
                                                   const QVariantList & ids)
{
    assert(m_ml);

    bool result = true;

    vlc_ml_query_params_t query;

    memset(&query, 0, sizeof(vlc_ml_query_params_t));

    for (const QVariant & id : ids)
    {
        if (id.canConvert<MLItemId>() == false)
        {
            result = false;

            continue;
        }

        const MLItemId & itemId = id.value<MLItemId>();

        if (itemId.id == 0)
        {
            result = false;

            continue;
        }

        // NOTE: When we have a parent it's a collection of media(s).
        if (itemId.type != VLC_ML_PARENT_UNKNOWN)
        {
            ml_unique_ptr<vlc_ml_media_list_t> list;

            list.reset(vlc_ml_list_media_of(m_ml, &query, itemId.type, itemId.id));

            if (list == nullptr)
            {
                result = false;

                continue;
            }

            for (const vlc_ml_media_t & media : ml_range_iterate<vlc_ml_media_t>(list))
            {
                if (vlc_ml_playlist_append(m_ml, playlistId.id, media.i_id) != VLC_SUCCESS)
                    result = false;
            }
        }
        // NOTE: Otherwise we add the media directly.
        else if (vlc_ml_playlist_append(m_ml, playlistId.id, itemId.id) != VLC_SUCCESS)
            result = false;
    }

    return result;
}

//-------------------------------------------------------------------------------------------------

/* Q_INVOKABLE */ bool MLPlaylistListModel::deletePlaylists(const QVariantList & ids)
{
    assert(m_ml);

    bool result = true;

    for (const QVariant & id : ids)
    {
        if (id.canConvert<MLItemId>() == false)
        {
            result = false;

            continue;
        }

        if (vlc_ml_playlist_delete(m_ml, id.value<MLItemId>().id) != VLC_SUCCESS)
            result = false;
    }

    return result;
}

//-------------------------------------------------------------------------------------------------

/* Q_INVOKABLE */ MLItemId MLPlaylistListModel::getItemId(int index) const
{
    if (index < 0 || index >= rowCount())
        return MLItemId();

    return item(index)->getId();
}

//-------------------------------------------------------------------------------------------------
// QAbstractItemModel implementation
//-------------------------------------------------------------------------------------------------

QHash<int, QByteArray> MLPlaylistListModel::roleNames() const /* override */
{
    return
    {
        { PLAYLIST_ID,        "id"        },
        { PLAYLIST_NAME,      "name"      },
        { PLAYLIST_THUMBNAIL, "thumbnail" },
        { PLAYLIST_DURATION,  "duration"  },
        { PLAYLIST_COUNT,     "count"     }
    };
}

QVariant MLPlaylistListModel::data(const QModelIndex & index, int role) const /* override */
{
    int row = index.row();

    MLPlaylist * playlist = static_cast<MLPlaylist *>(item(row));

    if (playlist == nullptr)
        return QVariant();

    switch (role)
    {
        // NOTE: This is the condition for QWidget view(s).
        case Qt::DisplayRole:
            if (index.column() == 0)
                return playlist->getName();
            else
                return QVariant();
        // NOTE: These are the conditions for QML view(s).
        case PLAYLIST_ID:
            return QVariant::fromValue(playlist->getId());
        case PLAYLIST_NAME:
            return playlist->getName();
        case PLAYLIST_THUMBNAIL:
            return getCover(playlist, row);
        case PLAYLIST_DURATION:
            return QVariant::fromValue(playlist->getDuration());
        case PLAYLIST_COUNT:
            return QVariant::fromValue(playlist->getCount());
        default:
            return QVariant();
    }
}

//-------------------------------------------------------------------------------------------------
// QAbstractItemModel reimplementation
//-------------------------------------------------------------------------------------------------

QVariant MLPlaylistListModel::headerData(int section, Qt::Orientation orientation,
                                         int role) const /* override */
{
    if (role != Qt::DisplayRole || orientation == Qt::Vertical)
        return QVariant();

    if (section == 0)
        return QVariant::fromValue(qtr("Name"));
    else
        return QVariant();
}

//-------------------------------------------------------------------------------------------------
// Protected MLBaseModel implementation
//-------------------------------------------------------------------------------------------------

vlc_ml_sorting_criteria_t MLPlaylistListModel::roleToCriteria(int role) const /* override */
{
    if (role == PLAYLIST_NAME)
        return VLC_ML_SORTING_ALPHA;
    else
        return VLC_ML_SORTING_DEFAULT;
}

ListCacheLoader<std::unique_ptr<MLItem>> * MLPlaylistListModel::createLoader() const /* override */
{
    return new Loader(*this);
}

//-------------------------------------------------------------------------------------------------
// Private functions
//-------------------------------------------------------------------------------------------------

QString MLPlaylistListModel::getCover(MLPlaylist * playlist, int index) const
{
    QString cover = playlist->getCover();

    // NOTE: Making sure we're not already generating a cover.
    if (cover.isNull() == false || playlist->hasGenerator())
        return cover;

    CoverGenerator * generator = new CoverGenerator(m_ml, playlist->getId(), index);

    generator->setSize(m_coverSize);

    generator->setDefaultThumbnail(m_coverDefault);

    generator->setPrefix(m_coverPrefix);

    // NOTE: We'll apply the new thumbnail once it's loaded.
    connect(generator, &CoverGenerator::result, this, &MLPlaylistListModel::onCover);

    generator->start(*QThreadPool::globalInstance());

    playlist->setGenerator(generator);

    return cover;
}

//-------------------------------------------------------------------------------------------------
// Private MLBaseModel reimplementation
//-------------------------------------------------------------------------------------------------

void MLPlaylistListModel::onVlcMlEvent(const MLEvent & event) /* override */
{
    int type = event.i_type;

    if (type == VLC_ML_EVENT_PLAYLIST_ADDED || type == VLC_ML_EVENT_PLAYLIST_UPDATED
        ||
        type == VLC_ML_EVENT_PLAYLIST_DELETED)
    {
        m_need_reset = true;

        // NOTE: Maybe we should call this from MLBaseModel ?
        emit resetRequested();
    }

    MLBaseModel::onVlcMlEvent(event);
}

void MLPlaylistListModel::thumbnailUpdated(int idx) /* override */
{
    QModelIndex index = this->index(idx);

    emit dataChanged(index, index, { PLAYLIST_THUMBNAIL });
}

//-------------------------------------------------------------------------------------------------
// Private slots
//-------------------------------------------------------------------------------------------------

void MLPlaylistListModel::onCover()
{
    CoverGenerator * generator = static_cast<CoverGenerator *> (sender());

    int index = generator->getIndex();

    // NOTE: We want to avoid calling 'MLBaseModel::item' for performance issues.
    MLItem * item = this->itemCache(index);

    // NOTE: When the item is no longer cached or has been moved we return right away.
    if (item == nullptr || item->getId() != generator->getId())
    {
        generator->deleteLater();

        return;
    }

    MLPlaylist * playlist = static_cast<MLPlaylist *> (item);

    playlist->setCover(generator->takeResult());

    playlist->setGenerator(nullptr);

    thumbnailUpdated(index);
}

//-------------------------------------------------------------------------------------------------
// Properties
//-------------------------------------------------------------------------------------------------

QSize MLPlaylistListModel::coverSize() const
{
    return m_coverSize;
}

void MLPlaylistListModel::setCoverSize(const QSize & size)
{
    if (m_coverSize == size)
        return;

    m_coverSize = size;

    emit coverSizeChanged();
}

QString MLPlaylistListModel::coverDefault() const
{
    return m_coverDefault;
}

void MLPlaylistListModel::setCoverDefault(const QString & fileName)
{
    if (m_coverDefault == fileName)
        return;

    m_coverDefault = fileName;

    emit coverDefaultChanged();
}

QString MLPlaylistListModel::coverPrefix() const
{
    return m_coverPrefix;
}

void MLPlaylistListModel::setCoverPrefix(const QString & prefix)
{
    if (m_coverPrefix == prefix)
        return;

    m_coverPrefix = prefix;

    emit coverPrefixChanged();
}

//=================================================================================================
// Loader
//=================================================================================================

MLPlaylistListModel::Loader::Loader(const MLPlaylistListModel & model)
    : MLBaseModel::BaseLoader(model) {}

size_t MLPlaylistListModel::Loader::count() const /* override */
{
    vlc_ml_query_params_t params = getParams().toCQueryParams();

    return vlc_ml_count_playlists(m_ml, &params);
}

std::vector<std::unique_ptr<MLItem>>
MLPlaylistListModel::Loader::load(size_t index, size_t count) const /* override */
{
    vlc_ml_query_params_t params = getParams(index, count).toCQueryParams();

    ml_unique_ptr<vlc_ml_playlist_list_t> list(vlc_ml_list_playlists(m_ml, &params));

    if (list == nullptr)
        return {};

    std::vector<std::unique_ptr<MLItem>> result;

    for (const vlc_ml_playlist_t & playlist : ml_range_iterate<vlc_ml_playlist_t>(list))
    {
        result.emplace_back(std::make_unique<MLPlaylist>(m_ml, &playlist));
    }

    return result;
}
