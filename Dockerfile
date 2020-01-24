# file based on example from nextcloud.com
FROM php:fpm-alpine

# latest commit hash from master @ git.tt-rss-org
ENV tt-rss-container-version "deefa901ab"

# entrypoint.sh and cron.sh dependencies
RUN set -ex; \
    \
    apk add --no-cache \
        rsync \
        sed \
        git \
        postgresql-client \
    ;

# install the PHP extensions we need
RUN set -ex; \
    \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        autoconf \
        curl-dev \
        freetype-dev \
        icu-dev \
        libjpeg-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
        oniguruma-dev \
        pcre-dev \
        postgresql-dev \
        git \
    ; \
    \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install \
        curl \
        fileinfo \
        gd \
        intl \
        json \
        mbstring \
        opcache \
        pcntl \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        xml \
        zip \
    ; \
    \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --virtual .ttrss-phpext-rundeps $runDeps ; \
    apk del .build-deps

# set recommended PHP.ini settings
RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.enable_cli=1'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=10000'; \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.save_comments=1'; \
        echo 'opcache.revalidate_freq=1'; \
    } > $PHP_INI_DIR/conf.d/opcache-recommended.ini; \
    \
    echo 'apc.enable_cli=1' >> $PHP_INI_DIR/conf.d/docker-php-ext-apcu.ini; \
    \
    echo 'memory_limit=512M' > $PHP_INI_DIR/conf.d/memory-limit.ini; \
    \
    chown -R www-data:root /var/www; \
    chmod -R g=u /var/www

VOLUME /var/www/html

WORKDIR /usr/src

RUN git clone --branch master --depth 1 https://git.tt-rss.org/fox/tt-rss.git ; \
    cd tt-rss ; \
    git log --pretty="%ct" -n1 HEAD 2>&1 > timestamp ; \
    git log --pretty="%h" -n1 HEAD 2>&1 > version ; 

# installing plugin_zip
#RUN curl -fsSL -o plugin.tar.gz \
#        "https://gogs.meyca.de/carstenmeyer/ttrss_plugin-feediron/archive/master.tar.gz" ; \
#    tar -xzf plugin.tar.gz -C /usr/src/tt-rss/plugins.local ; \
#    mv /usr/src/tt-rss/plugins.local/ttrss_plugin-feediron /usr/src/tt-rss/plugins.local/feediron; \
#    rm plugin.tar.gz ;

COPY *.sh /
COPY upgrade.exclude /

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
