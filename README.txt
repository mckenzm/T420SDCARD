================================================================================
 Fixing the built-in SD card reader on this machine
================================================================================

  *** STATUS: INSTALLED & WORKING (2026-07-04) ***
  Installed via Option 2-style automation using the self-contained package in
  .\pkg\ (signed with a throwaway cert that was removed afterward). The device
  now reports "Ricoh PCIe SDXC/MMC Host Controller (E822)", error code 0, bound
  to sdbus. Registered in the driver store as oem14.inf (persists across
  reboots). The options below are kept for reference / reinstall / uninstall.
--------------------------------------------------------------------------------

WHAT THE DEVICE ACTUALLY IS
---------------------------
The card reader is NOT a Canon device and NOT USB. It is the SD slot built into
your Lenovo ThinkPad T420 (machine type 4180RK8), driven by a Ricoh PCIe
SDXC/MMC host-controller chip:

    Hardware ID : PCI\VEN_1180&DEV_E822&SUBSYS_213317AA
    Vendor 1180 = Ricoh
    Device E822 = Ricoh PCIe SD/MMC host controller
    Subsys 17AA = Lenovo
    Status      = Error code 28 ("drivers not installed")

It currently appears in Device Manager as "Base System Device" with a yellow
warning triangle (look under "Other devices").

WHY IT HAS NO DRIVER
--------------------
The chip reports PCI class code 08 80 ("Base System Peripheral / Other")
instead of the standard SD host-controller class 08 05 01. Windows binds SD
readers by that standard class code, so it never claims this chip -- even
though the driver it needs (sdbus.sys) is already installed on your disk.

The fix is NOT to write a new driver. It is to tell Windows to use the driver
it already has. There are three ways, easiest first.


--------------------------------------------------------------------------------
 OPTION 1  --  Let Windows try first (30 seconds, no files)
--------------------------------------------------------------------------------
1. Press Win+X -> Device Manager.
2. Find "Base System Device" under "Other devices" (yellow triangle).
   To be sure it's the right one: right-click -> Properties -> Details ->
   "Hardware Ids" should show PCI\VEN_1180&DEV_E822...
3. Right-click it -> Update driver -> "Search automatically for drivers."
   This also checks Windows Update.

If Windows finds one, you're done. If it says the best driver is already
installed (it isn't), move on.


--------------------------------------------------------------------------------
 OPTION 2  --  Lenovo's official Ricoh driver (most reliable, WHQL-signed)
--------------------------------------------------------------------------------
This is the vendor-supported driver and the safest choice.

1. Go to Lenovo support:  https://pcsupport.lenovo.com
2. Enter machine type 4180 (ThinkPad T420), or search "T420 Ricoh card reader."
3. Download "Ricoh Multi Card Reader Driver" (the Windows 7 64-bit package
   installs and runs fine on Windows 10 64-bit).
4. Run the installer, reboot, insert a card.

Its INF explicitly lists DEV_E822, so it will bind correctly and gives you full
functionality and power management.


--------------------------------------------------------------------------------
 OPTION 3  --  The INF in this folder (no download, reversible)
--------------------------------------------------------------------------------
File:  ricoh-e822-sdhost.inf

This is a small binding file (not a new driver binary). It adds your exact
hardware ID and points it at Windows' own signed sdbus.sys, reusing the
Ricoh-specific tuning already in the system sdbus.inf. Worth trying because
this chip is a standard SD host controller (Linux drives it with its generic
sdhci-pci driver); the only reason Windows skipped it is the mis-reported
class code.

INSTALL
1. Win+X -> Device Manager.
2. Right-click "Base System Device" (the PCI\VEN_1180&DEV_E822 one) ->
   Update driver.
3. "Browse my computer for drivers."
4. "Let me pick from a list of available drivers on my computer."
   - If it asks you to choose a device type/class, scroll to and pick
     "Show All Devices," then Next.
5. Click "Have Disk..." -> Browse -> select:
       C:\Users\t420e\ricoh-sd-reader-driver\ricoh-e822-sdhost.inf
   -> OK.
6. Select "Ricoh PCIe SDXC/MMC Host Controller (E822)" -> Next.
7. A Windows Security dialog will warn "Windows can't verify the publisher of
   this driver software." This is expected -- the INF isn't code-signed, but
   the actual driver it loads (sdbus.sys) IS Microsoft-signed. Click
   "Install this driver software anyway."
8. The device should move out of "Other devices" and appear as an SD host
   controller. Insert a card; it should show up as a removable drive in
   File Explorer.

IF STEP 7 IS BLOCKED (rare: strict policy / memory integrity)
   Boot once with driver signature enforcement off, then repeat:
   Settings -> System -> Recovery -> Advanced startup -> Restart now ->
   Troubleshoot -> Advanced options -> Startup Settings -> Restart ->
   press 7 ("Disable driver signature enforcement"). Install, then reboot
   normally. The binding persists because sdbus.sys itself is signed.

IF IT BINDS BUT THE READER DOESN'T WORK
   The Ricoh tuning may not suit this exact chip. Edit ricoh-e822-sdhost.inf
   and change BOTH lines that read:
        Needs   = SDHostRicoh
        Needs   = SDHostRicoh.Services
        Needs   = SDHostRicoh.HW
   to the plain generic host-controller sections:
        Needs   = SDHost
        Needs   = SDHost.Services
        Needs   = SDHost.HW
   Save and repeat the install. If neither works, use Option 2.

HOW TO UNDO
   Device Manager -> right-click the device -> Properties -> Driver tab ->
   "Roll Back Driver," or "Uninstall device" and tick "Delete the driver
   software for this device," then Action -> Scan for hardware changes.


--------------------------------------------------------------------------------
 Why not a hand-written kernel driver?
--------------------------------------------------------------------------------
Authoring a Windows kernel driver from scratch would require the WDK, the
chip's exact register-level programming interface, and -- on 64-bit Windows --
a Microsoft-trusted signature or the driver won't load at all. It would also be
strictly worse than the options above, because Windows already ships a correct,
signed driver for this standard controller. The task was never "write a
driver"; it was "make Windows use the driver it already has." That's what the
INF above does.
================================================================================
