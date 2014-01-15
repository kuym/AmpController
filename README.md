AmpController
=============

A Mac Menu Bar widget to control your RS232-connected stereo receiver using your Mac's volume keys or Apple Remote.

![Mac Menu Bar preview](../master/Docs/menubar.png?raw=true)

Runs device-specific [Lua](http://lua.org) scripts to turn the following Mac events into actions on your receiver:

* Wake from sleep
* Go to sleep
* Volume up key
* Volume down key
* Mute key
* Apple Remote volume up button
* Apple Remote volume down button

Compatible with any serial port or Bluetooth, as long as it has a file in `/dev/tty.*`.  Compatible with any stereo receiver
that you can control with a serial port, though it's up to you to write the simple Lua script to control it.


## Status
**Alpha** - Feature-complete and works correctly, may have bugs.

## Known limitations
* Baud rates are always 9600,8n1.  I will fix this imminently.
* Script paths are absolute. I will fix this too.
* No enable/disable control, you have to quit the app. I'll add a checkbox on the status item menu.
* [Possibly other bugs](../../issues)
