/*****************************************************************************
 * preferences_widgets.cpp : Widgets for preferences displays
 ****************************************************************************
 * Copyright (C) 2006-2011 the VideoLAN team
 *
 * Authors: Clément Stenac <zorglub@videolan.org>
 *          Antoine Cellerier <dionoea@videolan.org>
 *          Jean-Baptiste Kempf <jb@videolan.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

/**
 * Todo:
 *  - Validator for modulelist
 */
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "dialogs/preferences/preferences_widgets.hpp"
#include "widgets/native/customwidgets.hpp"
#include "widgets/native/searchlineedit.hpp"
#include "util/qt_dirs.hpp"
#include <vlc_actions.h>
#include <vlc_intf_strings.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

#include <QString>
#include <QStringList>
#include <QVariant>
#include <QGridLayout>
#include <QSlider>
#include <QFileDialog>
#include <QGroupBox>
#include <QTreeWidgetItem>
#include <QTreeWidgetItemIterator>
#include <QSignalMapper>
#include <QDialogButtonBox>
#include <QKeyEvent>
#include <QColorDialog>
#include <QAction>
#include <QKeySequence>

#define MINWIDTH_BOX 90
#define LAST_COLUMN 10

#define HOTKEY_ITEM_HEIGHT 24

QString formatTooltip(const QString & tooltip)
{
    QString text = tooltip;
    text.replace("\n", "<br/>");

    QString formatted =
    "<html><head><meta name=\"qrichtext\" content=\"1\" />"
    "<style type=\"text/css\"> p, li { white-space: pre-wrap; } </style></head>"
    "<body style=\" font-family:'Sans Serif'; "
    "font-style:normal; text-decoration:none;\">"
    "<p style=\" margin-top:0px; margin-bottom:0px; margin-left:0px; "
    "margin-right:0px; -qt-block-indent:0; text-indent:0px;\">" +
    text + "</p></body></html>";
    return formatted;
}

ConfigControl *ConfigControl::createControl( module_config_t *p_item,
                                             QWidget *parent,
                                             QGridLayout *l, int line )
{
    ConfigControl *p_control = NULL;

    switch( p_item->i_type )
    {
    case CONFIG_ITEM_MODULE:
        p_control = new StringListConfigControl( p_item, parent );
        break;
    case CONFIG_ITEM_MODULE_CAT:
        p_control = new ModuleConfigControl( p_item, parent );
        break;
    case CONFIG_ITEM_MODULE_LIST:
        p_control = new ModuleListConfigControl( p_item, parent, false );
        break;
    case CONFIG_ITEM_MODULE_LIST_CAT:
        p_control = new ModuleListConfigControl( p_item, parent, true );
        break;
    case CONFIG_ITEM_STRING:
        if( p_item->list_count )
            p_control = new StringListConfigControl( p_item, parent );
        else
            p_control = new StringConfigControl( p_item, parent );
        break;
    case CONFIG_ITEM_PASSWORD:
        p_control = new PasswordConfigControl( p_item, parent );
        break;
    case CONFIG_ITEM_RGB:
        p_control = new ColorConfigControl( p_item, parent );
        break;
    case CONFIG_ITEM_INTEGER:
        if( p_item->list_count )
            p_control = new IntegerListConfigControl( p_item, parent );
        else
            p_control = new IntegerRangeConfigControl( p_item, parent );
        break;
    case CONFIG_ITEM_LOADFILE:
    case CONFIG_ITEM_SAVEFILE:
        p_control = new FileConfigControl( p_item, parent );
        break;
    case CONFIG_ITEM_DIRECTORY:
        p_control = new DirectoryConfigControl( p_item, parent );
        break;
    case CONFIG_ITEM_FONT:
        p_control = new FontConfigControl( p_item, parent );
        break;
    case CONFIG_ITEM_KEY:
        p_control = new KeySelectorControl( parent );
        break;
    case CONFIG_ITEM_BOOL:
        p_control = new BoolConfigControl( p_item, parent );
        break;
    case CONFIG_ITEM_FLOAT:
        p_control = new FloatRangeConfigControl( p_item, parent );
        break;
    default:
        break;
    }
    if ( p_control ) p_control->insertIntoExistingGrid( l, line );
    return p_control;
}

/* Inserts controls into layouts
   This is sub-optimal in the OO way, as controls's code still
   depends on Layout classes. We should use layout inserters [friend]
   classes, but it's unlikely we had to deal with a different layout.*/
void ConfigControl::insertInto( QBoxLayout *layout )
{
    QGridLayout *sublayout = new QGridLayout();
    fillGrid( sublayout, 0 );
    layout->addLayout( sublayout );
}

void ConfigControl::insertIntoExistingGrid( QGridLayout *l, int line )
{
    fillGrid( l, line );
}

/*******************************************************
 * Simple widgets
 *******************************************************/
InterfacePreviewWidget::InterfacePreviewWidget ( QWidget *parent ) : QLabel( parent )
{
    setGeometry( 0, 0, 128, 100 );
    setSizePolicy( QSizePolicy::Fixed, QSizePolicy::Fixed );
}

void InterfacePreviewWidget::setNormalPreview( bool b_minimal )
{
    setPreview( ( b_minimal ) ? MINIMAL : COMPLETE );
}

void InterfacePreviewWidget::setPreview( enum_style e_style )
{
    QString pixmapLocationString;

    switch( e_style )
    {
    default:
    case COMPLETE:
        pixmapLocationString = ":/prefsmenu/sample_complete.png";
        break;
    case MINIMAL:
        pixmapLocationString = ":/prefsmenu/sample_minimal.png";
        break;
    case SKINS:
        pixmapLocationString = ":/prefsmenu/sample_skins.png";
        break;
    }

    setPixmap( QPixmap( pixmapLocationString ).
               scaledToWidth( width(), Qt::SmoothTransformation ) );
    update();
}


/**************************************************************************
 * String-based controls
 *************************************************************************/

void
VStringConfigControl::doApply()
{
    config_PutPsz( getName(), qtu( getValue() ) );
}

