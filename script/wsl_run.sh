#!/bin/bash
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
eval "$($HOME/.local/bin/mise activate bash 2>/dev/null)"
cd /mnt/d/Apps/ruby-on-rails/learing_app
exec "$@"
