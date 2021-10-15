# geschke/powerdns-server

This is a Docker image with PowerDNS server with MySQL/MariaDB and SQLite3 support.

## Usage

To download the image run

    docker pull geschke/powerdns-server

## Configuration

**Environment Configuration:**

* Generic settings

  * `PDNS_BACKEND=none` Choose between `mysql` and `sqlite3`. The default is `none`, so you can provide your own configuration by mounting pdns.conf into
  * `PDNS_AUTOCONFIG=true`
  * `PDNS_LOCAL_ADDRESS=(empty)` Local address to bind to. If this variable is not set, the default entry in the config file will be used.
  * `PDNS_LOCAL_PORT=(empty)` Local port to bind to. If this variable is not set, the default entry in the config file will be used.
  * `PDNS_MASTER=(empty)` Default value of `master` setting. See PowerDNS documentation.
  * `PDNS_SLAVE=(empty)` Default value of `slave` setting. See PowerDNS documentation.
  * `PDNS_ALLOW_AXFR_IPS=(empty)` Default value of `allow-axfr-ips` setting. See PowerDNS documentation.
  * `PDNS_ALLOW_DNSUPDATE_FROM=(empty)` Default value of `allow-dnsupdate-from` setting. See PowerDNS documentation.
  * `PDNS_ALLOW_NOTIFY_FROM=(empty)` Default value of `allow-notify-from` setting. See PowerDNS documentation.
  * `PDNS_ALLOW_UNSIGNED_NOTIFY=(empty)` Default value of `allow-unsigned-notify` setting. See PowerDNS documentation.
  * `PDNS_TRUSTED_NOTIFICATION_PROXY=(empty)` Default value of `trusted-notification-proxy` setting. See PowerDNS documentation.
  * `PDNS_DNSUPDATE=(empty)` Default value of `dnsupdate` setting. See PowerDNS documentation.

* SQLite3 settings

  * `SQLITE3_PATH=/var/lib/powerdns/pdns.db` Path and filename of SQLite3 database

* MySQL connection settings

  * `MYSQL_HOST=localhost`
  * `MYSQL_PORT=3306`
  * `MYSQL_USER=dbuser`
  * `MYSQL_PASSWORD=<empty>` Password
  * `MYSQL_NAME=powerdns` Name of database

* API Key

  * `PDNS_API_KEY=none` By setting an API key, the built-in webserver and the HTTP API  will be activated. It runs on 0.0.0.0/0 on port 8081 in the container, so if you don't want to provide the API publically, just omit the port setting on 8081 in the docker run command or the compose file.

Skip modifying these parameters by setting PDNS_AUTOCONFIG to "false".

## Usage example

tbd

## Credits

This image is based on the official Ubuntu image, the Ubuntu PowerDNS packages and uses
some snippets of the following Docker images:

* https://github.com/psi-4ward/docker-powerdns
* https://github.com/docker-library/mariadb/blob/master/10.4/docker-entrypoint.sh

The script wait-for-it.sh is provided by https://github.com/vishnubob/wait-for-it/blob/master/wait-for-it.sh 

Thank you all!
