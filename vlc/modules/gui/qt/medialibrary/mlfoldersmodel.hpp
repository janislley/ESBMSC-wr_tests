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

#ifndef ML_FOLDERS_MODEL_HPP
#define ML_FOLDERS_MODEL_HPP

#ifdef HAVE_CONFIG_H

# include "config.h"

#endif

#include "qt.hpp"
#include <QAbstractListModel>
#include <QUrl>
#include <QList>
#include "mlhelper.hpp"

#include <util/qml_main_context.hpp>
#include <vlc_media_library.h>

class MLFoldersBaseModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QmlMainContext* ctx READ getCtx WRITE setCtx NOTIFY ctxChanged)

public:
    enum Roles
    {
        Banned = Qt::UserRole + 1,
        DisplayUrl,
        MRL
    };

    enum Operation
    {
        Add,
        Remove,
        Ban,
        Unban
    };

    MLFoldersBaseModel( QObject *parent = nullptr );

    void setCtx(QmlMainContext* ctx);
    inline QmlMainContext* getCtx() { return m_ctx; }
    void setMl(vlc_medialibrary_t* ml);
    inline vlc_medialibrary_t *ml() const { return m_ml; }

    int rowCount( QModelIndex const &parent = {} ) const  override;
    QVariant data( QModelIndex const &index , const int role = Qt::DisplayRole ) const  override;
    QHash<int, QByteArray> roleNames() const override;

public slots:
    virtual void remove( const QUrl &mrl ) = 0;
    virtual void add( const QUrl &mrl ) = 0;
    void removeAt( int index );

signals:
    void ctxChanged();
    void operationFailed( int op, QUrl url ) const;
    void onMLEntryPointModified(QPrivateSignal);

protected:
    struct EntryPoint
    {
        EntryPoint(const vlc_ml_folder_t &entryPoint );
        QString mrl;
        bool banned;
    };

    virtual std::vector<EntryPoint> entryPoints() const = 0;
    virtual bool failed( const vlc_ml_event_t* event ) const = 0; // will be called outside the main thread

private:
    static void onMlEvent( void* data , const vlc_ml_event_t* event );
    void update();

    using EventCallbackPtr = std::unique_ptr<vlc_ml_event_callback_t, std::function<void( vlc_ml_event_callback_t* )>>;

    std::vector<EntryPoint> m_mrls;
    vlc_medialibrary_t *m_ml = nullptr;
    QmlMainContext* m_ctx = nullptr;
    EventCallbackPtr m_ml_event_handle;
};

class MLFoldersModel : public MLFoldersBaseModel
{
public:
    using MLFoldersBaseModel::MLFoldersBaseModel;

    void remove( const QUrl &mrl ) override;
    void add( const QUrl &mrl ) override;

private:
    std::vector<EntryPoint> entryPoints() const final;
    bool failed( const vlc_ml_event_t* event ) const override;
};

class MLBannedFoldersModel : public MLFoldersBaseModel
{
public:
    using MLFoldersBaseModel::MLFoldersBaseModel;

    void remove( const QUrl &mrl ) override;
    void add( const QUrl &mrl ) override;

private:
    std::vector<EntryPoint> entryPoints() const final;
    bool failed( const vlc_ml_event_t* event ) const override;
};

#endif // ML_FOLDERS_MODEL_HPP