/*********** String **************/
StringConfigControl::StringConfigControl( module_config_t *_p_item,
                                          QWidget *_parent ) :
    VStringConfigControl( _p_item )
{
    label = new QLabel( p_item->psz_text ? qfut(p_item->psz_text) : "", _parent );
    text = new QLineEdit( p_item->value.psz ? qfu(p_item->value.psz) : "", _parent );
    finish();
}

StringConfigControl::StringConfigControl( module_config_t *_p_item,
                                          QLabel *_label, QLineEdit *_text ) :
    VStringConfigControl( _p_item )
{
    text = _text;
    label = _label;
    finish( );
}

void StringConfigControl::fillGrid( QGridLayout *l, int line )
{
    l->addWidget( label, line, 0 );
    l->setColumnMinimumWidth( 1, 10 );
    l->addWidget( text, line, LAST_COLUMN, Qt::AlignRight );
}

void StringConfigControl::finish()
{
    text->setText( qfu(p_item->value.psz) );
    if( p_item->psz_longtext )
    {
        QString tipText = qfut(p_item->psz_longtext);
        text->setToolTip( formatTooltip(tipText) );
        if( label )
            label->setToolTip( formatTooltip(tipText) );
    }
    if( label )
        label->setBuddy( text );
}

/********* String / Password **********/
PasswordConfigControl::PasswordConfigControl( module_config_t *_p_item,
                                              QWidget *_parent ) :
    StringConfigControl( _p_item, _parent )
{
    finish();
}

PasswordConfigControl::PasswordConfigControl( module_config_t *_p_item,
                                              QLabel *_label, QLineEdit *_text ) :
    StringConfigControl( _p_item, _label, _text )
{
    finish();
}

void PasswordConfigControl::finish()
{
    text->setEchoMode( QLineEdit::Password );
}

/*********** File **************/
FileConfigControl::FileConfigControl( module_config_t *_p_item, QWidget *p ) :
    VStringConfigControl( _p_item )
{
    label = new QLabel( qfut(p_item->psz_text), p );
    text = new QLineEdit( qfu(p_item->value.psz), p );
    browse = new QPushButton( qtr( "Browse..." ), p );

    BUTTONACT( browse, updateField() );

    finish();
}

FileConfigControl::FileConfigControl( module_config_t *_p_item,
                                      QLabel *_label, QLineEdit *_text,
                                      QPushButton *_button ) :
    VStringConfigControl( _p_item )
{
    browse = _button;
    text = _text;
    label = _label;

    BUTTONACT( browse, updateField() );

    finish( );
}

void FileConfigControl::fillGrid( QGridLayout *l, int line )
{
    l->addWidget( label, line, 0 );
    l->setColumnMinimumWidth( 1, 10 );
    QHBoxLayout *textAndButton = new QHBoxLayout();
    textAndButton->setMargin( 0 );
    textAndButton->addWidget( text, 2 );
    textAndButton->addWidget( browse, 0 );
    l->addLayout( textAndButton, line, LAST_COLUMN );
}

void FileConfigControl::updateField()
{
    QString file;

    if (p_item->i_type == CONFIG_ITEM_SAVEFILE)
        file = QFileDialog::getSaveFileName( NULL, qtr( "Save File" ),
                                             QVLCUserDir( VLC_HOME_DIR ) );
    else
        file = QFileDialog::getOpenFileName( NULL, qtr( "Select File" ),
                                             QVLCUserDir( VLC_HOME_DIR ) );

    if( file.isNull() ) return;
    text->setText( toNativeSeparators( file ) );
}

void FileConfigControl::finish()
{
    text->setText( qfu(p_item->value.psz) );
    if( p_item->psz_longtext )
    {
        QString tipText = qfut(p_item->psz_longtext);
        text->setToolTip( formatTooltip(tipText) );
        if( label )
            label->setToolTip( formatTooltip(tipText) );
    }
    if( label )
        label->setBuddy( text );
}

/********* String / Directory **********/
DirectoryConfigControl::DirectoryConfigControl( module_config_t *_p_item,
                                                QWidget *p ) :
    FileConfigControl( _p_item, p )
{}

DirectoryConfigControl::DirectoryConfigControl( module_config_t *_p_item,
                                                QLabel *_p_label,
                                                QLineEdit *_p_line,
                                                QPushButton *_p_button ) :
    FileConfigControl( _p_item, _p_label, _p_line, _p_button)
{}

void DirectoryConfigControl::updateField()
{
    QString dir = QFileDialog::getExistingDirectory( NULL,
                      qfut( I_OP_SEL_DIR ),
                      text->text().isEmpty() ?
                        QVLCUserDir( VLC_HOME_DIR ) : text->text(),
                  QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks );

    if( dir.isNull() ) return;
    text->setText( toNativeSepNoSlash( dir ) );
}

/********* String / Font **********/
FontConfigControl::FontConfigControl( module_config_t *_p_item, QWidget *p ) :
    VStringConfigControl( _p_item )
{
    label = new QLabel( qfut(p_item->psz_text), p );
    font = new QFontComboBox( p );
    font->setCurrentFont( QFont( qfu( p_item->value.psz) ) );

    if( p_item->psz_longtext )
    {
        label->setToolTip( formatTooltip( qfut(p_item->psz_longtext) ) );
    }
}

FontConfigControl::FontConfigControl( module_config_t *_p_item,
                                      QLabel *_p_label,
                                      QFontComboBox *_p_font) :
    VStringConfigControl( _p_item)
{
    label = _p_label;
    font = _p_font;
    font->setCurrentFont( QFont( qfu( p_item->value.psz) ) );

    if( p_item->psz_longtext )
    {
        label->setToolTip( formatTooltip( qfut(p_item->psz_longtext) ) );
    }
}

void FontConfigControl::fillGrid( QGridLayout *l, int line )
{
    l->addWidget( label, line, 0 );
    l->addWidget( font, line, 1, 1, -1 );
}

