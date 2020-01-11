#!/bin/sh
set -eu

# version_greater A B returns whether A > B
version_greater() {
  [ "$1" -gt "$2" ]
}

installed_version="0"

if [ -f /var/www/html/timestamp ]; then
  installed_version="$(cat /var/www/html/timestamp)"
fi

image_version="$(cat /usr/src/tt-rss/timestamp)"

if version_greater "$installed_version" "$image_version"; then
    echo "Can't start TT-RSS because the version of the data ($installed_version) is higher than the docker image version ($image_version) and downgrading is not supported. Are you sure you have pulled the newest image version?"
    exit 1
fi

if version_greater "$image_version" "$installed_version"; then
  echo "Initializing TT-RSS $image_version ..."
  if [ "$installed_version" != "0" ]; then
    echo "Upgrading TT-RSS from $installed_version ..."
    rsync_options="--exclude-from /upgrade.exclude "
  else
    echo "New Install "
    rsync_options=""
  fi

  if [ "$(id -u)" = 0 ]; then
      rsync_options=$rsync_options"-rlDog --chown www-data:root "
  else
      rsync_options=$rsync_options"-rlD "
  fi
  rsync $rsync_options --delete /usr/src/tt-rss/ /var/www/html/

  echo "Initializing finished"
fi

# modifying configuration based on environment variables

echo "Creating config.php from environment"

if [ ! -f /var/www/html/config.php ] ; then
  cp /var/www/html/config.php-dist /var/www/html/config.php
fi

if [ ! -z "${TT_RSS_DB_TYPE+x}" ] ; then
  sed -i "/DB_TYPE/ s/pgsql/$TT_RSS_DB_TYPE/" /var/www/html/config.php
fi
if [ ! -z "${TT_RSS_DB_HOST+x}" ] ; then
  sed -i "/DB_HOST/ s/localhost/$TT_RSS_DB_HOST/" /var/www/html/config.php
fi
if [ ! -z "${TT_RSS_DB_USER+x}" ] ; then
  sed -i "/DB_USER/ s/fox/$TT_RSS_DB_USER/" /var/www/html/config.php
fi
if [ ! -z "${TT_RSS_DB_NAME+x}" ] ; then
  sed -i "/DB_NAME/ s/fox/$TT_RSS_DB_NAME/" /var/www/html/config.php
fi
if [ ! -z "${TT_RSS_DB_PASS+x}" ] ; then
  sed -i "/DB_PASS/ s/XXXXXX/$TT_RSS_DB_PASS/" /var/www/html/config.php
fi
if [ ! -z "${TT_RSS_DB_PORT+x}" ] ; then
  sed -i "/DB_PORT/ s/''/'$TT_RSS_DB_PORT'/" /var/www/html/config.php
fi
if [ ! -z "${TT_RSS_SELF_URL_PATH+x}" ] ; then
  sed -i "/SELF_URL_PATH/ s/https\:\/\/example.org\/tt-rss\//$TT_RSS_SELF_URL_PATH/" /var/www/html/config.php
fi
if [ ! -z "${TT_RSS_SMTP_FROM_ADDRESS+x}" ] ; then
  sed -i "/SMTP_FROM_ADDRESS/ s/'noreply@your\.domain\.dom'/'$TT_RSS_SMTP_FROM_ADDRESS'/" /var/www/html/config.php
fi

# non-standard location of php PHP_EXECUTABLE in alpine php fpm container
sed -i "/PHP_EXECUTABLE/ s/\/usr\/bin\/php/\/usr\/local\/bin\/php/" /var/www/html/config.php

export PGPASSWORD=${TT_RSS_DB_PASS}

while ! /usr/bin/pg_isready -h "${TT_RSS_DB_HOST}" -U "${TT_RSS_DB_USER}"; do
	echo waiting until "${TT_RSS_DB_HOST}" is ready...
	sleep 3
done

PSQL="/usr/bin/psql -q -h ${TT_RSS_DB_HOST} -U ${TT_RSS_DB_USER} ${TT_RSS_DB_NAME}"

if  [ ! -f /var/www/html/sqlupdate ]; then
  
  touch /var/www/html/sqlupdate;

  $PSQL -c "create extension if not exists pg_trgm";

  if ! $PSQL -c 'select * from ttrss_version'; then
	  $PSQL < /usr/src/tt-rss/schema/ttrss_schema_pgsql.sql
  fi

  rm /var/www/html/sqlupdate;

else
  while [ -f /var/www/html/sqlupdate ]; do
    
    echo waiting until sqlupdate is finished...
    sleep 3
  
  done
fi 

exec "$@"
