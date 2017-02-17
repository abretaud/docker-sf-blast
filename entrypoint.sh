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


###  connect to database

echo
echo "=> Trying to connect to a database using:"
echo "      Database Driver:   $DB_DRIVER"
echo "      Database Host:     $DB_HOST"
echo "      Database Port:     $DB_PORT"
echo "      Database Username: $DB_USER"
echo "      Database Password: $DB_PASS"
echo "      Database Name:     $DB_NAME"
echo

for ((i=0;i<20;i++))
do
    DB_CONNECTABLE=$(PGPASSWORD=$DB_PASS psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -l >/dev/null 2>&1; echo "$?")
	if [[ $DB_CONNECTABLE -eq 0 ]]; then
		break
	fi
    sleep 3
done

if ! [[ $DB_CONNECTABLE -eq 0 ]]; then
	echo "Cannot connect to database"
    exit "${DB_CONNECTABLE}"
fi


### Initial setup if database doesn't exist

# Check if tables are there and that drush works
DB_LOADED=$(PGPASSWORD=$DB_PASS psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'result_file');")
if [[ $DB_LOADED != "t" ]]
then
	run_scripts setup
	echo "=> Done installing site!"
else
	echo "=> Skipped setup - database ${DB_NAME} already exists."
fi


###

run_scripts pre-launch

if [ "$JOBS_METHOD" == "drmaa" ]; then
    export LD_PRELOAD="/usr/local/sge/lib/lx-amd64/libdrmaa.so /usr/local/lib/php/extensions/no-debug-non-zts-20160303/sge.so"
fi

exec apache2-foreground

exit 1
