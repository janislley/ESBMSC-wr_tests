/* 5views.h
 *
 * Wiretap Library
 * Copyright (c) 1998 by Gilbert Ramirez <gram@alumni.rice.edu>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef __5VIEWS_H__
#define __5VIEWS_H__
#include <glib.h>
#include "wtap.h"

wtap_open_return_val _5views_open(wtap *wth, int *err, gchar **err_info);

#endif
