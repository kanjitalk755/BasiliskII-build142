Basilisk II for Windows NT and Windows 2000 Professional.

A free, portable Mac II emulator.

Copyright (C) 1997-2001 Christian Bauer et al.
UAE CPU emulation code copyright (C) Bernd Schmidt.
Windows specific code copyright by (C) Lauri Pesonen.

Freely distributable.


These are just quick notes describing the differences
to the other Basilisk II ports. Please read the other 
Basilisk II documentation first to get a general idea 
of the emulator.


Overview
--------

A port of Christian Bauer's Basilisk II Macintosh II emulator
for Windows 2000 Professional (later Win2k) Windows NT 4.0
(later NT4).

For DirectX support under Windows NT 4.0, service pack 3
or later is required.

Versions of Windows 2000 professional RC2 or later are supported.

Windows 95 and Windows 98 (later Win9x) can be used too, 
with a somewhat reduced set of features.

A list of features of Basilisk II for NT4 and Win9x follows.

  - Runs MacOS 7.x, 8.0 and 8.1 (7.0 not recommended).
  - FPU is enabled by default (but can be disabled if needed).
  - Processor is either 68020 68030 or 68040 with some limitations.
  - Color video 1, 2, 4, 8, 15, 16, 24 and 32 bits. Uses the
    Windows "Display Control Panel" video mode setting,
    which can be overridden by the "screen" command.
    Depending on you display adapter, some options may work
    incorrectly or not at all.
  - Floppy disk driver (only 1.44MB disks supported)
  - Driver for HFS and FAT partitions
  - Driver for HFS physical drives
  - Driver for HFS hard files 
  - CD-ROM driver 
  - CD-ROM audio functions (Win2k and NT4). Note that this limitation
    does not apply if you use a SCSI CD-ROM and not the emulated
    CD-ROM implementation.
  - Serial driver
  - SCSI Manager
  - SCSI device remapping
  - Emulates extended ADB keyboard and 1-button mouse.
  - Uses UAE 68k emulation
  - Mac clipboard text transfer to Windows
  - If the program freezes, you can try to kill it with
    Alt-F4. Normally you should not quit this way to
    avoid losing data (MacOS may not have saved all your
    data when you kill the program).
  - DirectX support
  - Non-refreshed linear frame buffer support (Win2k and NT4)
  - Ethernet driver
  - Easy file exchange with the host OS via a "My Computer" icon
    on the Mac desktop



Installation
------------

Copy the files "BasiliskII.exe" and "BasiliskIIGUI.exe" to a directory 
of your choice.

Under Win2k or NT4, delete BasiliskII.exe and rename
BasiliskIINT.exe to be BasiliskII.exe.

Boot your (real) Macintosh with extensions off (hold the shift key down)
and run the GetROM utility. Put the created "ROM" file into the same directory
where you placed other Basilisk II executable files.

To access CD-ROM's under Win2k and NT4, the driver file "cdenable.sys"
must be moved to your "\WinNT\System32\drivers" directory.

To access CD-ROM's and Zip media under Win9x, the driver file
"cdenable.vxd" must be moved to your "\Windows\System" directory.

The files B2WIN32.DLL and B2WIN16.DLL are only needed under Win9x
to access CD-ROM's using real mode (config.sys) drivers.
Under WinNT/Win2k, these files can be deleted.

Install the ethernet drivers as described in "Ethernet.win32.txt".

Run "BasiliskIIGUI.exe", and check all the pages to suit to your
needs. At a minimum, you need to define the location of your ROM
file, and the location of at least one bootable volume file
(or floppy or cd).

Launch "BasiliskII.exe".

IMPORTANT: see also the chapter "Keyboard".

A preferences file "BasiliskII_prefs" was written to the
startup directory. This is where most of the preferences
are kept. Using "BasiliskIIGUI" application, you should not
need to manually edit this file. However, you can do so any
time if you wish. It is a plain text file and your
favorite text editor is probably ok (Notepad is just fine).



Getting the ROM image
---------------------

The distribution archive contains two files, "GetROM.sit.hqx"
and "GetROM.sea.hqx" which both contain the same ROM grabbing
utility program. Expand one of them on your 68k Macintosh
and read the included readme file for details.


