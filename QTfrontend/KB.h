/*
 * Hedgewars, a free turn based strategy game
 * Copyright (c) 2006-2010 Andrey Korotaev <unC0Rr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */

#ifndef KB_H
#define KB_H

#include <QString>

const ulong KBmsgsCount = 1;

const QString KBMessages[KBmsgsCount] =
{
    QT_TRANSLATE_NOOP("KB", "SDL_ttf returned error while rendering text, "
                            "most propably it is related to the bug "
                            "in freetype2. It's recommended to update your "
                            "freetype lib.")
};

#endif // KB_H