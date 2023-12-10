/*
 *  extfs.h - MacOS file system for access native file system access
 *
 *  Basilisk II (C) 1997-1999 Christian Bauer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef EXTFS_H
#define EXTFS_H

extern void ExtFSInit(void);
extern void ExtFSExit(void);

extern void InstallExtFS(void);

extern int16 ExtFSComm(uint16 message, uint32 paramBlock, uint32 globalsPtr);
extern int16 ExtFSHFS(uint32 vcb, uint16 selectCode, uint32 paramBlock, uint32 globalsPtr, int16 fsid);

// System specific and internal functions/data
extern void extfs_init(void);
extern void extfs_exit(void);
extern void add_path_component(char *path, const char *component);
extern void get_finder_type(const char *path, uint32 &type, uint32 &creator);
extern void set_finder_type(const char *path, uint32 type, uint32 creator);
extern void get_finder_flags(const char *path, uint16 &flags);
extern void set_finder_flags(const char *path, uint16 flags);
extern void get_finder_location(const char *path, uint32 &location);
extern void set_finder_location(const char *path, uint32 location);
extern void get_finder_fldr(const char *path, uint16 &fldr);
extern void set_finder_fldr(const char *path, uint16 fldr);
extern void get_finder_rect(const char *path, uint32 &rect_lo, uint32 &rect_hi);
extern void set_finder_rect(const char *path, uint32 rect_lo, uint32 rect_hi);
extern void get_finder_view(const char *path, uint16 &view);
extern void set_finder_view(const char *path, uint16 view);
extern uint32 get_rfork_size(const char *path);
extern int open_rfork(const char *path, int flag);
extern void close_rfork(const char *path, int fd);
extern size_t extfs_read(int fd, void *buffer, size_t length);
extern size_t extfs_write(int fd, void *buffer, size_t length);

// Maximum length of full path name
const int MAX_PATH_LENGTH = 1024;

extern void get_finf_path(const char *path,char *helper_path, bool create);
extern void get_rsrc_path(const char *path,char *helper_path, bool create);

#define HOST_DIR_CHAR '\\'
// #define HOST_DIR_CHAR '/'

#endif
