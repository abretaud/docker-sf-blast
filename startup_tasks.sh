#!/bin/bash
set -e

function run_scripts () {
	SCRIPTS_DIR="/scripts/$1.d"
	SCRIPT_FILES_PATTERN="^${SCRIPTS_DIR}/[0-9][0-9][a-zA-Z0-9_-]+$"
	SCRIPTS=$(find "$SCRIPTS_DIR" -type f -uid 0 -executable -regex "$SCRIPT_FILES_PATTERN" | sort)
	if [ -n "$SCRIPTS" ] ; then
		echo "=>> $1-scripts:"
	    for script in $SCRIPTS ; do
	        echo "=> $script"
			. "$script"
	    done
	fi
}

### auto-configure database from environment-variables
DB_DRIVER='pgsql'
: ${DB_HOST:='postgres'}
: ${DB_PORT:='5432'}
: ${DB_NAME:='postgres'}
: ${DB_USER:='postgres'}
: ${DB_PASS:='postgres'}

: ${MAILER_HOST:='127.0.0.1'}
: ${MAILER_USER:='null'}
: ${MAILER_PASS:='null'}

SECRET=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1`

: ${APACHE_RUN_USER:='www-data'}
: ${APACHE_RUN_GROUP:='www-data'}

export DB_DRIVER DB_HOST DB_PORT DB_NAME DB_USER DB_PASS SECRET
echo -e "# Database configuration\n
export DB_DRIVER=${DB_DRIVER} DB_HOST=${DB_HOST} DB_PORT=${DB_PORT} DB_NAME=${DB_NAME} DB_USER=${DB_USER} DB_PASS=${DB_PASS} SECRET=${SECRET}" >> /etc/profile
echo -e "# Database configuration\n
export DB_DRIVER=${DB_DRIVER} DB_HOST=${DB_HOST} DB_PORT=${DB_PORT} DB_NAME=${DB_NAME} DB_USER=${DB_USER} DB_PASS=${DB_PASS} SECRET=${SECRET}" >> /etc/bash.bashrc

###

run_scripts pre-launch

if [ "$JOBS_METHOD" == "drmaa" ]; then
    export LD_PRELOAD="$DRMAA_LIB_DIR/lib/libdrmaa.so /usr/local/lib/php/extensions/no-debug-non-zts-20160303/drmaa.so"
		/etc/init.d/munge start
fi
