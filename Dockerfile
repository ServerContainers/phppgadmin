FROM ghcr.io/servercontainers/apache2-ssl-secure

RUN apt-get -q -y update && \
    apt-get -q -y install php-pgsql \
                          php-mbstring \
                          curl && \
    apt-get -q -y clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    \
    rm -rf /var/www/html/* && \
    cd /var/www/html && \
    export DOWNLOAD_URL=$(curl -s https://api.github.com/repos/phppgadmin/phppgadmin/releases/latest | grep browser_download_url | tr '"' '\n' | grep tar.gz) \
    curl -s "$DOWNLOAD_URL" | tar xzvf - && \
    mv php* phppgadmin && \
    chown -R www-data:www-data /var/www/html/phppgadmin && \
    chmod 660 /var/www/html/phppgadmin/conf/config.inc.php

COPY config/www/index.php /var/www/html/index.php
COPY config/runit/phppgadmin /container/config/runit/phppgadmin

COPY . /container-2