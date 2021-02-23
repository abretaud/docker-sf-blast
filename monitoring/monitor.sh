#!/bin/sh

# wait a bit for startup
sleep 180

while true
do
  python /monitoring/monitor.py "postgresql://$DB_USER:$DB_PASS@$DB_HOST/$DB_NAME" "$INFLUX_HOST" "$INFLUX_PORT" "$INFLUX_DB" "$JOBS_SCHED_NAME" --yesterday $OPTIONS
  sleep $((60*$DELAY))
done