/********* String / choice list **********/
StringListConfigControl::StringListConfigControl( module_config_t *_p_item,
                                                  QWidget *p ) :
    VStringConfigControl( _p_item )
{
    label = new QLabel( qfut(p_item->psz_text), p );
    combo = new QComboBox( p );
    combo->setMinimumWidth( MINWIDTH_BOX );
    combo->setSizePolicy( QSizePolicy::MinimumExpanding, QSizePolicy::Preferred );

    /* needed to see update from getting choice list where callback used */
    module_config_t *p_module_config = config_FindConfig( p_item->psz_name );

    finish( p_module_config );
}

StringListConfigControl::StringListConfigControl( module_config_t *_p_item,
                                                  QLabel *_label,
                                                  QComboBox *_combo ) :
    VStringConfigControl( _p_item )
{
    combo = _combo;
    label = _label;

    /* needed to see update from getting choice list where callback used */
    module_config_t *p_module_config = config_FindConfig( getName() );

    finish( p_module_config );
}

void StringListConfigControl::fillGrid( QGridLayout *l, int line )
{
    l->addWidget( label, line, 0 );
    l->addWidget( combo, line, LAST_COLUMN, Qt::AlignRight );
}

void StringListConfigControl::comboIndexChanged( int i_index )
{
    Q_UNUSED( i_index );
    emit changed();
}

void StringListConfigControl::finish(module_config_t *p_module_config )
{
    combo->setEditable( false );
    CONNECT( combo, currentIndexChanged( int ), this, comboIndexChanged( int ) );

    if(!p_module_config) return;

    char **values, **texts;
    ssize_t count = config_GetPszChoices( p_item->psz_name, &values, &texts );
    for( ssize_t i = 0; i < count && texts; i++ )
    {
        if( texts[i] == NULL || values[i] == NULL )
            continue;

        combo->addItem( qfu(texts[i]), QVariant( qfu(values[i])) );
        if( !strcmp( p_item->value.psz ? p_item->value.psz : "", values[i] ) )
            combo->setCurrentIndex( combo->count() - 1 );
        free( texts[i] );
        free( values[i] );
    }
    free( texts );
    free( values );

    if( p_module_config->psz_longtext )
    {
        QString tipText = qfut(p_module_config->psz_longtext);
        combo->setToolTip( formatTooltip(tipText) );
        if( label )
            label->setToolTip( formatTooltip(tipText) );
    }
    if( label )
        label->setBuddy( combo );
}

QString StringListConfigControl::getValue() const
{
    return combo->itemData( combo->currentIndex() ).toString();
}

void setfillVLCConfigCombo( const char *configname, QComboBox *combo )
{
    module_config_t *p_config = config_FindConfig( configname );
    if( p_config == NULL )
        return;

    if( (p_config->i_type & 0xF0) == CONFIG_ITEM_STRING )
    {
        char **values, **texts;
        ssize_t count = config_GetPszChoices(configname, &values, &texts);
        for( ssize_t i = 0; i < count; i++ )
        {
            combo->addItem( qfut(texts[i]), QVariant(qfu(values[i])) );
            if( p_config->value.psz && !strcmp(p_config->value.psz, values[i]) )
                combo->setCurrentIndex( i );
            free( texts[i] );
            free( values[i] );
        }
        free( texts );
        free( values );
    }
    else
    {
        int64_t *values;
        char **texts;
        ssize_t count = config_GetIntChoices(configname, &values, &texts);
        for( ssize_t i = 0; i < count; i++ )
        {
            combo->addItem( qfut(texts[i]), QVariant(qlonglong(values[i])) );
            if( p_config->value.i == values[i] )
                combo->setCurrentIndex( i );
            free( texts[i] );
        }
        free( texts );
        free( values );
    }

    if( p_config->psz_longtext != NULL )
        combo->setToolTip( qfu( p_config->psz_longtext ) );
}

/********* Module **********/
ModuleConfigControl::ModuleConfigControl( module_config_t *_p_item,
                                          QWidget *p ) :
    VStringConfigControl( _p_item )
{
    label = new QLabel( qfut(p_item->psz_text), p );
    combo = new QComboBox( p );
    combo->setMinimumWidth( MINWIDTH_BOX );
    finish( );
}

ModuleConfigControl::ModuleConfigControl( module_config_t *_p_item,
                                          QLabel *_label, QComboBox *_combo ) :
    VStringConfigControl( _p_item )
{
    combo = _combo;
    label = _label;
    finish( );
}

void ModuleConfigControl::fillGrid( QGridLayout *l, int line )
{
    l->addWidget( label, line, 0 );
    l->addWidget( combo, line, LAST_COLUMN );
}

void ModuleConfigControl::finish( )
{
    combo->setEditable( false );

    /* build a list of available modules */
    size_t count;
    module_t **p_list = module_list_get( &count );
    combo->addItem( qtr("Default") );
    for( size_t i = 0; i < count; i++ )
    {
        module_t *p_parser = p_list[i];

        if( !strcmp( module_get_object( p_parser ), "core" ) ) continue;

        unsigned confsize;
        module_config_t *p_config;

        p_config = module_config_get (p_parser, &confsize);
        for (size_t i = 0; i < confsize; i++)
        {
            /* Hack: required subcategory is stored in i_min */
            const module_config_t *p_cfg = p_config + i;
            if( p_cfg->i_type == CONFIG_SUBCATEGORY &&
                p_cfg->value.i == p_item->min.i )
            {
                combo->addItem( qfut( module_GetLongName( p_parser )),
                                QVariant( module_get_object( p_parser ) ) );
                if( p_item->value.psz && !strcmp( p_item->value.psz,
                                                  module_get_object( p_parser ) ) )
                    combo->setCurrentIndex( combo->count() - 1 );
                break;
            }
        }
        module_config_free (p_config);
    }
    module_list_free( p_list );

    if( p_item->psz_longtext )
    {
        QString tipText = qfut(p_item->psz_longtext);
        combo->setToolTip( formatTooltip(tipText) );
        if( label )
            label->setToolTip( formatTooltip(tipText) );
    }
    if( label )
        label->setBuddy( combo );
}

QString ModuleConfigControl::getValue() const
{
    return combo->itemData( combo->currentIndex() ).toString();
}

