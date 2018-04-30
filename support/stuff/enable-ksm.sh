#!/bin/sh

# enable kernel-samepage-merging to save RAM
[ -w /sys/kernel/mm/ksm/merge_across_nodes ] && echo 0 > /sys/kernel/mm/ksm/merge_across_nodes
[ -w /sys/kernel/mm/ksm/run ] && echo 1 > /sys/kernel/mm/ksm/run

# Don't waste a complete CPU core on low-core count machines
ppcpu=64

# aarch64 machines have high core count but low single-core performance
[ $(uname -m) = aarch64 ] && ppcpu=4
pts=$(($(lscpu -p | grep -vc '^#')*$ppcpu))
[ -w /sys/kernel/mm/ksm/pages_to_scan ] && echo $pts > /sys/kernel/mm/ksm/pages_to_scan

# huge pages can not be shared or swapped, so do not use them
[ -w /sys/kernel/mm/transparent_hugepage/enabled ] && echo never > /sys/kernel/mm/transparent_hugepage/enabled

exit 0