Configuration
-------------

The configuration file "BasiliskII_prefs" must be in
the working directory. If no preferences file is present, 
Basilisk II will create one with the default settings upon startup.
Alternatively, you can use a different preferences file by specifying
the name in the command line or shortcut properties:

BasiliskII.exe <path to prefs file>

disk <volume description>
  Example on how to define a hard file:
  
  disk c:\hardfiles\sys755.hfv

  Example on how to define a logical volume:
   
  disk c:\

  Example on how to define a physical volume under Win2k and NT4 (x=0,1, ...):
  disk \\.\PHYSICALDRIVEx

  if not defined, the files *.hfv and *.dsk is searched
  from the current directory. Note that in this case,
  the program tries to boot from the first volume file
  found which is random, and may not be the one you want.

  Iomega ZIP disks may be mounted either with the disk
  command, or installing the IomegaWare on the Mac.
  Do *not* use both ways simultaneously. 

  To mount a volume file read-only, precede the name with string "/RO":

  disk /RO c:\hardfiles\sys755.hfv

  To mount a partition (or a physical drive under NT) read/write,
  precede the name with string "/RW":

  disk /RW c:\

  If there is any file open in partition or the drive, a warning
  is issued and it will be mounted as read-only. This feature
  protects your Windows partition, the partition where you have
  the page file, and all other partitions with open files (and
  open directory handles under NT).

  Be *extremely* careful when using read/write partitions. PC Exchange
  bugs may CORRUPT YOUR DATA. Whenever in doubt, do *not* use the
  read/write mounting. It may be a good idea to create a small partition
  (the smaller the better) to be used only for file transfers.
  NEVER mount a partition that contains valuable data.


bootdrive <drive number>
  as in other ports


bootdriver <driver number>
  as in other ports


ramsize 75000000
  as in other ports. Aligns the value to 4 MB boundaries.


frameskip <frames to skip>
  ignored.


modelid <MacOS model ID>
  as in other ports


nogui <"true" or "false">
  ignored. GUI is a separate program, BasiliskIIGUI.exe.
  You can use this program to set up your Basilisk II without
  manually editing the preferences file.


seriala <serial port description>
  The port may be either COMx, LPTx or FILE, where x is a small
  integer (1..) referring to the device. If the device is connected
  to a FILE, all output is directed to a file named "C:\B2TEMP.OUT".
  This path may be configurable in the future.

  To use com port 1 as a Mac modem port:
  seriala COM1


serialb <serial port description>
  To use com port 2 as a Mac printer port:
  serialb COM2


nocdrom <"true" or "false">
  as in other ports
  
  
cdrom <CD-ROM drive description>

  cdrom v:\
  
  if not defined, the CD-ROM drives are detected automatically.


floppy <floppy drive description>

  floppy a:\
  
  if not defined, the floppy drives are
  detected automatically
  
  To change a floppy disk, drag and drop it to the
  wastebasket. Remove the disk from the drive.
  After inserting a new disk, press Control-Shift-F11
  and the program will mount the new disk.


scsi0 <SCSI target> ... scsi6 <SCSI target>
  <SCSI target> is: <"Vendor"> <"Model">

  scsi0 "HP" "CD-Writer+ 7100"
  
  Note the use of quotes.


