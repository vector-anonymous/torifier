#!/usr/bin/env bash

detect_os() {
    if grep -q Microsoft /proc/version 2>/dev/null; then
        echo "wsl"
        return 0
    fi
    
    case "$OSTYPE" in
        linux-gnu*|linux-musl*)
            if command -v apt &> /dev/null; then
                echo "debian"
            elif command -v pacman &> /dev/null; then
                echo "arch"
            elif command -v dnf &> /dev/null; then
                echo "fedora"
            elif command -v yum &> /dev/null; then
                echo "rhel"
            elif command -v zypper &> /dev/null; then
                echo "suse"
            else
                echo "linux-unknown"
            fi
            ;;
        darwin*)
            echo "macos"
            ;;
        cygwin*|msys*|mingw*)
            echo "windows-cygwin"
            ;;
        freebsd*)
            echo "freebsd"
            ;;
        *)
            if [[ -n "$WINDIR" ]] || [[ -n "$PROGRAMFILES" ]]; then
                echo "windows-native"
            else
                echo "unknown"
            fi
            ;;
    esac
}

os_result=$(detect_os)
