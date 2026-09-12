# How to Setup a Minimal Debian Kiosk

A complete guide to configuring a lightweight Debian system for a Kiosk or an Office-Tool. Everything is configured as `root`, but after rebooting, the system automatically logs in as `user` and boots into a Chromium fullscreen kiosk with a dynamic touch keyboard*.

--- 

# 📩 Debian Installation

Follow these exact configurations during the initial Debian system installation:

-  **Host & User Creation**:
	* **Hostname**: `debian-kiosk`   <- You can use something else
	* **Username**: `user`    <- This can be changed too but you **have to modify the commands** (replace every `user` value to your username)
-  **Software Selection Grid**:
	* **Uncheck** every single desktop environment option (like GNOME, XFCE, etc.).
	* **Uncheck** **`standard system utilities`**! Everything needed will be installed later.
* **Network Mirror & Proxy**
	* You can use a network mirror if you want
	* Leave `Proxy` empty.
-  **Finish & Boot**: 
	- Complete the installer instructions, let the system restart, and log back in on the black screen console using your **`root`** account username and password.


---

# ⚡ Fast Setup (1-Line Command)

Log into your VM as **`root`** and paste this exact single-line command to execute the entire setup instantly. 

💡 **To change the URL:** Replace `http://example.com` at the very end of the command with your custom IP or link.

```bash
sed -i '/cdrom:/d' /etc/apt/sources.list && apt update && apt install --no-install-recommends xserver-xorg xinit xterm openbox chromium x11-xserver-utils -y && mkdir -p /etc/systemd/system/getty@tty1.service.d && echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin user --noclear %I \$TERM" > /etc/systemd/system/getty@tty1.service.d/override.conf && echo "allowed_users=anybody" > /etc/X11/Xwrapper.config && echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' > /home/user/.profile && mkdir -p /home/user/.config/openbox && echo "xset s off -dpms s noblank" > /home/user/.config/openbox/autostart && echo "chromium --kiosk --no-sandbox --disable-gpu --no-first-run --disable-infobars --auto-virtual-keyboard http://example.com" >> /home/user/.config/openbox/autostart && chmod +x /home/user/.config/openbox/autostart && chown -R user:user /home/user/ && /sbin/reboot
```

---

# 📖 Step-by-Step Explanation

Here is exactly what the setup process does step-by-step behind the scenes:

## Step 1: Fix Repository Lists & Install Packages
```bash
sed -i '/cdrom:/d' /etc/apt/sources.list
apt update && apt install --no-install-recommends xserver-xorg xinit xterm openbox chromium x11-xserver-utils -y
```
* **`sed -i '/cdrom:/d'`**: Removes the local installation CD-ROM path from the system repository file, enabling Debian to fetch new software from the internet.
* **`--no-install-recommends`**: Skips heavy standard desktop environments to keep the system fast and lightweight.
* **`xserver-xorg` & `xinit`**: The core graphics server stack required to display any visual windows.
* **`openbox`**: A barebones window manager running Chromium without top borders, close buttons, or panels.

## Step 2: Configure Automatic Console Login for 'user'
```bash
mkdir -p /etc/systemd/system/getty@tty1.service.d
echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin user --noclear %I \$TERM" > /etc/systemd/system/getty@tty1.service.d/override.conf
```
* Bypasses the default Linux username/password prompt during terminal booting.
* Instructs the operating system to automatically log into the unprivileged account named **`user`** straight away.

## Step 3: Grant X-Server Permissions & Force Auto-Start
```bash
echo "allowed_users=anybody" > /etc/X11/Xwrapper.config
echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' > /home/user/.profile
```
* **`Xwrapper.config`**: Gives the unprivileged account (`user`) direct permission to launch the underlying graphic engine.
* **`.profile`**: A profile script triggered directly upon login. If the virtual terminal detects no window display is active, it fires `startx` to spin up the UI engine.

## Step 4: Configure Kiosk Mode & Fix System Permissions
```bash
mkdir -p /home/user/.config/openbox
echo "xset s off -dpms s noblank" > /home/user/.config/openbox/autostart
echo "chromium --kiosk --no-sandbox --disable-gpu --no-first-run --disable-infobars --auto-virtual-keyboard http://example.com" >> /home/user/.config/openbox/autostart
chmod +x /home/user/.config/openbox/autostart
chown -R user:user /home/user/
/sbin/reboot
```
* **`xset s off -dpms s noblank`**: Disables the screensaver and stops the virtual monitor from turning pitch black or entering standby modes.
* **`--kiosk`**: Forces Chromium to spin up in strict full-screen mode, hiding address inputs, navigation tabs, or window boundaries.
* **`--auto-virtual-keyboard`**: Triggers a built-in virtual touch keyboard overlay sliding into view only when a user focuses on inputs (like text search grids).
* **`chown -R user:user`**: Hands all directory configurations over to the target user account so the software has full permission to read and execute the startup configuration.
* **`/sbin/reboot`**: Reboots the system.

---

# 🔄 How to Change the Link Later

If you ever need to change the destination website in the future, you do not need to run the whole setup again. Log into your VM, switch to a terminal (`Ctrl + Alt + F2`), log in as **`root`**, and run this command:

```bash
echo "chromium --kiosk --no-sandbox --disable-gpu --no-first-run --disable-infobars --auto-virtual-keyboard http://YOUR-NEW-URL-HERE/" > /home/user/.config/openbox/autostart
```
*(Just replace `http://YOUR-NEW-URL-HERE/` with your updated destination, then type `/sbin/reboot` to apply it).*

---

# 📜 Credits

Yo Credits to the 3 hours of my life i won't get back


~deus-tx :)

\*this only happens if chromium detects touchscreen-hardware
