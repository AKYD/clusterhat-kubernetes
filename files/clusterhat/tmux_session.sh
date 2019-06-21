#!/bin/bash

tmux -f /root/.tmux.conf new-session -d -s rpiboot \; rename-window "status"\; send-keys '/usr/bin/rpiboot -m 2000 -d /var/lib/clusterhat/boot/ -o -l -v; sleep 10' C-m \; split-window -v -p 20\; send-keys '/usr/bin/rpi_status.sh 30' C-m \; new-window -n "controller"\; new-window -n "zero"\; send-keys 'p1' \; split-window -h -p 50 \; send-keys 'p2' \; select-pane -t 0 \; split-window \; send-keys 'p3' \; select-pane -t 2 \; split-window \; send-keys 'p4'
