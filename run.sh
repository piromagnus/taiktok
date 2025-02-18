#!/bin/bash

docker run -it --rm \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$HOME/.Xauthority:/root/.Xauthority" \
    -e DISPLAY="$DISPLAY" \
    --device /dev/kvm \
    --device /dev/dri \
    -p 5554:5554 \
    -p 5555:5555 \
    -p 30000:30000 \
    -v "$(pwd):/app" \
    flutter-dev