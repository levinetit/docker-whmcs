# Starting with base image (Ubuntu)
FROM lscr.io/linuxserver/baseimage-ubuntu:noble

ARG BUILD_DATE
LABEL build_date="Build-date:- ${BUILD_DATE}"
LABEL maintainer="levinetit"

ARG TARGETARCH
ARG PHP_RELEASE=8.2
ARG WHMCS_RELEASE=8.11

ENV PHP_VERSION=${PHP_RELEASE}
ENV TZ="UTC" PGID="1000" PUID="1000"
ENV AUTH_USER="" AUTH_PASS=""
ENV WHMCS_SERVER_IP="\$server_addr" WHMCS_SERVER_URL="_"
ENV DEBIAN_FRONTEND="noninteractive"

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    cron \
    curl \
    htop \
    jq \
    less \
    net-tools \
    openssl \
    software-properties-common \
    unzip \
    vim \
    wget \
    zip \
    nginx \
    apache2-utils \
    php${PHP_VERSION} \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-imagick \
    php${PHP_VERSION}-igbinary \
    php${PHP_VERSION}-redis \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-enchant \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-imap \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-xmlrpc \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-bz2 \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-curl \
    && apt-get clean

# Install ionCube and SourceGuardian
RUN case ${TARGETARCH} in \
         "amd64")  IONCUBE_ARCH="x86-64"  ;; \
         "arm64")  IONCUBE_ARCH="aarch64" ;; \
    esac && \
    curl -o ioncube.zip http://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_${IONCUBE_ARCH}.zip && \
    unzip -q ioncube.zip && \
    cp ioncube/ioncube_loader_lin_${PHP_VERSION}.so /usr/lib/php/ioncube/ && \
    echo "zend_extension = /usr/lib/php/ioncube/ioncube_loader_lin_${PHP_VERSION}.so" > /etc/php/${PHP_VERSION}/mods-available/00-ioncube.ini && \
    ln -s /etc/php/${PHP_VERSION}/mods-available/00-ioncube.ini /etc/php/${PHP_VERSION}/cli/conf.d/00-ioncube.ini && \
    ln -s /etc/php/${PHP_VERSION}/mods-available/00-ioncube.ini /etc/php/${PHP_VERSION}/fpm/conf.d/00-ioncube.ini

# Ensure php and MySQL are correctly configured
RUN update-alternatives --set php /usr/bin/php${PHP_VERSION} && \
    update-alternatives --install /usr/sbin/php-fpm php-fpm /usr/sbin/php-fpm${PHP_VERSION} 60 && \
    sed -i "s/;date.timezone =/date.timezone = UTC/" /etc/php/${PHP_VERSION}/cli/php.ini && \
    sed -i "s/max_execution_time = 30/max_execution_time = 1800/" /etc/php/${PHP_VERSION}/cli/php.ini

# Download WHMCS 8.11
RUN curl -o /whmcs.zip https://releases.whmcs.com/v2/pkgs/whmcs-8.11-release.zip && \
    unzip /whmcs.zip -d /var/www/whmcs

# Set permissions and clean up
RUN chown -R www-data:www-data /var/www/whmcs && \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# Expose port 80 for HTTP
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