/********* Module list **********/
ModuleListConfigControl::ModuleListConfigControl( module_config_t *_p_item,
                                                  QWidget *p, bool bycat ) :
    VStringConfigControl( _p_item )
{
    groupBox = NULL;

    /* Special Hack */
    if( !p_item->psz_text ) return;

    groupBox = new QGroupBox( qfut(p_item->psz_text), p );
    text = new QLineEdit( p );
    QGridLayout *layoutGroupBox = new QGridLayout( groupBox );

    finish( bycat );

    int boxline = 0;
    foreach ( checkBoxListItem *it, modules )
    {
        layoutGroupBox->addWidget( it->checkBox, boxline / 2, boxline % 2 );
        boxline++;
    }

    layoutGroupBox->addWidget( text, boxline, 0, 1, 2 );

    if( p_item->psz_longtext )
        text->setToolTip( formatTooltip( qfut( p_item->psz_longtext) ) );
}

void ModuleListConfigControl::fillGrid( QGridLayout *l, int line )
{
    l->addWidget( groupBox, line, 0, 1, -1 );
}

ModuleListConfigControl::~ModuleListConfigControl()
{
    foreach ( checkBoxListItem *it, modules )
        free( it->psz_module );
    qDeleteAll( modules );
    modules.clear();
    delete groupBox;
}

void ModuleListConfigControl::checkbox_lists( module_t *p_parser )
{
    const char *help = module_get_help( p_parser );
    checkbox_lists( qfut( module_GetLongName( p_parser ) ),
                    help != NULL ? qfut( help ): "",
                    module_get_object( p_parser ) );
}

void ModuleListConfigControl::checkbox_lists( QString label, QString help, const char* psz_module )
{
    QCheckBox *cb = new QCheckBox( label );
    checkBoxListItem *cbl = new checkBoxListItem;

    CONNECT( cb, stateChanged( int ), this, onUpdate() );
    if( !help.isEmpty() )
        cb->setToolTip( formatTooltip( help ) );
    cbl->checkBox = cb;

    cbl->psz_module = strdup( psz_module );
    modules.append( cbl );

    if( p_item->value.psz && strstr( p_item->value.psz, cbl->psz_module ) )
        cbl->checkBox->setChecked( true );
}

void ModuleListConfigControl::finish( bool bycat )
{
    /* build a list of available modules */
    size_t count;
    module_t **p_list = module_list_get( &count );
    for( size_t i = 0; i < count; i++ )
    {
        module_t *p_parser = p_list[i];

        if( bycat )
        {
            if( !strcmp( module_get_object( p_parser ), "core" ) ) continue;

            unsigned confsize;
            module_config_t *p_config = module_config_get (p_parser, &confsize);

            for (size_t i = 0; i < confsize; i++)
            {
                module_config_t *p_cfg = p_config + i;
                /* Hack: required subcategory is stored in i_min */
                if( p_cfg->i_type == CONFIG_SUBCATEGORY &&
                        p_cfg->value.i == p_item->min.i )
                {
                    checkbox_lists( p_parser );
                }

                /* Parental Advisory HACK:
                 * Selecting HTTP, RC and Telnet interfaces is difficult now
                 * since they are just the lua interface module */
                if( p_cfg->i_type == CONFIG_SUBCATEGORY &&
                    !strcmp( module_get_object( p_parser ), "lua" ) &&
                    !strcmp( p_item->psz_name, "extraintf" ) &&
                    p_cfg->value.i == p_item->min.i )
                {
                    checkbox_lists( "Web", "Lua HTTP", "http" );
                    checkbox_lists( "Telnet", "Lua Telnet", "telnet" );
#ifndef _WIN32
                    checkbox_lists( "Console", "Lua CLI", "cli" );
#endif
                }
            }
            module_config_free (p_config);
        }
        else if( module_provides( p_parser, p_item->psz_type ) )
        {
            checkbox_lists(p_parser);
        }
    }
    module_list_free( p_list );
}

QString ModuleListConfigControl::getValue() const
{
    assert( text );
    return text->text();
}

void ModuleListConfigControl::changeVisibility( bool b )
{
    foreach ( checkBoxListItem *it, modules )
        it->checkBox->setVisible( b );
    groupBox->setVisible( b );
}

void ModuleListConfigControl::onUpdate()
{
    text->clear();
    bool first = true;

    foreach ( checkBoxListItem *it, modules )
    {
        if( it->checkBox->isChecked() )
        {
            if( first )
            {
                text->setText( text->text() + it->psz_module );
                first = false;
            }
            else
            {
                text->setText( text->text() + ":" + it->psz_module );
            }
        }
    }
}

/**************************************************************************
 * Integer-based controls
 *************************************************************************/

void
VIntConfigControl::doApply()
{
    config_PutInt( getName(), getValue() );
}

/*********** Integer **************/
IntegerConfigControl::IntegerConfigControl( module_config_t *_p_item,
                                            QWidget *p ) :
    VIntConfigControl( _p_item )
{
    label = new QLabel( qfut(p_item->psz_text), p );
    spin = new QSpinBox( p );
    spin->setMinimumWidth( MINWIDTH_BOX );
    spin->setAlignment( Qt::AlignRight );
    spin->setMaximumWidth( MINWIDTH_BOX );
    finish();
}

IntegerConfigControl::IntegerConfigControl( module_config_t *_p_item,
                                            QLabel *_label, QSpinBox *_spin ) :
    VIntConfigControl( _p_item )
{
    spin = _spin;
    label = _label;
    finish();
}

void IntegerConfigControl::fillGrid( QGridLayout *l, int line )
{
    l->addWidget( label, line, 0 );
    l->addWidget( spin, line, LAST_COLUMN, Qt::AlignRight );
}

void IntegerConfigControl::finish()
{
    spin->setMaximum( 2000000000 );
    spin->setMinimum( -2000000000 );
    spin->setValue( p_item->value.i );

    if( p_item->psz_longtext )
    {
        QString tipText = qfut(p_item->psz_longtext);
        spin->setToolTip( formatTooltip(tipText) );
        if( label )
            label->setToolTip( formatTooltip(tipText) );
    }
    if( label )
        label->setBuddy( spin );
}

