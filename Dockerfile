FROM php:7-apache

MAINTAINER Anthony Bretaudeau <anthony.bretaudeau@inra.fr>

ENV TINI_VERSION v0.9.0
RUN set -x \
    && curl -fSL "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini" -o /usr/local/bin/tini \
    && curl -fSL "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini.asc" -o /usr/local/bin/tini.asc \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 6380DC428747F6C393FEACA59A84159D7001A4E5 \
    && gpg --batch --verify /usr/local/bin/tini.asc /usr/local/bin/tini \
    && rm -r "$GNUPGHOME" /usr/local/bin/tini.asc \
    && chmod +x /usr/local/bin/tini

ENTRYPOINT ["/usr/local/bin/tini", "--"]

WORKDIR /var/www

# Install packages and PHP-extensions
RUN apt-get -q update && \
    DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install \
    file libfreetype6 libjpeg62 libpng12-0 libpq-dev libx11-6 libxpm4 \
    postgresql-client wget patch git unzip npm ncbi-blast+ python-pip libyaml-dev \
    python-dev cron libhwloc5 \
 && docker-php-ext-install mbstring pdo_pgsql zip \
 && rm -rf /var/lib/apt/lists/* \
 && a2enmod rewrite && a2enmod proxy && a2enmod proxy_http \
 && npm install -g uglify-js uglifycss \
 && ln -s /usr/bin/nodejs /usr/bin/node \
 && ln -s /usr/lib/x86_64-linux-gnu/libssl.so /usr/lib/x86_64-linux-gnu/libssl.so.10 \
 && ln -s /usr/lib/x86_64-linux-gnu/libcrypto.so /usr/lib/x86_64-linux-gnu/libcrypto.so.10

# Install PHP DRMAA extension
RUN curl -o /opt/drmPhpExtension_1.2.tar.gz https://gforge.inria.fr/frs/download.php/file/28916/drmPhpExtension_1.2.tar.gz \
    && cd /opt/ \
    && tar -xzvf drmPhpExtension_1.2.tar.gz \
    && rm drmPhpExtension_1.2.tar.gz \
    && sed -i 's/RETURN_STRING(jobid, 1)/RETURN_STRING(jobid)/g' sge/sge.c \
    && mv /usr/local/bin/php /usr/local/bin/php_orig

ADD php/php_wrapper.sh /usr/local/bin/php

RUN pip install pyaml yamlordereddictloader bcbio-gff biopython

# Install composer
RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
    && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --snapshot \
    && rm -f /tmp/composer-setup.*

ENV CACHE_BUST=3

# Install Symfony and blast bundles
RUN composer create-project symfony/framework-standard-edition --quiet blast "2.8.*" \
    && cd blast \
    && composer require genouest/bioinfo-bundle \
    && composer require genouest/scheduler-bundle \
    && composer require genouest/blast-bundle \
    && composer require symfony/assetic-bundle \
    && sed -i '/\$bundles = array/a new Genouest\\Bundle\\BioinfoBundle\\GenouestBioinfoBundle(),' app/AppKernel.php \
    && sed -i '/\$bundles = array/a new Genouest\\Bundle\\SchedulerBundle\\GenouestSchedulerBundle(),' app/AppKernel.php \
    && sed -i '/\$bundles = array/a new Genouest\\Bundle\\BlastBundle\\GenouestBlastBundle(),' app/AppKernel.php \
    && sed -i '/\$bundles = array/a new Symfony\\Bundle\\AsseticBundle\\AsseticBundle(),' app/AppKernel.php \
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
    JOBS_WORK_DIR='/tmp/'\
    JOBS_DRMAA_NATIVE=''\
    CDD_DELTA_PATH=''\
    BLAST_TITLE=''\
    JOBS_SCHED_NAME='blast'\
    PRE_CMD=''\
    LINK_CMD='python ./bin/blast_links.py --config ./bin/links.yml'\
    BASE_URL_PATH='/'

ADD form/BlastRequest.php /var/www/blast/vendor/genouest/blast-bundle/Genouest/Bundle/BlastBundle/Entity/BlastRequest.php

ADD entrypoint.sh /
ADD /scripts/ /scripts/
ADD bin/blast_links.py /usr/local/bin/blast_links.py
ADD bin/xml2gff3.py /usr/local/bin/xml2gff3.py

ADD config/parameters.yml.tmpl /opt/parameters.yml.tmpl
ADD config/config.yml /var/www/blast/app/config/config.yml
ADD config/routing.yml /var/www/blast/app/config/routing.yml
ADD config/banks.yml /var/www/blast/app/config/banks.yml
ADD config/links.yml /var/www/blast/app/config/links.yml

CMD ["/entrypoint.sh"]
