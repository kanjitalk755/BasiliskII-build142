/*
 *  extfs_windows.cpp - MacOS file system for access native file system access, Windows specific stuff
 *
 *  Basilisk II (C) 1997-1999 Christian Bauer
 *
 *  Windows platform specific code copyright (C) Lauri Pesonen
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

#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
// #include <unistd.h>
// #include <dirent.h>
#include <errno.h>

#include "sysdeps.h"
#include "prefs.h"
#include "extfs.h"
#include "extfs_defs.h"
#include "posix_emu.h"
#include "typemap.h"

#define DEBUG 0
#include "debug.h"

// Default Finder flags
// const uint16 DEFAULT_FINDER_FLAGS = kHasBeenInited;
const uint16 DEFAULT_FINDER_FLAGS = 0;

bool m_use_ntfs_afp = false;

/*
 *  Initialization
 */

void extfs_init(void)
{
	// m_use_ntfs_afp = (win_os == VER_PLATFORM_WIN32_NT) && PrefsFindBool("usentfsafp");
	m_use_ntfs_afp = false;

	init_type_map(hInst);
	init_posix_emu();
}


/*
 *  Deinitialization
 */

void extfs_exit(void)
{
	final_posix_emu();
}


/*
 *  Add component to path name
 */

void add_path_component(char *path, const char *component)
{
	int l = strlen(path);
	if (l < MAX_PATH_LENGTH-1 && path[l-1] != HOST_DIR_CHAR) {
		path[l] = HOST_DIR_CHAR;
		path[l+1] = 0;
	}
	strncat(path, component, MAX_PATH_LENGTH-1);
}


/*
 *  Finder info and resource forks are kept in helper files
 *
 *  Finder info:
 *    /path/.finf/file
 *  Resource fork:
 *    /path/.rsrc/file
 */

// Layout of Finder info helper files (all fields big-endian)
/*
struct finf_struct {
	uint32 type;
	uint32 creator;
	uint16 flags;
	uint16 fldr;
	uint32 location;
	uint32 rect_lo;
	uint32 rect_hi;
	uint16 view;
	uint16 pad0;
};
*/

// foreign data, use byte struct packing
#pragma pack(1)
typedef int16 Integer;
typedef int32 LongInt;
typedef uint32 OSType;

typedef struct {
	Integer	top;
	Integer	left;
	Integer	bottom;
	Integer	right;
} Rect;

typedef struct {
	Rect frRect;
	Integer frFlags;
	LongInt frLocation;
	Integer frView;
} DInfo;

typedef struct {
	OSType fdType;
	OSType fdCreator;
	Integer fdFlags;
	LongInt fdLocation;
	Integer fdFldr;
} FInfo;

struct finf_struct {
	union {
		FInfo finfo;
		DInfo dinfo;
	};
};
#pragma pack()


static void init_finf_struct( finf_struct &finf )
{
	memset( &finf, 0, sizeof(finf) );
	finf.finfo.fdFlags = DEFAULT_FINDER_FLAGS;
}

static void make_helper_path(const char *src, char *dest, const char *add, bool only_dir = false)
{
	dest[0] = 0;

	// Get pointer to last component of path
	const char *last_part = strrchr(src, HOST_DIR_CHAR);
	if (last_part)
		last_part++;
	else
		last_part = src;

	// Copy everything before
	strncpy(dest, src, last_part-src);
	dest[last_part-src] = 0;

	// Add additional component
	strncat(dest, add, MAX_PATH_LENGTH-1);

	// Add last component
	if (!only_dir)
		strncat(dest, last_part, MAX_PATH_LENGTH-1);
}

static int create_helper_dir(const char *path, const char *add)
{
	char helper_dir[MAX_PATH_LENGTH];
	make_helper_path(path, helper_dir, add, true);
	return mkdir(helper_dir, 0777);
}

static int open_helper(const char *path, const char *add, int flag)
{
	char helper_path[MAX_PATH_LENGTH];
	make_helper_path(path, helper_path, add);

	// Christian: && -> &
	if ((flag & O_RDWR) || (flag & O_WRONLY))
		flag |= O_CREAT;
	int fd = open(helper_path, flag, 0666);
	if (fd < 0) {
		if (/*errno == ENOENT &&*/ (flag & O_CREAT)) {
			// One path component was missing, probably the helper
			// directory. Try to create it and re-open the file.
			int ret = create_helper_dir(path, add);
			if (ret < 0)
				return ret;
			fd = open(helper_path, flag, 0666);
		}
	}
	return fd;
}