int IntegerConfigControl::getValue() const
{
    return spin->value();
}

/********* Integer range **********/
IntegerRangeConfigControl::IntegerRangeConfigControl( module_config_t *_p_item,
                                                      QWidget *p ) :
    IntegerConfigControl( _p_item, p )
{
    finish();
}

IntegerRangeConfigControl::IntegerRangeConfigControl( module_config_t *_p_item,
                                                      QLabel *_label,
                                                      QSpinBox *_spin ) :
    IntegerConfigControl( _p_item, _label, _spin )
{
    finish();
}

void IntegerRangeConfigControl::finish()
{
    spin->setMaximum( p_item->max.i > INT_MAX ? INT_MAX : p_item->max.i );
    spin->setMinimum( p_item->min.i < INT_MIN ? INT_MIN : p_item->min.i );
}

IntegerRangeSliderConfigControl::IntegerRangeSliderConfigControl(
                                            module_config_t *_p_item,
                                            QLabel *_label, QSlider *_slider ) :
    VIntConfigControl( _p_item )
{
    slider = _slider;
    label = _label;
    slider->setMaximum( p_item->max.i > INT_MAX ? INT_MAX : p_item->max.i );
    slider->setMinimum( p_item->min.i < INT_MIN ? INT_MIN : p_item->min.i );
    slider->setValue( p_item->value.i );
    if( p_item->psz_longtext )
    {
        QString tipText = qfut(p_item->psz_longtext);
        slider->setToolTip( formatTooltip(tipText) );
        if( label )
            label->setToolTip( formatTooltip(tipText) );
    }
    if( label )
        label->setBuddy( slider );
}

int IntegerRangeSliderConfigControl::getValue() const
{
    return slider->value();
}


/********* Integer / choice list **********/
IntegerListConfigControl::IntegerListConfigControl( module_config_t *_p_item,
                                                    QWidget *p ) :
    VIntConfigControl( _p_item )
{
    label = new QLabel( qfut(p_item->psz_text), p );
    combo = new QComboBox( p );
    combo->setMinimumWidth( MINWIDTH_BOX );

    /* needed to see update from getting choice list where callback used */
    module_config_t *p_module_config = config_FindConfig( p_item->psz_name );

    finish( p_module_config );
}

IntegerListConfigControl::IntegerListConfigControl( module_config_t *_p_item,
                                                    QLabel *_label,
                                                    QComboBox *_combo ) :
    VIntConfigControl( _p_item )
{
    combo = _combo;
    label = _label;

    /* needed to see update from getting choice list where callback used */
    module_config_t *p_module_config = config_FindConfig( getName() );

    finish( p_module_config );
}

void IntegerListConfigControl::fillGrid( QGridLayout *l, int line )
{
    l->addWidget( label, line, 0 );
    l->addWidget( combo, line, LAST_COLUMN, Qt::AlignRight );
}

void IntegerListConfigControl::finish(module_config_t *p_module_config )
{
    combo->setEditable( false );

    if(!p_module_config) return;

    int64_t *values;
    char **texts;
    ssize_t count = config_GetIntChoices( p_module_config->psz_name,
                                          &values, &texts );
    for( ssize_t i = 0; i < count; i++ )
    {
        combo->addItem( qfut(texts[i]), qlonglong(values[i]) );
        if( p_module_config->value.i == values[i] )
            combo->setCurrentIndex( combo->count() - 1 );
        free( texts[i] );
    }
    free( texts );
    free( values );
    if( p_item->psz_longtext )
    {
        QString tipText = qfut(p_item->psz_longtext );
        combo->setToolTip( formatTooltip(tipText) );
        if( label )
            label->setToolTip( formatTooltip(tipText) );
    }
    if( label )
        label->setBuddy( combo );
}

int IntegerListConfigControl::getValue() const
{
    return combo->itemData( combo->currentIndex() ).toInt();
}

/*********** Boolean **************/
BoolConfigControl::BoolConfigControl( module_config_t *_p_item, QWidget *p ) :
    VIntConfigControl( _p_item )
{
    checkbox = new QCheckBox( qfut(p_item->psz_text), p );
    finish();
}

BoolConfigControl::BoolConfigControl( module_config_t *_p_item,
                                      QLabel *_label,
                                      QAbstractButton *_checkbox ) :
    VIntConfigControl( _p_item )
{
    checkbox = _checkbox;
    VLC_UNUSED( _label );
    finish();
}

void BoolConfigControl::fillGrid( QGridLayout *l, int line )
{
    l->addWidget( checkbox, line, 0, 1, -1 );
}

void BoolConfigControl::finish()
{
    checkbox->setChecked( p_item->value.i );
    if( p_item->psz_longtext )
        checkbox->setToolTip( formatTooltip(qfut(p_item->psz_longtext)) );
}

int BoolConfigControl::getValue() const
{
    return checkbox->isChecked();
}

/************* Color *************/
ColorConfigControl::ColorConfigControl( module_config_t *_p_item,
                                        QWidget *p ) :
    VIntConfigControl( _p_item )
{
    label = new QLabel( p );
    color_but = new QToolButton( p );
    finish();
}

ColorConfigControl::ColorConfigControl( module_config_t *_p_item,
                                        QLabel *_label,
                                        QAbstractButton *_color ) :
    VIntConfigControl( _p_item )
{
    label = _label;
    color_but = _color;
    finish();
}

void ColorConfigControl::fillGrid( QGridLayout *l, int line )
{
    l->addWidget( label, line, 0 );
    l->addWidget( color_but, line, LAST_COLUMN, Qt::AlignRight );
}

void ColorConfigControl::finish()
{
    i_color = p_item->value.i;

    color_px = new QPixmap( 34, 20 );
    color_px->fill( QColor( i_color ) );
    color_but->setIcon( QIcon( *color_px ) );
    color_but->setMinimumWidth( 40 );

    label->setText( qfut(p_item->psz_text) );
    if( p_item->psz_longtext )
    {
        label->setToolTip( formatTooltip(qfut(p_item->psz_longtext)) );
        color_but->setToolTip( formatTooltip(qfut(p_item->psz_longtext)) );
    }

    BUTTONACT( color_but, selectColor() );
}

