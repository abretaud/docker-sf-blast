# Docker Image for a Blast form based on Symfony

[![Docker Repository on Quay](https://quay.io/repository/abretaud/sf-blast/status "Docker Repository on Quay")](https://quay.io/repository/abretaud/sf-blast)

This image contains a ready-to-go blast form based on the Symfony framework.

## Using the Container

We highly recommend using a `docker-compose.yml` to run your containers.
The following example will run 2 docker containers:

 - `blast`: contains the Blast form code served by an Apache server
 - `db`: a postgresql server hosting the information about the Blast jobs

```yaml
version: "2"
services:
  blast:
    image: quay.io/abretaud/sf-blast:latest
    links:
      - db:postgres
    environment:
      UPLOAD_LIMIT: 20M
      MEMORY_LIMIT: 128M
      DB_NAME: 'postgres'
      ADMIN_EMAIL: 'admin@blast-server'
      ADMIN_NAME: 'Blast admin'
      JOBS_METHOD: 'local'
      JOBS_WORK_DIR: '/tmp/'
      JOBS_DRMAA_NATIVE: ''
      CDD_DELTA_PATH: ''
      BLAST_TITLE: 'My brand new blast server'
      JOBS_SCHED_NAME: 'my_blast'
      PRE_CMD: ''
      LINK_CMD: ''
    volumes:
      - ./config/banks.yml:/var/www/blast/app/config/banks.yml:ro
      - ./config/links.yml:/etc/blast_links/links.yml:ro
    ports:
      - "3000:80"
  db:
    image: postgres:9.5
    environment:
      - POSTGRES_PASSWORD=postgres
      - PGDATA=/var/lib/postgresql/data/
    volumes:
      - /var/lib/postgresql/data/
```

## Configuring the Container

You should populate the config/banks.yml file with the list of banks available. This file should be mounted to /var/www/blast/app/config/banks.yml when running the docker (see example above).
The bank path must be mounted in the docker (for local execution) and/or on the compute node (for drmaa execution).

Here's an example of banks.yml:

```yml
genouest_blast:
    db_provider:
        list:
            nucleic:      {'/db/some/bank': 'My bank 1', '/db/some/other/bank': 'My bank 2'
            proteic:      {'/db/some/protein/bank': 'My protein bank 1', '/db/some/other/protein/bank': 'My protein bank 2'}
```

Another example in case you don't have protein databank:

```yml
genouest_blast:
    db_provider:
        list:
            nucleic:      {'/db/some/bank': 'My bank 1', '/db/some/other/bank': 'My bank 2'
            proteic:      ~
```

To add hyperlinks to the blast result html file, you should populate the config/links.yml file following the syntax explained in it. This file should be mounted to /etc/blast_links/links.yml when running the docker (see example above).

Here's an example of links.yml:

```yml
        genome:    # you can give any name, it is not used by the script
            db:                     '\w+genome\w+'    # optional regex to restrict to a specific blast database
            '(scaffold\w+)':         '<a href="http://tripal/{id}"></a> <a href="http://jbrowse?loc={id}">JBrowse</a>'    # key is a regex to match seq ids, value is a full html block, or simply an http url
            '(superscaffold\w+)':    'http://tripal/{id}'
            '(hyperscaffold\w+)':    'http://jbrowse?loc={id}{jbrowse_track}' # {jbrowse_track} will be replaced by proper argument to add a custom jbrowse track based on the gff_url
            '(xxscaffold\w+)':    'http://apollo?loc={id}{apollo_track}' # {apollo_track} will be replaced by proper argument to add a custom jbrowse track based on the gff_url
            '(yyscaffold\w+)':    'http://google/{gff_url}' # {gff_url} will be replaced by the url of the gff output
        protein:
            db:                     '.+protein.+'
            '*':                    'http://tripal/{id}'
        other:
            '*':                    'http://google/{id}'
```

The following environment variables are also available:

```
UPLOAD_LIMIT: 20M # Maximum size of uploaded files
MEMORY_LIMIT: 128M # Maximum memory used by PHP
DB_HOST: 'postgres' # Hostname of the SQL server
DB_PORT: '5432' # Port to connect to the SQL server
DB_NAME: 'postgres' # SQL database name
DB_USER: 'postgres' # User name for SQL server
DB_PASS: 'postgres' # Password for SQL server

ENABLE_OP_CACHE: 1 # To enable/disable the PHP opcache

ADMIN_EMAIL: 'root@blast' # The sender email address for emails sent to users
ADMIN_NAME: 'Blast server' # The sender name for emails sent to users

BLAST_TITLE: 'Blast server (v2.2.29+)' # Title displayed in the blast form (default: none)
CDD_DELTA_PATH: '' # Path to the CDD DELTA databank if available (otherwise deltablast will not be available)
PRE_CMD: '' # If you need you can add a command that will be executed just before running the blast job.
LINK_CMD: 'python ./bin/blast_links.py --config ./bin/links.yml' # A command to add links to html file (e.g. 'add_links.py --really', path to input html will be appended, should write to stdout)

JOBS_METHOD: 'local' # Should the jobs be executed locally ('local'), or on a cluster with DRMAA ('drmaa')
JOBS_WORK_DIR: '/tmp/' # Directory where job files will be created. Is using DRMAA, must be mounted on computing nodes, at the same location
JOBS_DRMAA_NATIVE: '' # Any native specification you want to pass to DRMAA (when JOBS_METHOS='drmaa', e.g. '-q dev')
JOBS_SCHED_NAME: 'blast' # The names given to jobs (in particular for drmaa jobs)

DRMAA_METHOD: 'slurm' # 'sge' or 'slurm' depending on the cluster type you are using
SLURMGID: '992' # the gid of the slurm group (should be the same as on your slurm cluster)
SLURMUID: '992' # the uid of the slurm user (should be the same as on your slurm cluster)
MUNGEGID: '991' # the gid of the munge group (should be the same as on your slurm cluster)
MUNGEUID: '991' # the uid of the munge user (should be the same as on your slurm cluster)
```

## Using DRMAA

To use DRMAA, you need to pay attention to several things (only tested with SGE and Slurm):

### Slurm

Slurm libraries are installed in version 18.08 (from Debian Buster). It should match the version installed on your cluster to work properly.

#### Environment variables

If you're using Slurm, you should set the `DRMAA_METHOD` environment variable to `slurm`

#### Mounts

You need to mount the slurm configuration files from your cluster to the /etc/slurm-llnl/ directory.
You also need to mount the libdrmaa.so library to $DRMAA_LIB_DIR directory (/etc/slurm-llnl/drmaa/ by default).
And you need to mount the munge conf directory which stores the munge key specific to your cluster.
All this shouldlook something like that:

```
volumes:
  - /etc/slurm/slurm.conf:/etc/slurm-llnl/slurm.conf:ro
  - /etc/slurm/gres.conf:/etc/slurm-llnl/gres.conf:ro
  - /etc/slurm/cgroup.conf:/etc/slurm-llnl/cgroup.conf:ro
  - /etc/slurm/slurmdbd.conf:/etc/slurm-llnl/slurmdbd.conf:ro
  - /etc/slurm/drmaa/:/etc/slurm-llnl/drmaa/:ro
  - /etc/munge/:/etc/munge/:ro
```

#### DRMAA user

Jobs will probably need to be launched by a user known by the scheduler. You will to use the following options to configure this:

```
APACHE_RUN_USER: 'submituser'
APACHE_RUN_GROUP: 'submitgroup'
UID: 55914
GID: 40259
```

When launching the container, it will automatically configure itself to run apache with the user and group names and ids specified.

### With SGE

Please note that the latest version of this image was not tested with SGE. It should work in theory, but not guaranteed.

#### Environment variables

If you're using SGE, you should set the `DRMAA_METHOD` environment variable to `sge`

#### Mounts

Depending on your cluster setup, you will probably need to mount a shared directory containing the scheduler binaries.
It should be mounted to /usr/local/sge/

```
volumes:
    - /sge/:/usr/local/sge/:ro
```

#### DRMAA user

Jobs will probably need to be launched by a user known by the scheduler. You will to use the following options to configure this:

```
APACHE_RUN_USER: 'submituser'
APACHE_RUN_GROUP: 'submitgroup'
UID: 55914
GID: 40259
```

When launching the container, it will automatically configure itself to run apache with the user and group names and ids specified.

#### Dealing with restriction on submission node

By default the container is using the default docker `bridge` network. One of the consequence is that the container's hostname is a random string.
As SGE allows submitting jobs from a list of known hostname, having a variable hostname is a problem.
To fix this, we need to give a fixed hostname to our container. This hostname must be registered as a submit_host (`qconf -as my_blast`).

```
version: "2"
services:
  blast:
    image: quay.io/abretaud/sf-blast:latest
    links:
      - db:postgres
    hostname: my_blast
```

The master node does some checks on the hostname and corresponding ip, so you might need to add soemthing like this in `/etc/hosts`:

```
<docker-host-ip> my_blast <real-name-of-the-docker-host>
```

### Blast binaries (SGE and Slurm)

When using drmaa, ensure that blast binaries + python (with bcbio-gff, yaml and yamlordereddictloader modules) are in the PATH (using PRE_CMD).