static int open_finf(const char *path, int flag)
{
	return open_helper(path, ".finf\\", flag);
}

static int open_rsrc(const char *path, int flag)
{
	return open_helper(path, ".rsrc\\", flag);
}

void get_finf_path(const char *path,char *helper_path, bool create)
{
	make_helper_path(path, helper_path, ".finf\\");
	if(create && access(helper_path,F_OK) != 0) create_helper_dir(path, ".finf\\");
}

void get_rsrc_path(const char *path,char *helper_path, bool create)
{
	make_helper_path(path, helper_path, ".rsrc\\");
	if(create && access(helper_path,F_OK) != 0) create_helper_dir(path, ".rsrc\\");
}

/*
 *  Get/set finder type/creator for file specified by full path
 */

void get_finder_type(const char *path, uint32 &type, uint32 &creator)
{
	type = 0;
	creator = 0;

	// Open Finder info file
	int fd = open_finf(path, O_RDONLY);
	if (fd >= 0) {

		// Read file
		finf_struct finf;
		if (read(fd, &finf, sizeof(finf_struct)) == sizeof(finf_struct)) {

			// Type/creator are in Finder info file, return them
			type = ntohl(finf.finfo.fdType);
			creator = ntohl(finf.finfo.fdCreator);
			close(fd);
			return;
		}
		close(fd);
	}

	// No Finder info file, translate file name extension to MacOS type/creator
	int path_len = strlen(path);
	for (int i=0; e2t_translation[i].ext; i++) {
		int ext_len = strlen(e2t_translation[i].ext);
		if (path_len < ext_len)
			continue;
		if (!stricmp(path + path_len - ext_len, e2t_translation[i].ext)) {
			type = e2t_translation[i].type;
			creator = e2t_translation[i].creator;
			break;
		}
	}
}

void set_finder_type(const char *path, uint32 type, uint32 creator)
{
	// Open Finder info file
	int fd = open_finf(path, O_RDWR);
	if (fd < 0)
		return;

	// Read file
	finf_struct finf;
	init_finf_struct( finf );
	read(fd, &finf, sizeof(finf_struct));

	// Set Finder flags
	finf.finfo.fdType = htonl(type);
	finf.finfo.fdCreator = htonl(creator);

	// Update file
	lseek(fd, 0, SEEK_SET);
	write(fd, &finf, sizeof(finf_struct));
	close(fd);
}

void get_finder_location(const char *path, uint32 &location)
{
	location = 0;

	// Open Finder info file
	int fd = open_finf(path, O_RDONLY);
	if (fd >= 0) {

		// Read file
		finf_struct finf;
		if (read(fd, &finf, sizeof(finf_struct)) == sizeof(finf_struct)) {

			// Location is in Finder info file, return them
			location = ntohl(finf.finfo.fdLocation);
			close(fd);
			return;
		}
		close(fd);
	}
}

void set_finder_location(const char *path, uint32 location)
{
	// Open Finder info file
	int fd = open_finf(path, O_RDWR);
	if (fd < 0)
		return;

	// Read file
	finf_struct finf;
	init_finf_struct( finf );
	read(fd, &finf, sizeof(finf_struct));

	// Set Finder location
	finf.finfo.fdLocation = htonl(location);

	// Update file
	lseek(fd, 0, SEEK_SET);
	write(fd, &finf, sizeof(finf_struct));
	close(fd);
}

void get_finder_fldr(const char *path, uint16 &fldr)
{
	fldr = 0;

	// Open Finder info file
	int fd = open_finf(path, O_RDONLY);
	if (fd >= 0) {

		// Read file
		finf_struct finf;
		if (read(fd, &finf, sizeof(finf_struct)) == sizeof(finf_struct)) {

			// fldr is in Finder info file, return them
			fldr = ntohs(finf.finfo.fdFldr);
			close(fd);
			return;
		}
		close(fd);
	}
}

void set_finder_fldr(const char *path, uint16 fldr)
{
	// Open Finder info file
	int fd = open_finf(path, O_RDWR);
	if (fd < 0)
		return;

	// Read file
	finf_struct finf;
	init_finf_struct( finf );
	read(fd, &finf, sizeof(finf_struct));

	// Set Finder fldr
	finf.finfo.fdFldr = htons(fldr);

	// Update file
	lseek(fd, 0, SEEK_SET);
	write(fd, &finf, sizeof(finf_struct));
	close(fd);
}

