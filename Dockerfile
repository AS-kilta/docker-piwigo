# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.21

# set version label
ARG BUILD_DATE
ARG VERSION
ARG PIWIGO_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"

ENV PHP_INI_SCAN_DIR=":/config/php"

RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    exiftool \
    ffmpeg \
    nginx \
    openssl \
    imagemagick \
    imagemagick-heic \
    libjpeg-turbo-utils \
    mediainfo \
    php83-apcu \
    php83-cgi \
    php83-ctype \
    php83-curl \
    php83-dom \
    php83-exif \
    php83-gd \
    php83-ldap \
    php83-mysqli \
    php83-mysqlnd \
    php83-pear \
    php83-pecl-imagick \
    php83-xsl \
    php83-zip \
    poppler-utils \
    re2c \
    apache2-utils \
    git \
    logrotate \
    nano \
    php83 \
    php83-ctype \
    php83-curl \
    php83-fileinfo \
    php83-fpm \
    php83-iconv \
    php83-json \
    php83-mbstring \
    php83-openssl \
    php83-phar \
    php83-session \
    php83-simplexml \
    php83-xml \
    php83-xmlwriter \
    php83-zip \
    php83-zlib && \

    echo "**** configure nginx ****" && \
  echo 'fastcgi_param  HTTP_PROXY         ""; # https://httpoxy.org/' >> \
    /etc/nginx/fastcgi_params && \
  echo 'fastcgi_param  PATH_INFO          $fastcgi_path_info; # http://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_split_path_info' >> \
    /etc/nginx/fastcgi_params && \
  echo 'fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name; # https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/#connecting-nginx-to-php-fpm' >> \
    /etc/nginx/fastcgi_params && \
  echo 'fastcgi_param  SERVER_NAME        $host; # Send HTTP_HOST as SERVER_NAME. If HTTP_HOST is blank, send the value of server_name from nginx (default is `_`)' >> \
    /etc/nginx/fastcgi_params && \
  rm -f /etc/nginx/conf.d/stream.conf && \
  rm -f /etc/nginx/http.d/default.conf && \

    echo "**** guarantee correct php version is symlinked ****" && \
  if [ "$(readlink /usr/bin/php)" != "php83" ]; then \
    rm -rf /usr/bin/php && \
    ln -s /usr/bin/php83 /usr/bin/php; \
  fi && \
  echo "**** configure php ****" && \
  sed -i "s#;error_log = log/php83/error.log.*#error_log = /config/log/php/error.log#g" \
    /etc/php83/php-fpm.conf && \
  sed -i "s#user = nobody.*#user = abc#g" \
    /etc/php83/php-fpm.d/www.conf && \
  sed -i "s#group = nobody.*#group = abc#g" \
    /etc/php83/php-fpm.d/www.conf && \
  echo "**** add run paths to php runtime config ****" && \
  grep -qxF 'include=/config/php/*.conf' /etc/php83/php-fpm.conf || echo 'include=/config/php/*.conf' >> /etc/php83/php-fpm.conf && \
  echo "**** install php composer ****" && \
  EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')" && \
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
  ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")" && \
  if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then \
    >&2 echo 'ERROR: Invalid installer checksum' && \
    rm composer-setup.php && \
    exit 1; \
  fi && \
  php composer-setup.php --install-dir=/usr/bin && \
  rm composer-setup.php && \
  ln -s /usr/bin/composer.phar /usr/bin/composer && \
  echo "**** fix logrotate ****" && \
  sed -i "s#/var/log/messages {}.*# #g" \
    /etc/logrotate.conf && \
  sed -i 's#/usr/sbin/logrotate /etc/logrotate.conf#/usr/sbin/logrotate /etc/logrotate.conf -s /config/log/logrotate.status#g' \
    /etc/periodic/daily/logrotate && \

  echo "**** modify php-fpm process limits ****" && \
  sed -i 's/pm.max_children = 5/pm.max_children = 32/' /etc/php83/php-fpm.d/www.conf && \
  echo "**** download piwigo ****" && \
  if [ -z ${PIWIGO_RELEASE+x} ]; then \
    PIWIGO_RELEASE=$(curl -sX GET "https://api.github.com/repos/Piwigo/Piwigo/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  mkdir -p /app/www/public && \
  curl -o \
    /tmp/piwigo.zip -L \
    "https://piwigo.org/download/dlcounter.php?code=${PIWIGO_RELEASE}" && \
  unzip -q /tmp/piwigo.zip -d /tmp && \
  mv /tmp/piwigo/* /app/www/public && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \  
  echo "**** cleanup ****" && \
  rm -rf \
    /tmp/*

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 80

VOLUME /config /gallery
