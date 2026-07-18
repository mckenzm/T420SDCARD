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
Windows binds a driver to a device by matching EITHER an exact hardware ID
listed in some INF, OR a PCI class code. This device misses both:

  * No hardware ID match. Nothing in any catalog Windows consults declares
    PCI\VEN_1180&DEV_E822. Notably, Microsoft's in-box sdbus.inf DOES have a
    [Ricoh.NTamd64] section -- but it covers DEV_0822, not DEV_E822.
    (Verified by reading C:\Windows\INF\sdbus.inf on this machine.)

  * No class code match. sdbus.inf's [Generic.NTamd64] section binds any
    device advertising PCI class 08 05 01 (SD Host Controller). That generic
    fallback is what rescues most no-name SD readers. This chip advertises
    class 08 80 ("Base System Peripheral / Other") instead, so it misses the
    safety net too.

So the driver it needs (sdbus.sys) is already sitting on your disk, signed by
Microsoft -- Windows just has no rule that connects the two.

WHY NOTHING AUTOMATIC FIXES IT
------------------------------
This also explains why no automated source supplies the driver. Three
different mechanisms all fail, for three different reasons, all rooted in the
fact that Lenovo never validated the T420 for Windows 10:

  * Not listed on Lenovo's site for this machine. Lenovo's downloads are a
    lookup of machine-type x OS. There is no Windows 10 row for 4180, so
    searching that machine type surfaces nothing -- even though a suitable
    package exists (see OPTION 2).

  * Not found by Lenovo System Update / Vantage. Those tools query the same
    machine-type manifest. They do not enumerate your PCI bus and reason
    about it; they read a table that has no row for you.

  * Not offered by Windows Update. WU matches by hardware ID against packages
    published to its catalog. OEM packages like Ricoh's are distributed from
    the vendor site and generally never pushed to WU at all -- and as above,
    no in-box INF claims this ID either.

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
 OPTION 2  --  Lenovo's official Ricoh driver (vendor-signed, but see caveats)
--------------------------------------------------------------------------------
Lenovo DOES publish a "Ricoh Media Card Reader Driver" for Windows 10:

    DS032126 - Ricoh Media Card Reader Driver, Windows 10 / 8 (32 & 64-bit)
    https://support.lenovo.com/us/en/downloads/ds032126

    DS038445 - Ricoh Media Card Reader Driver, Windows 10 / 8.1 (32 & 64-bit)
    https://support.lenovo.com/us/en/downloads/ds038445

IMPORTANT: do NOT expect to find these by searching machine type 4180. The
T420 was never validated by Lenovo for Windows 10, so it has no Windows 10
entry; these packages are published under the ThinkPad models that WERE
validated (T430 / X230 era). The package is real, it is simply not surfaced
for this machine. Open the DS links above directly.

UNVERIFIED: whether that package's INF actually lists DEV_E822. Our chip is
the same Ricoh PCIe family, so it is plausible -- but it has NOT been
confirmed. To check before installing, extract the package and search its
.inf files for "E822":

    Select-String -Path <extracted folder>\*.inf -Pattern 'E822'

If DEV_E822 appears, this is the better long-term choice than OPTION 3: it is
vendor-signed and may bring fuller power management. If it does NOT appear,
the package will not bind to this device and OPTION 3 is your answer.


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
