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

#include "mlfoldersmodel.hpp"
#include <cassert>

MLFoldersBaseModel::MLFoldersBaseModel( QObject *parent )
    : QAbstractListModel( parent )
    , m_ml_event_handle( nullptr , [this](vlc_ml_event_callback_t* cb ) {
        if ( m_ml )
            vlc_ml_event_unregister_callback( m_ml , cb );
    })
{
    connect( this , &MLFoldersBaseModel::onMLEntryPointModified , this , &MLFoldersBaseModel::update );
}

MLFoldersBaseModel::EntryPoint::EntryPoint( const vlc_ml_folder_t& entryPoint)
    : mrl(entryPoint.psz_mrl)
    , banned(entryPoint.b_banned)
{
}

void MLFoldersBaseModel::setCtx(QmlMainContext *ctx)
{
    if (ctx)
    {
        m_ctx = ctx;
        setMl(vlc_ml_instance_get( m_ctx->getIntf() ));
    }
    else
    {
        m_ctx = nullptr;
        setMl(nullptr);
    }
    emit ctxChanged();
}

void MLFoldersBaseModel::setMl(vlc_medialibrary_t *ml)
{
    if (ml)
        m_ml_event_handle.reset( vlc_ml_event_register_callback( ml , onMlEvent , this ) );
    else
        m_ml_event_handle.reset( nullptr );
    m_ml = ml;
    update();
}

int MLFoldersBaseModel::rowCount( QModelIndex const & ) const
{
    return static_cast<int>(m_mrls.size());
}

QVariant MLFoldersBaseModel::data( const QModelIndex &index ,
                              int role) const {
    if ( !index.isValid() )
        return {};

    switch ( role )
    {
        case Banned:
            return m_mrls[index.row()].banned;
        case MRL:
            return m_mrls[index.row()].mrl;
        case Qt::DisplayRole:
        case DisplayUrl:
        {
            QUrl url = QUrl::fromUserInput(m_mrls[index.row()].mrl);
            if (!url.isValid())
                return {};
            return QVariant::fromValue( url.toDisplayString( QUrl::RemovePassword | QUrl::PreferLocalFile | QUrl::NormalizePathSegments ) );
        }
        default :
            return {};
    }
}

QHash<int, QByteArray> MLFoldersBaseModel::roleNames() const
{
    return {
        {DisplayUrl, "display_url"},
        {Banned, "banned"},
    };
}

void MLFoldersBaseModel::removeAt(int index)
{
    assert(index < rowCount());
    const QModelIndex idx = this->index( index, 0 );
    if (idx.isValid())
        remove( data( idx,  MRL ).toUrl() );

}

void MLFoldersBaseModel::update()
{
    beginResetModel();
    m_mrls = entryPoints();
    endResetModel();
}

void MLFoldersBaseModel::onMlEvent( void* data , const vlc_ml_event_t* event )
{
    auto self = static_cast<MLFoldersBaseModel *>( data );
    if ( event->i_type == VLC_ML_EVENT_ENTRY_POINT_ADDED || event->i_type == VLC_ML_EVENT_ENTRY_POINT_REMOVED ||
         event->i_type == VLC_ML_EVENT_ENTRY_POINT_UNBANNED || event->i_type == VLC_ML_EVENT_ENTRY_POINT_BANNED  )
    {
        if (!self->failed( event ))
            emit self->onMLEntryPointModified( QPrivateSignal() );
    }
}

std::vector<MLFoldersBaseModel::EntryPoint> MLFoldersModel::entryPoints() const
{
    std::vector<MLFoldersBaseModel::EntryPoint> r;

    vlc_ml_folder_list_t* entrypoints = vlc_ml_list_entry_points( ml(), nullptr );
    if ( entrypoints != nullptr )
    {
        for ( unsigned int i = 0; entrypoints && i < entrypoints->i_nb_items; i++ )
            r.emplace_back( entrypoints->p_items[i] );
        vlc_ml_release( entrypoints );
    }

    return r;
}

bool MLFoldersModel::failed(const vlc_ml_event_t *event) const
{
    if ( event->i_type == VLC_ML_EVENT_ENTRY_POINT_ADDED && !event->entry_point_added.b_success )
    {
        emit operationFailed( Add, QUrl::fromEncoded( event->entry_point_added.psz_entry_point ) );
        return true;
    }
    else if ( event->i_type == VLC_ML_EVENT_ENTRY_POINT_REMOVED && !event->entry_point_removed.b_success )
    {
        emit operationFailed( Remove, QUrl::fromEncoded( event->entry_point_removed.psz_entry_point ) );
        return true;
    }

    return false;
}

void MLFoldersModel::remove( const QUrl &mrl )
{
    vlc_ml_remove_folder( ml() , qtu( mrl.toString( QUrl::FullyEncoded ) ) );
}

void MLFoldersModel::add(const QUrl &mrl )
{
    vlc_ml_add_folder( ml() , qtu( mrl.toString( QUrl::FullyEncoded ) ) );
}

void MLBannedFoldersModel::remove(const QUrl &mrl)
{
    vlc_ml_unban_folder( ml() , qtu( mrl.toString( QUrl::FullyEncoded ) ) );
}

void MLBannedFoldersModel::add(const QUrl &mrl)
{
    vlc_ml_ban_folder( ml() , qtu( mrl.toString( QUrl::FullyEncoded ) ) );
}

std::vector<MLFoldersBaseModel::EntryPoint> MLBannedFoldersModel::entryPoints() const
{
    std::vector<MLFoldersBaseModel::EntryPoint> r;

    vlc_ml_folder_list_t* entrypoints = vlc_ml_list_banned_entry_points( ml(), nullptr );
    if ( entrypoints != nullptr )
    {
        for ( unsigned int i = 0; entrypoints && i < entrypoints->i_nb_items; i++ )
            r.emplace_back( entrypoints->p_items[i] );
        vlc_ml_release( entrypoints );
    }

    return r;
}

bool MLBannedFoldersModel::failed(const vlc_ml_event_t *event) const
{
    if ( event->i_type == VLC_ML_EVENT_ENTRY_POINT_BANNED && !event->entry_point_banned.b_success )
    {
        emit operationFailed( Ban, QUrl::fromEncoded( event->entry_point_banned.psz_entry_point ) );
        return true;
    }
    else if ( event->i_type == VLC_ML_EVENT_ENTRY_POINT_UNBANNED && !event->entry_point_unbanned.b_success )
    {
        emit operationFailed( Unban, QUrl::fromEncoded( event->entry_point_unbanned.psz_entry_point ) );
        return true;
    }

    return false;
}