/*
 *  Get/set finder flags for file/dir specified by full path
 */

void get_finder_flags(const char *path, uint16 &flags)
{
	flags = DEFAULT_FINDER_FLAGS;	// Default

	// Open Finder info file
	int fd = open_finf(path, O_RDONLY);
	if (fd < 0)
		return;

	// Read Finder flags
	finf_struct finf;
	if (read(fd, &finf, sizeof(finf_struct)) == sizeof(finf_struct))
		flags = ntohs(finf.finfo.fdFlags);

	// Close file
	close(fd);
}

void set_finder_flags(const char *path, uint16 flags)
{
	// Open Finder info file
	int fd = open_finf(path, O_RDWR);
	if (fd < 0)
		return;

	// Read file
	finf_struct finf;
	init_finf_struct( finf );
	read(fd, &finf, sizeof(finf_struct));

	// Set Finder flags
	finf.finfo.fdFlags = htons(flags);

	// Update file
	lseek(fd, 0, SEEK_SET);
	write(fd, &finf, sizeof(finf_struct));
	close(fd);
}

extern void get_finder_rect(const char *path, uint32 &rect_lo, uint32 &rect_hi)
{
	rect_lo = rect_hi = 0;

	// Open Finder info file
	int fd = open_finf(path, O_RDONLY);
	if (fd < 0)
		return;

	// Read Finder flags
	finf_struct finf;
	if (read(fd, &finf, sizeof(finf_struct)) == sizeof(finf_struct)) {
		rect_lo = ntohl(*(uint32*)&finf.dinfo.frRect.top);
		rect_hi = ntohl(*(uint32*)&finf.dinfo.frRect.bottom);
	}

	// Close file
	close(fd);
}

extern void set_finder_rect(const char *path, uint32 rect_lo, uint32 rect_hi)
{
	// Open Finder info file
	int fd = open_finf(path, O_RDWR);
	if (fd < 0)
		return;

	// Read file
	finf_struct finf;
	init_finf_struct( finf );
	read(fd, &finf, sizeof(finf_struct));

	// Set Finder rect
	*(uint32*)&finf.dinfo.frRect.top = htonl(rect_lo);
	*(uint32*)&finf.dinfo.frRect.bottom = htonl(rect_hi);

	// Update file
	lseek(fd, 0, SEEK_SET);
	write(fd, &finf, sizeof(finf_struct));
	close(fd);
}

extern void get_finder_view(const char *path, uint16 &view)
{
	view = 0;

	// Open Finder info file
	int fd = open_finf(path, O_RDONLY);
	if (fd < 0)
		return;

	// Read Finder view
	finf_struct finf;
	if (read(fd, &finf, sizeof(finf_struct)) == sizeof(finf_struct)) {
		view = ntohs(finf.dinfo.frView);
	}

	// Close file
	close(fd);
}

extern void set_finder_view(const char *path, uint16 view)
{
	// Open Finder info file
	int fd = open_finf(path, O_RDWR);
	if (fd < 0)
		return;

	// Read file
	finf_struct finf;
	init_finf_struct( finf );
	read(fd, &finf, sizeof(finf_struct));

	// Set Finder view
	finf.dinfo.frView = htons(view);

	// Update file
	lseek(fd, 0, SEEK_SET);
	write(fd, &finf, sizeof(finf_struct));
	close(fd);
}

/*
 *  Resource fork emulation functions
 */

uint32 get_rfork_size(const char *path)
{
	// Open resource file
	int fd = open_rsrc(path, O_RDONLY);
	if (fd < 0)
		return 0;

	// Get size
	off_t size = lseek(fd, 0, SEEK_END);

	// Close file and return size
	close(fd);
	return size < 0 ? 0 : size;
}

int open_rfork(const char *path, int flag)
{
	return open_rsrc(path, flag);
}

void close_rfork(const char *path, int fd)
{
	if(fd >= 0) close(fd);
}


/*
 *  Read "length" bytes from file to "buffer",
 *  returns number of bytes read (or 0)
 */

size_t extfs_read(int fd, void *buffer, size_t length)
{
	return read(fd, buffer, length);
}


/*
 *  Write "length" bytes from "buffer" to file,
 *  returns number of bytes written (or 0)
 */

size_t extfs_write(int fd, void *buffer, size_t length)
{
	return write(fd, buffer, length);
}
