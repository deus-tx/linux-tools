#!/bin/bash
# -------------------------------------------------------------------------
# Debian Minimal GUI Installer
# -------------------------------------------------------------------------

set -e

# -------------------------------------------------------------------------
# Root check
# -------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo!"
    exit 1
fi

# -------------------------------------------------------------------------
# Optional sudo installation
# -------------------------------------------------------------------------
echo "============================================="
echo "             Sudo Configuration              "
echo "============================================="
echo

if command -v sudo >/dev/null 2>&1; then
    echo "sudo is already installed."
    SUDO_AVAILABLE=true
else
    echo "sudo is NOT currently installed."
    echo
    read -r -p "Do you want to install sudo? (y/n): " INSTALL_SUDO

    if [[ "$INSTALL_SUDO" =~ ^[Yy]$ ]]; then
        echo
        echo "Installing sudo..."

        apt update
        apt install -y sudo

        SUDO_AVAILABLE=true
        echo "sudo installed successfully."
    else
        SUDO_AVAILABLE=false
        echo "sudo will NOT be installed."
    fi
fi

# -------------------------------------------------------------------------
# Determine the real/current user
# -------------------------------------------------------------------------
if [ -n "${SUDO_USER:-}" ] && id "$SUDO_USER" >/dev/null 2>&1; then
    CURRENT_REAL_USER="$SUDO_USER"
else
    CURRENT_REAL_USER="${USER:-root}"
fi

echo
echo "Current user: $CURRENT_REAL_USER"

# -------------------------------------------------------------------------
# User Scope Selection
# -------------------------------------------------------------------------
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

        # Include root if script was executed directly as root
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

# Remove duplicate users
mapfile -t TARGET_USERS < <(
    printf '%s\n' "${TARGET_USERS[@]}" | sort -u
)

echo
echo "============================================="
echo "Users that will be configured:"
echo "============================================="
printf '  - %s\n' "${TARGET_USERS[@]}"
echo

read -r -p "Continue with these settings? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi
