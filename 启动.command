#!/bin/zsh
cd "$(dirname "$0")"
(sleep 1; open "http://127.0.0.1:4173/admin/") &
python3 -m http.server 4173 --bind 127.0.0.1
