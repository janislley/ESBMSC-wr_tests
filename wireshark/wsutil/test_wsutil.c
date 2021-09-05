/*
 * Wireshark - Network traffic analyzer
 * By Gerald Combs <gerald@wireshark.org>
 * Copyright 1998 Gerald Combs
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "config.h"

#include <stdio.h>
#include <glib.h>
#include <wsutil/utf8_entities.h>

#include "str_util.h"


void test_format_size(void)
{
    char *str;

    str = format_size(10000, format_size_unit_bytes);
    g_assert_cmpstr(str, ==, "10 kB");
    g_free(str);

    str = format_size(100000, format_size_unit_bytes|format_size_prefix_iec);
    g_assert_cmpstr(str, ==, "97 KiB");
    g_free(str);

    str = format_size(20971520, format_size_unit_bits|format_size_prefix_iec);
    g_assert_cmpstr(str, ==, "20 Mib");
    g_free(str);
}

#include "to_str.h"

void test_bytes_to_str(void)
{
    char *str;

    const guint8 buf[] = { 1, 2, 3};

    str = bytes_to_str(NULL, buf, sizeof(buf));
    g_assert_cmpstr(str, ==, "010203");
    g_free(str);
}

void test_bytes_to_str_punct(void)
{
    char *str;

    const guint8 buf[] = { 1, 2, 3};

    str = bytes_to_str_punct(NULL, buf, sizeof(buf), ':');
    g_assert_cmpstr(str, ==, "01:02:03");
    g_free(str);
}

void test_bytes_to_string_trunc1(void)
{
    char *str;

    const guint8 buf[] = {
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA,
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA,
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA,
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA,
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA,
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA,
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA
    };
    const char *expect =
        "112233445566778899aa"
        "112233445566778899aa"
        "112233445566778899aa"
        "112233445566" UTF8_HORIZONTAL_ELLIPSIS;

    str = bytes_to_str(NULL, buf, sizeof(buf));
    g_assert_cmpstr(str, ==, expect);
    g_free(str);
}

int main(int argc, char **argv)
{
    int ret;

    g_test_init(&argc, &argv, NULL);

    g_test_add_func("/str_util/format_size", test_format_size);

    g_test_add_func("/to_str/bytes_to_str", test_bytes_to_str);
    g_test_add_func("/to_str/bytes_to_str_punct", test_bytes_to_str_punct);
    g_test_add_func("/to_str/bytes_to_str_trunc1", test_bytes_to_string_trunc1);

    ret = g_test_run();

    return ret;
}

/*
 * Editor modelines  -  https://www.wireshark.org/tools/modelines.html
 *
 * Local variables:
 * c-basic-offset: 4
 * tab-width: 8
 * indent-tabs-mode: nil
 * End:
 *
 * vi: set shiftwidth=4 tabstop=8 expandtab:
 * :indentSize=4:tabSize=8:noTabs=true:
 */
