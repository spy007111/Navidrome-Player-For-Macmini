#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

if [ ! -d "AppleMusicPlayer.app" ]; then
    echo "📦 正在编译 AppleMusicPlayer..."
    swift build -c release --disable-sandbox
    ./build_app.sh
fi

echo "🎵 正在启动 Apple Music 播放器..."
open AppleMusicPlayer.app