int ColorConfigControl::getValue() const
{
    return i_color;
}

void ColorConfigControl::selectColor()
{
    QColor color = QColorDialog::getColor( QColor( i_color ) );
    if( color.isValid() )
    {
        i_color = (color.red() << 16) + (color.green() << 8) + color.blue();

        color_px->fill( QColor( i_color ) );
        color_but->setIcon( QIcon( *color_px ) );
    }
}


/**************************************************************************
 * Float-based controls
 *************************************************************************/

void
VFloatConfigControl::doApply()
{
    config_PutFloat( getName(), getValue() );
}

/*********** Float **************/
FloatConfigControl::FloatConfigControl( module_config_t *_p_item,
                                        QWidget *p ) :
    VFloatConfigControl( _p_item )
{
    label = new QLabel( qfut(p_item->psz_text), p );
    spin = new QDoubleSpinBox( p );
    spin->setMinimumWidth( MINWIDTH_BOX );
    spin->setMaximumWidth( MINWIDTH_BOX );
    spin->setAlignment( Qt::AlignRight );
    finish();
}

FloatConfigControl::FloatConfigControl( module_config_t *_p_item,
                                        QLabel *_label,
                                        QDoubleSpinBox *_spin ) :
    VFloatConfigControl( _p_item )
{
    spin = _spin;
    label = _label;
    finish();
}

void FloatConfigControl::fillGrid( QGridLayout *l, int line )
{
    l->addWidget( label, line, 0 );
    l->addWidget( spin, line, LAST_COLUMN, Qt::AlignRight );
}

void FloatConfigControl::finish()
{
    spin->setMaximum( 2000000000. );
    spin->setMinimum( -2000000000. );
    spin->setSingleStep( 0.1 );
    spin->setValue( (double)p_item->value.f );
    if( p_item->psz_longtext )
    {
        QString tipText = qfut(p_item->psz_longtext);
        spin->setToolTip( formatTooltip(tipText) );
        if( label )
            label->setToolTip( formatTooltip(tipText) );
    }
    if( label )
        label->setBuddy( spin );
}

float FloatConfigControl::getValue() const
{
    return (float)spin->value();
}

/*********** Float with range **************/
FloatRangeConfigControl::FloatRangeConfigControl( module_config_t *_p_item,
                                                  QWidget *p ) :
    FloatConfigControl( _p_item, p )
{
    finish();
}

FloatRangeConfigControl::FloatRangeConfigControl( module_config_t *_p_item,
                                                  QLabel *_label,
                                                  QDoubleSpinBox *_spin ) :
    FloatConfigControl( _p_item, _label, _spin )
{
    finish();
}

void FloatRangeConfigControl::finish()
{
    spin->setMaximum( (double)p_item->max.f );
    spin->setMinimum( (double)p_item->min.f );
}


/**********************************************************************
 * Key selector widget
 **********************************************************************/
KeySelectorControl::KeySelectorControl( QWidget *p ) : ConfigControl( nullptr )
{
    label = new QLabel(
        qtr( "Action hotkey mappings. Double-click (or select and press Enter) "
             "to change an action's hotkey. The delete key will unset." ), p );

    label->setWordWrap( true );
    searchLabel = new QLabel( qtr( "Search" ), p );
    actionSearch = new SearchLineEdit();

    searchOptionLabel = new QLabel( qtr("in") );
    searchOption = new QComboBox();
    searchOption->addItem( qtr("Any field"), ANY_COL );
    searchOption->addItem( qtr("Actions"), ACTION_COL );
    searchOption->addItem( qtr("Hotkeys"), HOTKEY_COL );
    searchOption->addItem( qtr("Global Hotkeys"), GLOBAL_HOTKEY_COL );

    table = new QTreeWidget( p );
    table->setColumnCount( ANY_COL );
    table->headerItem()->setText( ACTION_COL, qtr( "Action" ) );
    table->headerItem()->setText( HOTKEY_COL, qtr( "Hotkey" ) );
    table->headerItem()->setToolTip( HOTKEY_COL, qtr( "Application level hotkey" ) );
    table->headerItem()->setText( GLOBAL_HOTKEY_COL, qtr( "Global" ) );
    table->headerItem()->setToolTip( GLOBAL_HOTKEY_COL, qtr( "Desktop level hotkey" ) );
    table->setAlternatingRowColors( true );
    table->setSelectionBehavior( QAbstractItemView::SelectItems );

    table->installEventFilter( this );

    /* Find the top most widget */
    QWidget *parent, *rootWidget = p;
    while( (parent = rootWidget->parentWidget()) != NULL )
        rootWidget = parent;
    buildAppHotkeysList( rootWidget );

    finish();

    CONNECT( actionSearch, textChanged( const QString& ),
             this, filter() );
    connect( searchOption, QOverload<int>::of(&QComboBox::activated),
             this, &KeySelectorControl::filter );
}

void KeySelectorControl::fillGrid( QGridLayout *l, int line )
{
    QGridLayout *gLayout = new QGridLayout();
    gLayout->addWidget( label, 0, 0, 1, 4 );
    gLayout->addWidget( searchLabel, 1, 0, 1, 1 );
    gLayout->addWidget( actionSearch, 1, 1, 1, 1 );
    gLayout->addWidget( searchOptionLabel, 1, 2, 1, 1 );
    gLayout->addWidget( searchOption, 1, 3, 1, 1 );
    gLayout->addWidget( table, 2, 0, 1, 4 );
    l->addLayout( gLayout, line, 0, 1, -1 );
}

void KeySelectorControl::buildAppHotkeysList( QWidget *rootWidget )
{
    QList<QAction *> actionsList = rootWidget->findChildren<QAction *>();
    foreach( const QAction *action, actionsList )
    {
        const QList<QKeySequence> shortcuts = action->shortcuts();
        foreach( const QKeySequence &keySequence, shortcuts )
            existingkeys << keySequence.toString();
    }
}

