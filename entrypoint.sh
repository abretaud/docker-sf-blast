#!/bin/bash
set -e

/startup_tasks.sh

exec apache2-foreground

exit 1
