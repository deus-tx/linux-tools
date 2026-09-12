#!/bin/bash

# 1. Ask the user for the desired URL
read -p "Kiosk URL (e.g., http://example.com): " KIOSK_URL

# 2. Automatically detect the logged-in user
# If run with sudo, $SUDO_USER preserves the actual user. Otherwise, it falls back to $USER.
TARGET_USER=${SUDO_USER:-$USER}

# Fallback in case it's run directly as root or detection fails
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    read -p "Could not detect regular user. Please enter the target username: " TARGET_USER
fi

# 3. Execute the modified commands
sed -i '/cdrom:/d' /etc/apt/sources.list && \
apt update && \
apt install --no-install-recommends xserver-xorg xinit xterm openbox chromium x11-xserver-utils -y && \
mkdir -p /etc/systemd/system/getty@tty1.service.d && \
echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin $TARGET_USER --noclear %I \$TERM" > /etc/systemd/system/getty@tty1.service.d/override.conf && \
echo "allowed_users=anybody" > /etc/X11/Xwrapper.config && \
echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' > /home/$TARGET_USER/.profile && \
mkdir -p /home/$TARGET_USER/.config/openbox && \
echo "xset s off -dpms s noblank" > /home/$TARGET_USER/.config/openbox/autostart && \
echo "chromium --kiosk --no-sandbox --disable-gpu --no-first-run --disable-infobars --auto-virtual-keyboard $KIOSK_URL" >> /home/$TARGET_USER/.config/openbox/autostart && \
chmod +x /home/$TARGET_USER/.config/openbox/autostart && \
chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/ && \
/sbin/reboot