void KeySelectorControl::finish()
{
    /* Fill the table

       Each table row (action) has the following:
        - Non-global option name stored in data of column 0 (action name) field.
        - Translated key assignment strings displayed in columns 1 & 2, global
          and non-global respectively.
        - Non-translated (stored) key assignment strings stored in data of
          columns 1 & 2, global and non-global respectively.
     */

    /* Get the main Module */
    module_t *p_main = module_get_main();
    assert( p_main );

    /* Access to the module_config_t */
    unsigned confsize;
    module_config_t *p_config;

    p_config = module_config_get (p_main, &confsize);

    QMultiMap<QString, QString> global_keys;
    for (size_t i = 0; i < confsize; i++)
    {
        module_config_t *p_config_item = p_config + i;

        if( p_config_item->i_type != CONFIG_ITEM_KEY )
            continue;

        /* If we are a (non-global) key option not empty */
        if( strncmp( p_config_item->psz_name, "global-", 7 ) != 0 )
        {
            QTreeWidgetItem *treeItem = new QTreeWidgetItem();
            treeItem->setText( ACTION_COL, p_config_item->psz_text ?
                                           qfut( p_config_item->psz_text ) : qfu("") );
            treeItem->setData( ACTION_COL, Qt::UserRole,
                               QVariant( qfu( p_config_item->psz_name ) ) );
            if (p_config_item->psz_longtext)
                treeItem->setToolTip( ACTION_COL, qfut(p_config_item->psz_longtext) );

            QString keys = p_config_item->value.psz ? qfut(p_config_item->value.psz) : qfu("");
            treeItem->setText( HOTKEY_COL, keys.replace( "\t", ", " ) );
            treeItem->setToolTip( HOTKEY_COL, qtr("Double click to change.\nDelete key to remove.") );
            treeItem->setToolTip( GLOBAL_HOTKEY_COL, qtr("Double click to change.\nDelete key to remove.") );
            treeItem->setData( HOTKEY_COL, Qt::UserRole, QVariant( p_config_item->value.psz ) );
            table->addTopLevelItem( treeItem );
        }
        /* Capture global key option mappings to fill in afterwards */
        else if( !EMPTY_STR( p_config_item->value.psz ) )
        {
            global_keys.insert( qfu( p_config_item->psz_name + 7 ),
                                qfu( p_config_item->value.psz ) );
        }
    }

    QMap<QString, QString>::const_iterator i = global_keys.constBegin();
    while (i != global_keys.constEnd())
    {
        for (QTreeWidgetItemIterator iter(table); *iter; ++iter)
        {
            QTreeWidgetItem *item = *iter;

            if( item->data( ACTION_COL, Qt::UserRole ) == i.key() )
            {
                QString keys = i.value();
                item->setText( GLOBAL_HOTKEY_COL, qfut(qtu(keys)).replace( "\t", ", " ) );
                item->setData( GLOBAL_HOTKEY_COL, Qt::UserRole, keys );
                break;
            }
        }
        ++i;
    }

    module_config_free (p_config);

    table->resizeColumnToContents( ACTION_COL );
    table->resizeColumnToContents( HOTKEY_COL );

    table->setUniformRowHeights( true );
    table->topLevelItem(0)->setSizeHint( 0, QSize( 0, HOTKEY_ITEM_HEIGHT ) );

    CONNECT( table, itemActivated( QTreeWidgetItem *, int ),
             this, selectKey( QTreeWidgetItem *, int ) );
}

void KeySelectorControl::filter()
{
    const QString &qs_search = actionSearch->text();
    int i_column = searchOption->itemData( searchOption->currentIndex() ).toInt();
    int i_column_count = 1;
    if( i_column == ANY_COL )
    {
        i_column = 0; // ACTION_COL
        i_column_count = ANY_COL;
    }
    for (QTreeWidgetItemIterator iter(table); *iter; ++iter)
    {
        QTreeWidgetItem *item = *iter;
        bool found = false;
        for( int idx = i_column; idx < (i_column + i_column_count); idx++ )
        {
            if( item->text( idx ).contains( qs_search, Qt::CaseInsensitive ) )
            {
                found = true;
                break;
            }
        }
        item->setHidden( !found );
    }
}

void KeySelectorControl::selectKey( QTreeWidgetItem *keyItem, int column )
{
    /* This happens when triggered by ClickEater */
    if( keyItem == NULL ) keyItem = table->currentItem();

    /* This can happen when nothing is selected on the treeView
       and the shortcutValue is clicked */
    if( !keyItem ) return;

    /* If clicked on the first column, assuming user wants the normal hotkey */
    if( column == ACTION_COL ) column = HOTKEY_COL;

    bool b_global = ( column == GLOBAL_HOTKEY_COL );

    /* Launch a small dialog to ask for a new key */
    KeyInputDialog *d = new KeyInputDialog( table, keyItem, b_global );
    d->setExistingkeysSet( &existingkeys );
    d->exec();

    if( d->result() == QDialog::Accepted )
    {
        /* In case of conflict, reset other keys*/
        if( d->conflicts )
        {
            for (QTreeWidgetItemIterator iter(table); *iter; ++iter)
            {
                QTreeWidgetItem *it = *iter;
                if( keyItem == it )
                    continue;
                QStringList it_keys = it->data( column, Qt::UserRole ).toString().split( "\t" );
                if( it_keys.removeAll( d->vlckey ) )
                {
                    QString it_filteredkeys = it_keys.join( "\t" );
                    it->setText( column, it_filteredkeys.replace( "\t", ", " ) );
                    it->setData( column, Qt::UserRole, it_filteredkeys );
                }
            }
        }

        keyItem->setText( column, d->vlckey_tr );
        keyItem->setData( column, Qt::UserRole, d->vlckey );
    }
    else if( d->result() == 2 )
    {
        keyItem->setText( column, NULL );
        keyItem->setData( column, Qt::UserRole, QVariant() );
    }

    delete d;
}