screen <video mode>/<width>/<height>/<bits per pixel>
  video mode may be either "win", "dx", "dxwin" or "fb".

  "win" is a refreshed screen mode that uses Windows GDI calls to 
  write to the screen. You may have other windows on top of Basilisk II.

  "dx" is a refreshed DirectX full-screen mode. "dxwin" is a refreshed
  DirectX mode in a window.

  "fb" is a non-refreshed video mode that works only on NT.
  It accesses the linear frame buffer directly. 
  Use the hotkey Control-Shift-F12 to switch between Windows and Mac.
  Fast task switch (Alt-tab) and Explorer start menu (Control-escape)
  are disabled, control-alt-del is enabled. If the program crashes so
  badly that even alt-f4 doesn't work, use control-alt-del
  to log off and back on again.

  <width> and <height> can be either zeroes (uses current screen values),
  or something else. "win" mode can use almost anything, for other modes
  there must be a corresponding DirectX mode.

  <bits> is ignored for windowed "dx" mode. It uses always current screen values,
  those defined in the Windows Control Panel.

  If the mode is "win" and the dimensions are different than the desktop
  dimensions, windowed mode is used. The window can be moved around by
  dragging with the right mouse button. This mode remembers window positions 
  separately for different dimensions

  The supported values are 8,15,16,24,32. It is possible that some of them
  do not work for you. In particular, it may be that only one of the
  two modes, 15 and 16, is suitable for your card. You need to find out
  the best solution by experimenting.

  Since this option grabs the Win16Lock for an extended period of time, 
  it would instantly hang the system if attempted under Win9x, 
  and is therefore disabled (it silently falls back to the Direct X mode).
  It also creates a new desktop which is supported only on NT.

  To use windowed mode (for example):

  screen dx/800/0

  To use DirectX mode (for example):

  screen dx/1024/768/8

  To use linear frame buffer mode (for example):

  screen fb/0/0/16

  You can freely task switch with Alt-Tab between BasiliskII and other
  application. When you switch out, BasiliskII is put into a "snooze" 
  mode; that is, it uses less processor time but still keeps processing 
  possible background tasks. Normal operation is resumed when the 
  BasiliskII window is reactivated.

  If you have a fast display adapter, don't expect to get a huge 
  performance boost using dx or fb. The screen updates are usually
  not the performance bottleneck anymore (moving the data in the 68020
  code is).

  See "Keyboard" section on how to switch between display modes
  when Basilisk II is running.


rom <ROM file path>
  as in other ports


ether9x <driver name>
  Windows 9x ethernet driver name, set by the GUI program.
  Please consult to the document "Ethernet.win32.txt" for details.

  To find out the name manually, start "RegEdit" and browse to
  HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Class\Net.
  There are subkeys like "0000", "0001" etc depending how many
  NICs you have. Examine the subkeys, they have entries like (say)
    "DeviceVxDs"="w940nd.sys"
  The string "w940nd" is what you're looking for.
  Ignore entries that have value "pppmac.vxd".


ethernt <driver name>
  Windows NT ethernet driver name, set by the GUI program.
  Please consult to the document "Ethernet.win32.txt" for details.

  To find out the name manually, start "RegEdit" and browse to
  HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\B2Ether\Linkage.
  Double-click the "Export" value. There is a string like
  "\Device\B2Ether_W30NT1". In this case, the <driver name> would
  be "W30NT1" (without quotes).


ethernt5 <driver name>
  Windows 2000 Professional ethernet driver name (GUID), set by the GUI
  program. Please consult to the document "Ethernet.win32.txt" for details.


etherpermanentaddress <"true" or "false">
  Some network cards allow manual configuration of the
  hardware address. The value "true" uses the hard-wired
  default address.


ethermulticastmode <integer>
  0: Use Mac multicast addresses. Default, normally use this one.
  1: Get all multicast packets.
  2: Promiscuous mode. Get *all* packets on wire. Needed in some
     cases when there is an AppleShare host running on the same
     computer.


etherfakeaddress <12 hexadecimal digits, or nothing>
  Overrides the hardware address, must not conflict any other
  address on the LAN.


noscsi <"true" or "false">
  to completely disable SCSI devices:
  
  noscsi true
  
  Note that currently all SCSI operations are executed
  synchronously, even if Mac application has requested
  asynchronous operation. What this means is that the
  control is not returned to the application until the command
  is completely finished. Normally this is not an issue,
  but when a CDR/CDRW is closed or erased the burner
  program typically wants to wait in some progress dialog.
  The result may be that the application reports
  a time-out error, but the operation completes
  all right anyway.
  
  
nofloppyboot <"true" or "false">
  to disable booting from a floppy:
  
  nofloppyboot true


replacescsi <"Vendor1"> <"Model1"> <"Vendor2"> <"Model2">
  This command tricks the Mac to believe that you have
  a SCSI device Model2 from vendor Vendor2, although your
  real hardware is Model1 from Vendor1. This is very useful
  since many devices have almost identical ATAPI and SCSI
  versions of their hardware, and MacOS applications usually
  support the SCSI version only. The example below is typical:
  
  replacescsi "HP" "CD-Writer+ 7100" "PHILIPS" "CDD3600"
  
  Note the use of quotes.


