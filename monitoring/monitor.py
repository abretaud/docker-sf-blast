#!/usr/bin/env python

import click
import datetime

from influxdb import InfluxDBClient
from sqlalchemy import create_engine


class SfblastMonitor():

    db_string = None
    engine = None
    connection = None
    influx = None

    def __init__(self, db_string, influx_host, influx_port, influx_db, form_name, suffix):
        self.db_string = db_string
        self.influx_host = influx_host
        self.influx_port = influx_port
        self.influx_db = influx_db
        self.form_name = form_name
        self.suffix = suffix

    def influx_client(self):
        if self.influx is None:
            self.influx = InfluxDBClient(host=self.influx_host, port=self.influx_port)

            # Check if db exists, create it if not
            dbs = self.influx.get_list_database()
            dbs = [x['name'] for x in dbs]
            if self.influx_db not in dbs:
                self.influx.create_database(self.influx_db)

            self.influx.switch_database(self.influx_db)

        return self.influx

    def connect(self):
        if self.connection is None:
            self.engine = create_engine(self.db_string)
            self.connection = self.engine.connect()

        return self.connection

    def get_jobs(self, day):

        next_day = day + datetime.timedelta(days=1)

        con = self.connect()

        res = con.execute("""SELECT job_uid
            FROM job
            where created_at > '%s'::date
            and created_at <= '%s'::date""" % (day.strftime("%Y.%m.%d"), next_day.strftime("%Y.%m.%d")))

        jobs = []
        for x in res:
            jobs.append(x[0])

        return jobs

    def prepare_influx_points(self, measure, value, day):

        points = []
        points.append({
            "measurement": "blast.%s" % (measure),
            "time": int(day.timestamp()) * 1000000000,
            "tags": {
                "form": self.form_name
            },
            "fields": {
                "value": value
            }
        })

        return points

    def prepare_influx_points_by_x(self, measure, value, by_x, day):

        points = []
        for elem in value:
            points.append({
                "measurement": "blast.%s" % (measure),
                "time": int(day.timestamp()) * 1000000000,
                "tags": {
                    "form": self.form_name,
                    by_x: elem
                },
                "fields": {
                    "value": value[elem]
                }
            })

        return points

    def write(self, points):

        influx = self.influx_client()
        influx.write_points(points)

    def collect_metrics(self, day, dry_run):

        points = []

        click.echo("Collecting stats for day: %s" % day)

        jobs = self.get_jobs(day)
        click.echo("Found %s jobs" % (len(jobs)))

        points += self.prepare_influx_points("jobs", len(jobs), day)

        click.echo("InfluxDB points: %s" % points)

        if not dry_run:
            click.echo("Writing to InfluxDB")
            self.write(points)
        else:
            click.echo("Not writing to InfluxDB (dry-run mode)")


@click.command()
@click.argument('db_string')
@click.argument('influx_host')
@click.argument('influx_port')
@click.argument('influx_db')
@click.argument('form_name')
@click.option('--suffix', default="", help="Remove given suffix from user ids")
@click.option('--from-date', default="", help="Collect data from given date (format: YYYYMMDD, e.g. 20181025)")
@click.option('--to-date', default="", help="Collect data until given date (format: YYYYMMDD, e.g. 20181025)")
@click.option('-d', '--dry-run', help='Do not write any influxdb data, just fetch and print stats on stdout', is_flag=True)
@click.option('--yesterday', help='Collect jobs from yesterday (=last finished day)', is_flag=True)
def monitor(db_string, influx_host, influx_port, influx_db, form_name, suffix, from_date, to_date, dry_run, yesterday):
    mon = SfblastMonitor(db_string, influx_host, influx_port, influx_db, form_name, suffix)

    days = []
    if from_date or to_date:

        if not from_date or not to_date:
            raise RuntimeError("Give a starting date %s AND an ending date %s" % (from_date, to_date))

        if yesterday:
            raise RuntimeError("Don't use --yesterday with a starting date %s AND an ending date %s" % (from_date, to_date))

        from_date = datetime.datetime.strptime(from_date, '%Y%m%d')
        to_date = datetime.datetime.strptime(to_date, '%Y%m%d')

        if from_date == to_date:
            raise RuntimeError("Give a starting date %s and an ending date %s that are different" % (from_date, to_date))

        if from_date > to_date:
            raise RuntimeError("Starting date %s should be before ending date %s" % (from_date, to_date))

        delta = to_date - from_date

        for i in range(delta.days + 1):
            day = from_date + datetime.timedelta(days=i)
            days.append(day)
    else:
        # Get today's date, at midnight
        days = [datetime.datetime.combine(datetime.date.today(), datetime.datetime.min.time())]
        if yesterday:
            days[0] = days[0] - datetime.timedelta(days=1)

    click.echo("Will run for the following day(s):")
    for day in days:
        print(day)

    for day in days:
        mon.collect_metrics(day, dry_run)


if __name__ == '__main__':
    monitor()