void KeySelectorControl::doApply()
{
    for (QTreeWidgetItemIterator iter(table); *iter; ++iter)
    {
        QTreeWidgetItem *it = *iter;

        QString option = it->data( ACTION_COL, Qt::UserRole ).toString();

        config_PutPsz( qtu( option ),
                       qtu( it->data( HOTKEY_COL, Qt::UserRole ).toString() ) );

        config_PutPsz( qtu( "global-" + option ),
                       qtu( it->data( GLOBAL_HOTKEY_COL, Qt::UserRole ).toString() ) );
    }
}

bool KeySelectorControl::eventFilter( QObject *obj, QEvent *e )
{
    if( obj != table || e->type() != QEvent::KeyPress )
        return ConfigControl::eventFilter(obj, e);

    QKeyEvent *keyEv = static_cast<QKeyEvent*>(e);
    QTreeWidget *aTable = static_cast<QTreeWidget *>(obj);
    if( keyEv->key() == Qt::Key_Escape )
    {
        aTable->clearFocus();
        return true;
    }
    else if( keyEv->key() == Qt::Key_Return ||
             keyEv->key() == Qt::Key_Enter )
    {
        selectKey( aTable->currentItem(), aTable->currentColumn() );
        return true;
    }
    else if( keyEv->key() == Qt::Key_Delete )
    {
        if( aTable->currentColumn() != ACTION_COL )
        {
            aTable->currentItem()->setText( aTable->currentColumn(), NULL );
            aTable->currentItem()->setData( aTable->currentColumn(), Qt::UserRole, QVariant() );
        }
        return true;
    }
    else
        return false;
}


/**
 * Class KeyInputDialog
 **/
KeyInputDialog::KeyInputDialog( QTreeWidget *_table,
                                QTreeWidgetItem * _keyItem,
                                bool b_global ) :
                                QDialog( _table ), table( _table ), keyItem( _keyItem )
{
    setModal( true );
    conflicts = false;
    existingkeys = NULL;

    column = b_global ? KeySelectorControl::GLOBAL_HOTKEY_COL
                      : KeySelectorControl::HOTKEY_COL;

    setWindowTitle( b_global ? qtr( "Global Hotkey change" )
                             : qtr( "Hotkey change" ) );
    setWindowRole( "vlc-key-input" );

    QVBoxLayout *vLayout = new QVBoxLayout( this );
    selected = new QLabel( qtr( "Press the new key or combination for <b>%1</b>" )
                           .arg( keyItem->text( KeySelectorControl::ACTION_COL ) ) );
    vLayout->addWidget( selected , Qt::AlignCenter );

    warning = new QLabel;
    warning->hide();
    vLayout->insertWidget( 1, warning );

    QDialogButtonBox *buttonBox = new QDialogButtonBox;
    ok = new QPushButton( qtr("Assign") );
    QPushButton *cancel = new QPushButton( qtr("Cancel") );
    unset = new QPushButton( qtr("Unset") );
    buttonBox->addButton( ok, QDialogButtonBox::AcceptRole );
    buttonBox->addButton( unset, QDialogButtonBox::ActionRole );
    buttonBox->addButton( cancel, QDialogButtonBox::RejectRole );
    ok->setDefault( true );

    ok->setFocusPolicy(Qt::NoFocus);
    unset->setFocusPolicy(Qt::NoFocus);
    cancel->setFocusPolicy(Qt::NoFocus);

    vLayout->addWidget( buttonBox );
    ok->hide();

    CONNECT( buttonBox, accepted(), this, accept() );
    CONNECT( buttonBox, rejected(), this, reject() );
    BUTTONACT( unset, unsetAction() );
}

void KeyInputDialog::setExistingkeysSet( const QSet<QString> *keyset )
{
    existingkeys = keyset;
}

void KeyInputDialog::checkForConflicts( const QString &sequence )
{
    conflicts = false;
    if ( vlckey == "" )
    {
        accept();
        return;
    }

    for (QTreeWidgetItemIterator iter(table); *iter; ++iter)
    {
        QTreeWidgetItem *item = *iter;

        if( item == keyItem )
            continue;

        if( !item->data( column, Qt::UserRole ).toString().split( "\t" ).contains( vlckey ) )
            continue;

        warning->setText(
                qtr("Warning: this key or combination is already assigned to \"<b>%1</b>\"")
                .arg( item->text( KeySelectorControl::ACTION_COL ) ) );
        warning->show();
        ok->show();
        unset->hide();

        conflicts = true;
        return;
    }

    if( existingkeys && !sequence.isEmpty()
        && existingkeys->contains( sequence ) )
    {
        warning->setText(
            qtr( "Warning: <b>%1</b> is already an application menu shortcut" )
                    .arg( sequence )
        );
        warning->show();
        ok->show();
        unset->hide();

        conflicts = true;
    }
    else accept();
}

void KeyInputDialog::keyPressEvent( QKeyEvent *e )
{
    if( e->key() == Qt::Key_Tab ||
        e->key() == Qt::Key_Shift ||
        e->key() == Qt::Key_Control ||
        e->key() == Qt::Key_Meta ||
        e->key() == Qt::Key_Alt ||
        e->key() == Qt::Key_AltGr )
        return;
    int i_vlck = qtEventToVLCKey( e );
    QKeySequence sequence( e->key() | e->modifiers() );
    vlckey = VLCKeyToString( i_vlck, false );
    vlckey_tr = VLCKeyToString( i_vlck, true );
    selected->setText( qtr( "Key or combination: <b>%1</b>" ).arg( vlckey_tr ) );
    checkForConflicts( sequence.toString() );
}

void KeyInputDialog::wheelEvent( QWheelEvent *e )
{
    int i_vlck = qtWheelEventToVLCKey( *e );
    vlckey = VLCKeyToString( i_vlck, false );
    vlckey_tr = VLCKeyToString( i_vlck, true );
    selected->setText( qtr( "Key: <b>%1</b>" ).arg( vlckey_tr ) );
    checkForConflicts( QString() );
}

void KeyInputDialog::unsetAction() { done( 2 ); }
