AmpController
=============

A Mac Menu Bar widget to control your RS232-connected stereo receiver using your Mac's volume keys or [Apple Remote](https://en.wikipedia.org/wiki/Apple_remote).

![Mac Menu Bar preview](../master/Docs/menubar.png?raw=true)

## Purpose
**Given that** I have a Mac Mini connected to my TV with HDMI and to my stereo receiver ([what's a stereo receiver?](https://en.wikipedia.org/wiki/File:HK_AVR_245.jpg)) with an [SPDIF optical fibre](https://en.wikipedia.org/wiki/SPDIF), and the receiver has an [RS-232](https://en.wikipedia.org/wiki/RS-232)
serial connector for control input/output, **and...**

**Given that** Apple decided to disable system-level volume control when the audio output is SPDIF, I have to use a separate remote control to adjust speaker volume or turn the volume knob manually.  This is silly.

**Therefore,** I wrote *AmpController* to restore volume control to the Mac by capturing volume change button presses - both on the
keyboard and on the Apple Remote (if present and supported) - and controlling the receiver according to your intent.

*AmpController* runs reciever-specific [Lua](http://lua.org) scripts to turn the following Mac events into actions on your receiver:

* Wake from sleep
* Go to sleep
* Volume up key
* Volume down key
* Mute key
* Apple Remote volume up button
* Apple Remote volume down button

This utility is compatible with any serial port or Bluetooth, as long as it has a file in `/dev/tty.*`.  It's also compatible with
any stereo receiver that you can control with a serial port, though it's up to you to write the simple Lua script to control it.

This codebase may also serve as a useful reference in how to **capture special keyboard button presses**, receive **Apple Remote button presses**,
implement **asynchronous serial networking** (just take Serialport.m/.h) integrate **Lua in a Cocoa app** and more.

## Status
**Alpha** - Feature-complete and works correctly, may have bugs.

## Known limitations
* Baud rates are always 9600,8n1.  I will fix this imminently.
* Script paths are absolute. I will fix this too.
* No enable/disable control, you have to quit the app. I'll add a checkbox on the status item menu.
* Handling of changing script and/or changing serial port needs to result in more consistent behaviour.
* [Possibly other bugs](../../issues)
