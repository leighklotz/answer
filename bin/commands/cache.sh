#!/usr/bin/env -S bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"
source "${SCRIPT_DIR}/../functions.sh"

case "$1" in
    clear)
        cache_dir=$(_find_cache_dir)

        if [[ -z "$cache_dir" || ! -d "$cache_dir" ]]; then 
            echo "❌ No valid cache directory found." >&2
            return 1
        fi

        # Safety check: prevent accidental deletion of root or home if _find_cache_dir fails catastrophically
        if [[ "$cache_dir" == "/" || "$cache_dir" == "$HOME" ]]; then
            echo "❌ Error: Cache directory is a protected system path." >&2
            return 1
        fi

        printf "⚠️ Are you sure you want to remove %s?\n" "$cache_dir" >&2
        read -r -p "Delete directory? (y/N): " reply < /dev/tty
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            rm -- "$cache_dir"/*.json && echo "🗑️ Cache cleared." || echo "❌ Deletion failed." >&2
        else
            echo "🚫 Cancelled."
        fi
        ;;

    show) printf "%s\n" "$(_find_cache_dir)" ;;
    enable|disable) log_and_exit 1 "internal error: $1 must be handled by function, not script" ;;
    *) echo "Unknown cache option '$1': (clear|show|enable|disable)" >&2; exit 1 ;;
esac

