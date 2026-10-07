#!/bin/sh

export LC_ALL=C #prevent encoding errors during filtering

printf "Length: " #length prompt
read -r number

case "$number" in #integer check
    ''|*[!0-9]*)
        echo "NO INTEGER!" >&2
        exit 1
        ;;
esac

token=$(tr -dc '[:alnum:]' < /dev/urandom | head -c "$number") #token generator

echo "TOKEN: $token" #token shower
