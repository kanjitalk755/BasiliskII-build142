/*
 *  scsi_windows.h
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

#define VENDOR_LEN 8
#define PRODUCT_LEN 16
#define MAX_SCSI_NAME (VENDOR_LEN+PRODUCT_LEN+10)
#define MAX_SCSI_NAMES 100
extern int all_scsi_count;
extern char all_scsi_names[MAX_SCSI_NAMES][MAX_SCSI_NAME];
extern DWORD all_scsi_types[MAX_SCSI_NAMES];

void SCSI_set_buffer_alloc( bool alloc_buffer );
