#!/bin/bash

# Just a wrapper script to avoid php segfault when using the sge.so lib

if [ "$JOBS_METHOD" == "drmaa" ]; then
    export LD_PRELOAD="/usr/local/sge/lib/lx-amd64/libdrmaa.so /usr/local/lib/php/extensions/no-debug-non-zts-20160303/sge.so"
fi

exec /usr/local/bin/php_orig "$@"