ntdx5hack <"true" or "false">
  Default is false.
  You may need this on NT if your display adapter driver has a bug
  in DirectX palette support. Black and white are reversed.
  It fixes the palette issue by using GDI palette instead of D3D palette.


rightmouse <0/1>
  Defines what the right mouse button is used for. The default values of 0
  means that it is used to move windowed mode BasiliskII screen.
  Value 1 sends a combination Control and mouse click to the MacOS.
  This may be useful under OS versions 8 and above.


keyboardfile <path>
  Defines the path of the customized keyboard code file.


pollmedia <"true" or "false">
  If true (default), tries to automatically detect new media.
  Applies to all "floppy", "cd" or "disk" removable media except
  1.44 MB floppies. May cause modest slow down. If unchecked, 
  use Ctrl-Shift-F11 to manually mount new media.
  If you have auto-insert notification (AIN) enabled, you may turn this
  option off. Note that some CD related software require AIN,
  and some other need it to be turned off. Consult the documentation
  of your CD software to learn which one is optimal for you.


framesleepticks <milliseconds>    
  The amount of time between video frames.


showfps <true/false>
  If true, the real frame rate is displayed.


stickymenu <true/false>
  If true, the main menu bar is kept open even after the mouse button is released,
  under all OS versions (OS 8 has this feature already). There are extensions to do 
  the same thing, but it's faster to handle this in native code.
  Default is "true".


mousewheelmode <0/1>
  If 0, mouse wheel rotation sends page up/page down keys.
  If 1, mouse wheel rotation sends line up/line down keys.


mousewheellines <integer>
  How many lines to scroll when mouse wheel is rotated.
  Has no effect if mousewheelmode is 0.


mousewheelreversex <true/false>
mousewheelreversey <true/false>
  Reverses the mouse wheel scrolling direction.


mousewheelclickmode <0/1>
  0 means toggling the wheel mouse direction vertical<->horizontal.
  1 generates a "Command - Left Arrow" key combination.


mousewheelcust00 <string>
  Customize the characters generated when mouse wheel is clicked.
  Example: send "command down", "left down", "left up", "command up":

  mousewheelcust00 +37+3C-3C-37

  See the GUI "Edit keyboard codes" dialog for available codes.
  Alternatively, if the GUI does not work for you, check the source
  code file "keyboard_windows.cpp".

mousewheelcust01 <string>
  String used when mouse wheel is clicked with shift key down.
mousewheelcust10 <string>
  String used when mouse wheel is clicked with control key down.
mousewheelcust11 <string>
  String used when mouse wheel is clicked with shift and control keys down.


realmodecd <true/false>
  If you have real-mode (16 bit) cd-rom drivers, you can use them to read
  the emulated cd. The libraries "B2WIN16.DLL" and "B2WIN32.DLL" must be
  present in the Basilisk II run time directory.  


disable98optimizations <true/false>
  If true, disables Windows 98 specific screen draw optimizations.


cpu <68020/68030/68040>
  Selects the processor to emulate. The default is 68040.


soundbuffers <integer>
  How many sound buffers can be queued. Use smallest possible value,
  but at least 2. If you have breaks in sound, either increase this
  value or the sound buffer sizes.


soundbuffersize8000 <integer>
soundbuffersize11025 <integer>
soundbuffersize22050 <integer>
soundbuffersize44100 <integer>
  Size of the sound buffer for different sampling frequencies.
  Use the smallest possible value. If you have breaks in sound, 
  increase the size of the buffers. The sizes should be multiples of
  1024 (one kilobyte).


nosoundwheninactive <true/false>
  If true, Basilisk II allows other Windows programs to use the sound
  when Basilisk II is not the active window.


guiautorestart <integer>
  0: do not restart the GUI after Basilisk II is terminated.
  1: restart the GUI in normal window.
  2: restart the GUI minimized.


extfs
  This is just a placeholder and reserved for future usage.


enableextfs <true/false>
  Selects whether the external files system is enabled.


usentfsafp
  Reserved for future usage.


extdrives <drive list>
  A list of uppercase letters, each one of them corresponding
  a drive enabled in external file system.


