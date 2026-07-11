FROM ghcr.io/servercontainers/apache2-ssl-secure

RUN apt-get -q -y update && \
    apt-get -q -y install php-pgsql \
                          php-mbstring \
                          wget && \
    apt-get -q -y clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    \
    rm -rf /var/www/html/* && \
    cd /var/www/html && \
    export DOWNLOAD_URL=$(wget -O - https://api.github.com/repos/phppgadmin/phppgadmin/releases/latest | grep browser_download_url | tr '"' '\n' | grep tar.gz) && \
    wget -O - "$DOWNLOAD_URL" | tar xzvf - && \
    mv php* phppgadmin && \
    \
    # PHP 8 compat: bundled adodb postgres driver still uses PHP4-style constructors
    # which PHP 8 ignores -> "Virtual Class -- cannot instantiate". Convert to __construct.
    sed -i 's/function ADODB_postgres64() /function __construct() /' phppgadmin/libraries/adodb/drivers/adodb-postgres64.inc.php && \
    sed -i 's/function ADODB_postgres7() /function __construct() /' phppgadmin/libraries/adodb/drivers/adodb-postgres7.inc.php && \
    sed -i 's/\$this->ADODB_postgres64();/parent::__construct();/' phppgadmin/libraries/adodb/drivers/adodb-postgres7.inc.php && \
    # postgres 15+ version detection: leading "1" of "16" was read as major 1 (<8) -> "not supported"
    sed -i 's/(int)substr(\$version, 0, 1) < 8/(int)\$version < 8/' phppgadmin/classes/database/Connection.php && \
    \
    chown -R www-data:www-data /var/www/html/phppgadmin && \
    chmod 660 /var/www/html/phppgadmin/conf/config.inc.php

COPY config/www/index.php /var/www/html/index.php
COPY config/runit/phppgadmin /container/config/runit/phppgadmin

COPY . /container-2