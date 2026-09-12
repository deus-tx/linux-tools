#!/bin/bash
# Debian Minimal GUI Installer

set -e

# Root check
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo!"
    echo
    echo -e "\033[38;2;252;36;3mIf sudo isn't installed:\033[0m"
    echo "login as root -> apt install -y sudo,"
    echo "/sbin/reboot,"
    echo "Log in as root -> usermod -aG sudo [username]"
    exit 1
fi

# Determine current user
if [ -n "${SUDO_USER:-}" ] && id "$SUDO_USER" >/dev/null 2>&1; then
    CURRENT_REAL_USER="$SUDO_USER"
else
    CURRENT_REAL_USER="${USER:-root}"
fi

echo
echo "Current user: $CURRENT_REAL_USER"

# User scope
echo
echo "============================================="
echo "       User Configuration Scope              "
echo "============================================="
echo
echo "Apply the Shell-to-GUI configuration to:"
echo
echo "  y) ALL users with a home directory in /home"
echo "  n) ONLY the current user ($CURRENT_REAL_USER)"
echo

read -r -p "Apply to ALL users? (y/n): " USER_SCOPE

TARGET_USERS=()

case "$USER_SCOPE" in
    [Yy])
        echo
        echo "Scope selected: ALL users."

        while IFS=: read -r username _ uid _ _ homedir _; do
            if [[ "$homedir" == /home/* ]] \
                && [ "$uid" -ge 1000 ] \
                && id "$username" >/dev/null 2>&1; then
                TARGET_USERS+=("$username")
            fi
        done < /etc/passwd

        if [ "$CURRENT_REAL_USER" = "root" ]; then
            TARGET_USERS+=("root")
        fi
        ;;

    [Nn]|"")
        echo
        echo "Scope selected: CURRENT user only."
        TARGET_USERS+=("$CURRENT_REAL_USER")
        ;;

    *)
        echo
        echo "Invalid selection. Defaulting to CURRENT user only."
        TARGET_USERS+=("$CURRENT_REAL_USER")
        ;;
esac

# Remove duplicates
mapfile -t TARGET_USERS < <(
    printf '%s\n' "${TARGET_USERS[@]}" | sort -u
)

echo
echo "============================================="
echo "Users that will be configured:"
echo "============================================="
printf '  - %s\n' "${TARGET_USERS[@]}"
echo

read -r -p "Continue with these users? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# System installation
echo
echo "=== 1. System Update & Minimal GUI Installation ==="

apt update

apt install -y --no-install-recommends \
    xorg \
    openbox \
    xterm \
    synaptic \
    zram-tools \
    curl \
    ca-certificates

# Configure users
echo
echo "=== 2. Configuring Users ==="

for username in "${TARGET_USERS[@]}"; do
    echo "Configuring user: $username..."

    if [ "$username" = "root" ]; then
        U_HOME="/root"
    else
        U_HOME="$(getent passwd "$username" | cut -d: -f6)"

        if [ -z "$U_HOME" ] || [ ! -d "$U_HOME" ]; then
            echo "WARNING: Could not find home directory for $username. Skipping."
            continue
        fi

        # Add user to sudo group
        usermod -aG sudo "$username" || true
    fi

    # Start Openbox through startx
    echo "exec openbox-session" > "$U_HOME/.xinitrc"

    # Automatically start X on TTY1
    if [ -f "$U_HOME/.bashrc" ]; then
        if ! grep -q "Shell-to-GUI" "$U_HOME/.bashrc"; then
            cat << 'EOF' >> "$U_HOME/.bashrc"

# Automatically start X environment on TTY1 (Shell-to-GUI)
if [ -z "$DISPLAY" ] && [ "${XDG_VTNR:-}" = "1" ]; then
    exec startx
fi
EOF
        fi
    else
        cat << 'EOF' > "$U_HOME/.bashrc"

# Automatically start X environment on TTY1 (Shell-to-GUI)
if [ -z "$DISPLAY" ] && [ "${XDG_VTNR:-}" = "1" ]; then
    exec startx
fi
EOF
    fi

    if [ "$username" != "root" ]; then
        chown "$username:$username" "$U_HOME/.xinitrc"
        chown "$username:$username" "$U_HOME/.bashrc"
    fi

    echo "  ✓ $username configured."
done

# Reduce APT cache usage
echo
echo "=== 3. SSD / Storage Optimizations ==="

cat > /etc/apt/apt.conf.d/no-cache << 'EOF'
DPkg::Post-Invoke {
    "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true";
};
EOF

rm -f /var/cache/apt/archives/*.deb
rm -f /var/cache/apt/archives/partial/*.deb

# Limit systemd journal logs
if [ -f /etc/systemd/journald.conf ]; then
    if grep -q '^SystemMaxUse=' /etc/systemd/journald.conf; then
        sed -i 's/^SystemMaxUse=.*/SystemMaxUse=50M/' /etc/systemd/journald.conf
    else
        sed -i '/^\[Journal\]/a SystemMaxUse=50M' /etc/systemd/journald.conf
    fi

    systemctl restart systemd-journald || true
fi

# ZRAM
echo
echo "=== 4. Configuring ZRAM ==="

cat > /etc/default/zram-tools << 'EOF'
ALGORITHM=lz4
PERCENT=50
EOF

# Script already runs as root, so sudo is unnecessary.
systemctl start dbus.service

systemctl enable zram-tools 2>/dev/null || true
systemctl restart zram-tools || true

# Automatic Login
echo
echo "=== 5. Automatic Login Configuration ==="
echo
read -r -p "Enable automatic login on TTY1? (y/n): " ENABLE_AUTOLOGIN

# One-shot autologin:
# - First login after boot is automatic.
# - After Openbox exits, getty returns to normal login.
# - Reboot clears /run, allowing automatic login again.

ONE_SHOT_GETTY="/usr/local/sbin/one-shot-autologin"
AUTOLOGIN_DROPIN_DIR="/etc/systemd/system/getty@tty1.service.d"
AUTOLOGIN_DROPIN="$AUTOLOGIN_DROPIN_DIR/autologin.conf"
AUTOLOGIN_FLAG="/run/openbox-autologin-used"

# Always clean up previous configuration first.
rm -f -- "$AUTOLOGIN_DROPIN"
rm -f -- "$ONE_SHOT_GETTY"
rm -rf -- "$AUTOLOGIN_FLAG"

systemctl daemon-reload

if [[ "$ENABLE_AUTOLOGIN" =~ ^[Yy]$ ]]; then

    echo
    echo "Users available for automatic login:"
    echo

    i=1
    for username in "${TARGET_USERS[@]}"; do
        echo "  $i) $username"
        ((i++))
    done

    echo
    read -r -p "Select user number for automatic login: " AUTOLOGIN_CHOICE

    if [[ "$AUTOLOGIN_CHOICE" =~ ^[0-9]+$ ]] \
        && [ "$AUTOLOGIN_CHOICE" -ge 1 ] \
        && [ "$AUTOLOGIN_CHOICE" -le "${#TARGET_USERS[@]}" ]; then

        AUTOLOGIN_USER="${TARGET_USERS[$((AUTOLOGIN_CHOICE - 1))]}"

        if [ "$AUTOLOGIN_USER" = "root" ]; then
            echo
            echo "WARNING: Automatic root login is not recommended."
            read -r -p "Are you REALLY sure? (y/n): " ROOT_CONFIRM

            if [[ ! "$ROOT_CONFIRM" =~ ^[Yy]$ ]]; then
                echo "Automatic root login cancelled."
                AUTOLOGIN_USER=""
            fi
        fi

        if [ -n "$AUTOLOGIN_USER" ]; then
            echo
            echo "Configuring one-shot automatic login for: $AUTOLOGIN_USER"

            # Create the one-shot agetty wrapper.
            #
            # First start after boot:
            #   -> automatic login
            #
            # Every later getty restart:
            #   -> normal login prompt
            #
            # /run is cleared during reboot, so automatic login
            # becomes available again on the next boot.

            cat > "$ONE_SHOT_GETTY" << 'EOF'
#!/bin/bash

set -e

AUTOLOGIN_USER="$1"
shift

FLAG="/run/openbox-autologin-used"

# mkdir is atomic:
# only the first getty invocation can successfully create the directory.
if mkdir "$FLAG" 2>/dev/null; then
    exec /sbin/agetty --autologin "$AUTOLOGIN_USER" "$@"
else
    exec /sbin/agetty "$@"
fi
EOF

            chmod 755 "$ONE_SHOT_GETTY"
            chown root:root "$ONE_SHOT_GETTY"

            mkdir -p "$AUTOLOGIN_DROPIN_DIR"

            cat > "$AUTOLOGIN_DROPIN" << EOF
[Service]
ExecStart=
ExecStart=-$ONE_SHOT_GETTY $AUTOLOGIN_USER --noclear %I \$TERM
EOF

            # Make sure the first boot after installation gets autologin.
            rm -rf -- "$AUTOLOGIN_FLAG"

            systemctl daemon-reload

            # Ensure tty1 getty is enabled.
            systemctl enable getty@tty1.service

            echo
            echo "✓ One-shot automatic login enabled for $AUTOLOGIN_USER"
            echo
            echo "Behavior:"
            echo "  Boot"
            echo "    -> automatic login"
            echo "    -> Openbox"
            echo
            echo "  Openbox -> Exit"
            echo "    -> normal login prompt"
            echo
            echo "  Login again"
            echo "    -> Openbox"
            echo
            echo "  Reboot"
            echo "    -> automatic login again"

        else
            echo
            echo "Automatic login cancelled."
            echo "Normal login will be used."

            systemctl daemon-reload
        fi

    else
        echo
        echo "Invalid selection."
        echo "Automatic login was not configured."

        systemctl daemon-reload
    fi

else
    echo
    echo "Automatic login disabled."

    # Previous configuration was already removed above.
    systemctl daemon-reload
fi

# Finished
echo
echo "============================================="
echo " INSTALLATION SUCCESSFULLY COMPLETED"
echo "============================================="
echo
echo "Configured users:"
printf '  - %s\n' "${TARGET_USERS[@]}"
echo
echo "Reboot the system to complete."
echo
