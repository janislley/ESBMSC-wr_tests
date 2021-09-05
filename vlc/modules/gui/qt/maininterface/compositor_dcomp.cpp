/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "compositor_dcomp.hpp"

#include "maininterface/main_interface_win32.hpp"

#include <comdef.h>

#include <QApplication>
#include <QDesktopWidget>
#include <QQuickWidget>

#include <QOpenGLFunctions>
#include <QOpenGLFramebufferObject>
#include <QOpenGLExtraFunctions>

#include <qpa/qplatformnativeinterface.h>
#include "compositor_dcomp_error.hpp"
#include "maininterface/interface_window_handler.hpp"

namespace vlc {

using namespace Microsoft::WRL;

//Signature for DCompositionCreateDevice
typedef HRESULT (*DCompositionCreateDeviceFun)(IDXGIDevice *dxgiDevice, REFIID iid, void** dcompositionDevice);

int CompositorDirectComposition::window_enable(struct vout_window_t * p_wnd, const vout_window_cfg_t *)
{
    CompositorDirectComposition* that = static_cast<CompositorDirectComposition*>(p_wnd->sys);
    msg_Dbg(that->m_intf, "window_enable");
    if (!that->m_videoVisual)
    {
        msg_Err(that->m_intf, "m_videoVisual is null");
        return VLC_EGENERIC;
    }

    try
    {
        that->m_qmlVideoSurfaceProvider->enable(p_wnd);
        that->m_qmlVideoSurfaceProvider->setVideoEmbed(true);
        HR(that->m_rootVisual->AddVisual(that->m_videoVisual.Get(), FALSE, that->m_uiVisual.Get()), "add video visual to root");
        HR(that->m_dcompDevice->Commit(), "commit");
    }
    catch (const DXError& err)
    {
        msg_Err(that->m_intf, "failed to enable window: %s code 0x%lX", err.what(), err.code());
        return VLC_EGENERIC;
    }
    return VLC_SUCCESS;
}

void CompositorDirectComposition::window_disable(struct vout_window_t * p_wnd)
{
    CompositorDirectComposition* that = static_cast<CompositorDirectComposition*>(p_wnd->sys);
    try
    {
        that->m_qmlVideoSurfaceProvider->setVideoEmbed(false);
        that->m_qmlVideoSurfaceProvider->disable();
        that->m_videoWindowHandler->disable();
        msg_Dbg(that->m_intf, "window_disable");
        HR(that->m_rootVisual->RemoveVisual(that->m_videoVisual.Get()), "remove video visual from root");
        HR(that->m_dcompDevice->Commit(), "commit");
    }
    catch (const DXError& err)
    {
        msg_Err(that->m_intf, "failed to disable window: '%s' code: 0x%lX", err.what(), err.code());
    }
}

void CompositorDirectComposition::window_resize(struct vout_window_t * p_wnd, unsigned width, unsigned height)
{
    CompositorDirectComposition* that = static_cast<CompositorDirectComposition*>(p_wnd->sys);
    msg_Dbg(that->m_intf, "window_resize %ux%u", width, height);
    that->m_videoWindowHandler->requestResizeVideo(width, height);
}

void CompositorDirectComposition::window_destroy(struct vout_window_t * p_wnd)
{
    CompositorDirectComposition* that = static_cast<CompositorDirectComposition*>(p_wnd->sys);
    msg_Dbg(that->m_intf, "window_destroy");
    that->m_window = nullptr;
    that->m_videoVisual.Reset();
    that->onWindowDestruction(p_wnd);
}

void CompositorDirectComposition::window_set_state(struct vout_window_t * p_wnd, unsigned state)
{
    CompositorDirectComposition* that = static_cast<CompositorDirectComposition*>(p_wnd->sys);
    msg_Dbg(that->m_intf, "window_set_state");
    that->m_videoWindowHandler->requestVideoState(static_cast<vout_window_state>(state));
}

void CompositorDirectComposition::window_unset_fullscreen(struct vout_window_t * p_wnd)
{
    CompositorDirectComposition* that = static_cast<CompositorDirectComposition*>(p_wnd->sys);
    msg_Dbg(that->m_intf, "window_unset_fullscreen");
    that->m_videoWindowHandler->requestVideoWindowed();
}

void CompositorDirectComposition::window_set_fullscreen(struct vout_window_t * p_wnd, const char *id)
{
    CompositorDirectComposition* that = static_cast<CompositorDirectComposition*>(p_wnd->sys);
    msg_Dbg(that->m_intf, "window_set_fullscreen");
    that->m_videoWindowHandler->requestVideoFullScreen(id);
}

CompositorDirectComposition::CompositorDirectComposition( qt_intf_t* p_intf,  QObject *parent)
    : QObject(parent)
    , m_intf(p_intf)
{
}

CompositorDirectComposition::~CompositorDirectComposition()
{
    destroyMainInterface();
    m_dcompDevice.Reset();
    m_d3d11Device.Reset();
    if (m_dcomp_dll)
        FreeLibrary(m_dcomp_dll);
}

bool CompositorDirectComposition::init()
{
    //import DirectComposition API (WIN8+)
    m_dcomp_dll = LoadLibrary(TEXT("DCOMP.dll"));
    if (!m_dcomp_dll)
        return false;
    DCompositionCreateDeviceFun myDCompositionCreateDevice = (DCompositionCreateDeviceFun)GetProcAddress(m_dcomp_dll, "DCompositionCreateDevice");
    if (!myDCompositionCreateDevice)
    {
        FreeLibrary(m_dcomp_dll);
        m_dcomp_dll = nullptr;
        return false;
    }

    HRESULT hr;
    UINT creationFlags = D3D11_CREATE_DEVICE_BGRA_SUPPORT
        //| D3D11_CREATE_DEVICE_DEBUG
            ;

    D3D_FEATURE_LEVEL requestedFeatureLevels[] = {
        D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0,
    };

    hr = D3D11CreateDevice(
        nullptr,    // Adapter
        D3D_DRIVER_TYPE_HARDWARE,
        nullptr,    // Module
        creationFlags,
        requestedFeatureLevels,
        ARRAY_SIZE(requestedFeatureLevels),
        D3D11_SDK_VERSION,
        m_d3d11Device.GetAddressOf(),
        nullptr,    // Actual feature level
        nullptr);

    if (FAILED(hr))
        return false;

    ComPtr<IDXGIDevice> dxgiDevice;
    m_d3d11Device.As(&dxgiDevice);

    // Create the DirectComposition device object.
    hr = myDCompositionCreateDevice(dxgiDevice.Get(), __uuidof(IDCompositionDevice), &m_dcompDevice);
    if (FAILED(hr))
        return false;

    QApplication::setAttribute( Qt::AA_UseOpenGLES ); //force usage of ANGLE backend

    return true;
}

MainInterface* CompositorDirectComposition::makeMainInterface()
{
    try
    {
        bool ret;
        m_rootWindow = new MainInterfaceWin32(m_intf);
        m_rootWindow->setAttribute(Qt::WA_NativeWindow);
        m_rootWindow->setAttribute(Qt::WA_DontCreateNativeAncestors);
        m_rootWindow->setAttribute(Qt::WA_TranslucentBackground);

        m_rootWindow->winId();
        m_rootWindow->show();

        WinTaskbarWidget* taskbarWidget = new WinTaskbarWidget(m_intf, m_rootWindow->windowHandle(), this);
        qApp->installNativeEventFilter(taskbarWidget);

        m_videoWindowHandler = std::make_unique<VideoWindowHandler>(m_intf, m_rootWindow);
        m_videoWindowHandler->setWindow( m_rootWindow->windowHandle() );

        HR(m_dcompDevice->CreateTargetForHwnd((HWND)m_rootWindow->windowHandle()->winId(), TRUE, &m_dcompTarget), "create target");
        HR(m_dcompDevice->CreateVisual(&m_rootVisual), "create root visual");
        HR(m_dcompTarget->SetRoot(m_rootVisual.Get()), "set root visual");

        HR(m_dcompDevice->CreateVisual(&m_uiVisual), "create ui visual");

        m_uiSurface  = std::make_unique<CompositorDCompositionUISurface>(m_intf,
                                                                         m_rootWindow->windowHandle(),
                                                                         m_uiVisual);
        ret = m_uiSurface->init();
        if (!ret)
        {
            destroyMainInterface();
            return nullptr;
        }

        //install the interface window handler after the creation of CompositorDCompositionUISurface
        //so the event filter is handled before the one of the UISurface (for wheel events)
        m_interfaceWindowHandler = new InterfaceWindowHandlerWin32(m_intf, m_rootWindow, m_rootWindow->window()->windowHandle(), m_rootWindow);

        m_qmlVideoSurfaceProvider = std::make_unique<VideoSurfaceProvider>();
        m_rootWindow->setVideoSurfaceProvider(m_qmlVideoSurfaceProvider.get());
        m_rootWindow->setCanShowVideoPIP(true);

        connect(m_qmlVideoSurfaceProvider.get(), &VideoSurfaceProvider::hasVideoEmbedChanged,
                m_interfaceWindowHandler, &InterfaceWindowHandlerWin32::onVideoEmbedChanged);
        connect(m_qmlVideoSurfaceProvider.get(), &VideoSurfaceProvider::surfacePositionChanged,
                this, &CompositorDirectComposition::onSurfacePositionChanged);

        connect(m_rootWindow, &MainInterface::requestInterfaceMaximized,
                m_rootWindow, &MainInterface::showMaximized);
        connect(m_rootWindow, &MainInterface::requestInterfaceNormal,
                m_rootWindow, &MainInterface::showNormal);

        m_ui = std::make_unique<MainUI>(m_intf, m_rootWindow, m_rootWindow->windowHandle());
        ret = m_ui->setup(m_uiSurface->engine());
        if (! ret)
        {
            destroyMainInterface();
            return nullptr;
        }
        m_uiSurface->setContent(m_ui->getComponent(), m_ui->createRootItem());
        HR(m_rootVisual->AddVisual(m_uiVisual.Get(), FALSE, nullptr), "add ui visual to root");
        HR(m_dcompDevice->Commit(), "commit UI visual");
        return m_rootWindow;
    }
    catch (const DXError& err)
    {
        msg_Err(m_intf, "failed to initialise compositor: '%s' code: 0x%lX", err.what(), err.code());
        destroyMainInterface();
        return nullptr;
    }
}

void CompositorDirectComposition::onSurfacePositionChanged(QPointF position)
{
    HR(m_videoVisual->SetOffsetX(position.x()));
    HR(m_videoVisual->SetOffsetY(position.y()));
    HR(m_dcompDevice->Commit(), "commit UI visual");
}

void CompositorDirectComposition::destroyMainInterface()
{
    if (m_videoVisual)
        msg_Err(m_intf, "video surface still active while destroying main interface");

    unloadGUI();

    m_rootVisual.Reset();
    m_dcompTarget.Reset();
    m_qmlVideoSurfaceProvider.reset();
    if (m_rootWindow)
    {
        delete m_rootWindow;
        m_rootWindow = nullptr;
    }
}

void CompositorDirectComposition::unloadGUI()

{
    if (m_uiVisual)
    {
        m_rootVisual->RemoveVisual(m_uiVisual.Get());
        m_uiVisual.Reset();
    }
    m_uiSurface.reset();
    m_ui.reset();
}

bool CompositorDirectComposition::setupVoutWindow(vout_window_t *p_wnd, VoutDestroyCb destroyCb)
{
    m_destroyCb = destroyCb;

    //Only the first video is embedded
    if (m_videoVisual.Get())
        return false;

    HRESULT hr = m_dcompDevice->CreateVisual(&m_videoVisual);
    if (FAILED(hr))
    {
        msg_Err(p_wnd, "create to create DComp video visual");
        return false;
    }

    static const struct vout_window_operations ops = {
        CompositorDirectComposition::window_enable,
        CompositorDirectComposition::window_disable,
        CompositorDirectComposition::window_resize,
        CompositorDirectComposition::window_destroy,
        CompositorDirectComposition::window_set_state,
        CompositorDirectComposition::window_unset_fullscreen,
        CompositorDirectComposition::window_set_fullscreen,
        nullptr, //window_set_title
    };
    p_wnd->sys = this;
    p_wnd->type = VOUT_WINDOW_TYPE_DCOMP;
    p_wnd->display.dcomp_device = m_dcompDevice.Get();
    p_wnd->handle.dcomp_visual = m_videoVisual.Get();
    p_wnd->ops = &ops;
    p_wnd->info.has_double_click = true;
    m_window = p_wnd;
    return true;
}

Compositor::Type CompositorDirectComposition::type() const
{
    return Compositor::DirectCompositionCompositor;
}

}
