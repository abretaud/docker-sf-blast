FROM php:7.1-apache-buster

MAINTAINER Anthony Bretaudeau <anthony.bretaudeau@inra.fr>

WORKDIR /var/www

RUN mkdir -p /usr/share/man/man1 /usr/share/man/man7

ADD apt_genouest_priority /etc/apt/preferences.d/apt_genouest_priority

# Install packages and PHP-extensions
# apt-key adv --keyserver keyserver.ubuntu.com --recv-key 64D3DCC02B3AC23A8D96059FC41FF1AADA6E6518
RUN apt-get -q update \
&& DEBIAN_FRONTEND=noninteractive apt-get -yq upgrade \
&& DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install gnupg2 \
&& echo "deb [trusted=yes] https://apt.genouest.org/buster/ buster main" > /etc/apt/sources.list.d/slurm_genouest.list \
&& apt-get -q update \
&& DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install \
    file libfreetype6 libjpeg62-turbo libpng16-16 libpq-dev libx11-6 libxpm4 gnupg \
    postgresql-client wget patch git unzip ncbi-blast+ python3-pip python3-dev python3-setuptools python3-wheel \
    cron libhwloc5 build-essential libssl-dev \
    zlib1g zlib1g-dev dirmngr libslurm42t64 "slurm-client=24.11.0*" munge nano \
 && curl -sL https://deb.nodesource.com/setup_6.x | bash - \
 && DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install \
     nodejs npm \
 && docker-php-ext-install mbstring pdo_pgsql zip \
 && rm -rf /var/lib/apt/lists/* \
 && a2enmod rewrite && a2enmod proxy && a2enmod proxy_http \
 && npm install -g uglify-js uglifycss \
 && ln -s /usr/lib/x86_64-linux-gnu/libssl.so /usr/lib/x86_64-linux-gnu/libssl.so.10 \
 && ln -s /usr/lib/x86_64-linux-gnu/libcrypto.so /usr/lib/x86_64-linux-gnu/libcrypto.so.10 \
 && update-alternatives --install /usr/bin/python python /usr/bin/python3 1

ENV TINI_VERSION v0.9.0
RUN set -x \
     && curl -fSL "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini" -o /usr/local/bin/tini \
     && chmod +x /usr/local/bin/tini

ENTRYPOINT ["/usr/local/bin/tini", "--"]

# Some env var for slurm only
ENV DRMAA_LIB_DIR /etc/slurm/drmaa

# Download PHP DRMAA extension code
# Slurm version
RUN cd /opt/ \
    && git clone https://github.com/genouest/php_drmaa.git \
    && mv /usr/local/bin/php /usr/local/bin/php_orig

ADD php/php_wrapper.sh /usr/local/bin/php

ADD requirements.txt /tmp/requirements.txt

RUN pip3 install -r /tmp/requirements.txt

# Install composer
RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
    && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --snapshot \
    && rm -f /tmp/composer-setup.*

# Install Symfony and blast bundles
RUN echo "memory_limit = -1" > $PHP_INI_DIR'/conf.d/memory-limit.ini' \
    && composer create-project symfony/framework-standard-edition --quiet blast "2.8.*" \
    && cd blast \
    && composer require genouest/bioinfo-bundle \
    && composer require genouest/scheduler-bundle \
    && composer require genouest/blast-bundle \
    && composer require symfony/assetic-bundle \
    && sed -i '/\$bundles = array/a new Genouest\\Bundle\\BioinfoBundle\\GenouestBioinfoBundle(),' app/AppKernel.php \
    && sed -i '/\$bundles = array/a new Genouest\\Bundle\\SchedulerBundle\\GenouestSchedulerBundle(),' app/AppKernel.php \
    && sed -i '/\$bundles = array/a new Genouest\\Bundle\\BlastBundle\\GenouestBlastBundle(),' app/AppKernel.php \
    && sed -i '/\$bundles = array/a new Symfony\\Bundle\\AsseticBundle\\AsseticBundle(),' app/AppKernel.php \
    && sed -i 's|, UrlGeneratorInterface::RELATIVE_PATH||' vendor/genouest/scheduler-bundle/Genouest/Bundle/SchedulerBundle/Controller/SchedulerController.php \
    && sed -i 's|$this->generateUrl|rtrim($this->container->getParameter("base_url_path"), "/") . $this->generateUrl|' vendor/genouest/scheduler-bundle/Genouest/Bundle/SchedulerBundle/Controller/SchedulerController.php \
    && sed -i 's|$this->generateUrl|rtrim($this->container->getParameter("base_url_path"), "/") . $this->generateUrl|' vendor/genouest/blast-bundle/Genouest/Bundle/BlastBundle/Controller/BlastController.php \
    && rm web/favicon.ico \
    && cd .. \
    && rm -rf html \
    && ln -s /var/www/blast/web html \
    && sed -i "/createFromGlobals/a Request::setTrustedProxies(array('127.0.0.1', \$request->server->get('REMOTE_ADDR')));" /var/www/blast/web/app.php

ENV DB_HOST='postgres'\
    DB_PORT='5432'\
    DB_NAME='postgres'\
    DB_USER='postgres'\
    DB_PASS='postgres'\
    MAILER_HOST='127.0.0.1'\
    MAILER_USER='null'\
    MAILER_PASS='null'\
    ENABLE_OP_CACHE=1\
    ADMIN_EMAIL='root@blast'\
    ADMIN_NAME='Blast server'\
    JOBS_METHOD='local'\
    DRMAA_METHOD='slurm' \
    SLURMGID='992' \
    SLURMUID='992' \
    MUNGEGID='991' \
    MUNGEUID='991' \
    JOBS_WORK_DIR='/tmp/'\
    JOBS_DRMAA_NATIVE=''\
    CDD_DELTA_PATH=''\
    BLAST_TITLE=''\
    JOBS_SCHED_NAME='blast'\
    PRE_CMD=''\
    LINK_CMD='python3 ./bin/blast_links.py --config ./bin/links.yml --gff-url \$GFF3_URL'\
    BASE_URL_PATH='/'\
    RESULT_URL_HOST='""'

# Influxdb stuff
ENV DELAY=1440 \
    INFLUX_HOST='' \
    INFLUX_PORT=8086 \
    INFLUX_DB=sfblast

RUN mkdir /var/spool/slurmctld /var/spool/slurmd /var/run/slurm /var/log/slurm && \
    chown -R slurm:slurm /var/spool/slurmctld /var/spool/slurmd /var/run/slurm /var/log/slurm && \
    chmod 755 /var/spool/slurmctld /var/spool/slurmd /var/run/slurm /var/log/slurm

ADD form/BlastRequest.php /var/www/blast/vendor/genouest/blast-bundle/Genouest/Bundle/BlastBundle/Entity/BlastRequest.php

ADD monitoring/ /monitoring/

ADD entrypoint.sh /
ADD startup_tasks.sh /
ADD /scripts/ /scripts/
ADD bin/blast_links.py /usr/local/bin/blast_links.py
ADD bin/xml2gff3.py /usr/local/bin/xml2gff3.py

ADD config/parameters.yml.tmpl /opt/parameters.yml.tmpl
ADD config/config.yml /var/www/blast/app/config/config.yml
ADD config/routing.yml /var/www/blast/app/config/routing.yml
ADD config/banks.yml /var/www/blast/app/config/banks.yml
ADD config/links.yml /var/www/blast/app/config/links.yml

CMD ["/entrypoint.sh"]