gethardwarevolume <true/false>
  Enables/disable AudioGetInfo(siHardwareVolume) audio control code.
  The default and recommended setting is false. You may want to
  set it true to make alert sounds work, but be prepared for some
  other applications requiring sound breaking up.


Some settings are saved in the file "BasiliskII.ini" in your Windows
directory. These are mostly options that you are not supposed to modify
yourself (but you can if you wish), like screen positions of the windows
of different sizes. This file holds also some undocumented settings
used for debugging and advanced tewaking. You need to browse the source
code to learn more about these settings.



Mouse
-----

Right mouse button is used either to move the window (when not in full screen
mode), or send Control & click to MacOS. See "rightmouse".

Mouse wheel (if available) may be used to scroll either vertically (by default)
or horizontally. Mouse wheel button may be used to either toggle the scroll
direction, or to send a "Command - Left Arrow" combination. This equals to 
the "Back" button in Netscape an IE 4. The character sequence can be customized.

Whether the mouse wheel works under original Windows 95 (before OSR2) is
not known to me.


See also "stickymenu".



Keyboard
--------

Alt-F4
  Kill the program (prompts for confirmation)

Alt-tab, Control-escape, Alt-escape
  Windows functions disabled under Win2k and NT4 (now configurable).

Alt-enter
  Switch between windowed GUI mode and full screen Direct X mode.

Shift-Control-F12
  Desktop hotkey, Windows <-> Mac

Shift-Control-F11
  Floppy reload hotkey.

Shift-Control-F10
  Remount all hard disk partitions.

Shift-Control-F9
  Remount all CD's.

Shift-Control-F8
  Remount all floppies (including Zip disks).

Pause/break
  Mac Power off key.

Right control
  Option key.

Left Winkey
  Option key. (Has problems under Win9x)

Print Screen
  Copies a bitmap image of the screen to Windows clipboard.



Compiling
---------

Requires Microsoft Visual C++ 6.0. Visual C++ 5.0 works too,
but generates worse code and the compatible project file is not updated.
MASM is required to optimize the UAE core. Can be built without MASM, but
the speed is lower.

See the sysdeps.h file in "Windows" directory.

There is a technical document "Tech.win32.txt" which shortly
describes how to build Basilisk II Windows port.



Availability
------------

The Official Basilisk II Home Page:
http://www.uni-mainz.de/~bauec002/B2Main.html

Basilisk II for Windows NT:
http://gamma.nic.fi/~lpesonen/BasiliskII/



License
-------

Basilisk II is available under the terms of the GNU General Public License.
See the file "COPYING" that is included in this archive for details.



Ported by
---------

Lauri Pesonen
lpesonen@nic.fi



Credits
-------
Christian Bauer <Christian.Bauer@uni-mainz.de>
  Basilisk II core.

Bernd Schmidt <crux@pool.informatik.rwth-aachen.de>
  The original UAE core.

Herman ten Brugge
  The original UAE FPU core.

Lew Perin
  for his invaluable web site: http://www.panix.com/~perin/packetbugs.html

Frank M. Siegert
  Fix for b2ether.vxd hang when Win9x is shutting down.

Toshimitsu Tanaka
  Fix for time zone error.
  Fix for Kanji character set in Mac -> Host clipboard text translation.

Gwenolé Beauchesne
  Faster memory bank method in the Windows 9x compatible version, more...

Mike Allison
  Fix for Windows Me ethernet driver INF script.

Stas Khirman and Raz Galili
  MIB access code.

Bernd Meyer
  UAE JIT compiler (not yet integrated to the Windows port)

Akihiko Matsuo
  Fix for the assembler version of MOVE (Ax)++,(Ay)++, op code 20d8.
  Fix for the NUMLOCK keyboard code extended flag.



A lot of people have submitted bug reports and ran test versions
of Basilisk II to find bugs. Thanks to all. To name a few:

  Joe LeVan
  Marciano Siniscalchi
  Jim Watters
  Dan
  Gregg Eshelman
  Peter Lambert
  Torsten Fastbinder
  Marc Hoffman
  Tim Pratt
  Paulo Bazaglia (Sérgio)
  Vico Klump

  More ... 

If you think that you (or someone else) should be mentioned here, please let me know.



--
Lauri
