#!/bin/bash
#Standard
#maximum CPU clock frequencies by speed grade are: 866 MHz (-3), 766 MHz (-2), and 667 MHz (-1C/-1I/-1LI/-1Q)
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 BOARD_NAME"
    echo "Example: $0 libre"
    exit 1
fi

BOARD_NAME=$1

if [ "$BOARD_NAME" = "libre" ]; then
    ./overclock.sh 50 950 600
    ./overclock.sh 50 1100 750
else
    ./overclock.sh 33 495 396
    ./overclock.sh 33 950 600
    ./overclock.sh 33 1100 750
fi