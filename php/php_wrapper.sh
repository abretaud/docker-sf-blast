#!/bin/bash

# Just a wrapper script to avoid php segfault when using the drmaa.so lib

if [ "$JOBS_METHOD" == "drmaa" ]; then
    if [ "$DRMAA_METHOD" == "sge" ]; then
        export LD_PRELOAD="/usr/local/sge/lib/lx-amd64/libdrmaa.so /usr/local/lib/php/extensions/no-debug-non-zts-20160303/sge.so"
    else
        export LD_PRELOAD="$DRMAA_LIB_DIR/lib/libdrmaa.so /usr/local/lib/php/extensions/no-debug-non-zts-20160303/drmaa.so"
    fi
fi

exec /usr/local/bin/php_orig "$@"
