#!/bin/bash
set -e

/startup_tasks.sh

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

if [ ! -z "${INFLUX_HOST}" ]; then
	/monitoring/monitor.sh &
fi

exec apache2-foreground

exit 1
