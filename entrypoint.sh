#!/bin/bash
set -e

## Execute a command as user pdns
exec_as_pdns() {
  sudo -HEu pdns "$@"
}


# The file_env function is taken from https://github.com/docker-library/mariadb - thanks to the Docker community
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    echo "Both $var and $fileVar are set (but are exclusive)"
  fi
  local val="$def"
  if [ "${!var:-}" ]; then
    val="${!var}"
  elif [ "${!fileVar:-}" ]; then
    val="$(< "${!fileVar}")"
  fi
  export "$var"="$val"
  unset "$fileVar"
}


[[ -n $DEBUG_ENTRYPOINT ]] && set -x


# Initialize values that might be stored in a file when using Docker secret
file_env 'MYSQL_HOST'
file_env 'MYSQL_PORT'
file_env 'MYSQL_USER'
file_env 'MYSQL_NAME'
file_env 'MYSQL_PASSWORD'
file_env 'MYSQL_DNSSEC'
file_env 'PDNS_BACKEND'
file_env 'SQLITE3_PATH'
file_env 'PDNS_API_KEY'
file_env 'PDNS_AUTOCONFIG'
file_env 'PDNS_LOCAL_ADDRESS'
file_env 'PDNS_LOCAL_PORT'
file_env 'PDNS_MASTER'
file_env 'PDNS_SLAVE'
file_env 'PDNS_ALLOW_AXFR_IPS'
file_env 'PDNS_ALLOW_DNSUPDATE_FROM'
file_env 'PDNS_ALLOW_NOTIFY_FROM'
file_env 'PDNS_ALLOW_UNSIGNED_NOTIFY'
file_env 'PDNS_DNSUPDATE'
file_env 'PDNS_TRUSTED_NOTIFICATION_PROXY'

PDNS_BACKEND=${PDNS_BACKEND:-none}
PDNS_AUTOCONFIG=${PDNS_AUTOCONFIG:-true}
PDNS_LOCAL_ADDRESS=${PDNS_LOCAL_ADDRESS:-} # IP
PDNS_LOCAL_PORT=${PDNS_LOCAL_PORT:-} # port
PDNS_MASTER=${PDNS_MASTER:-} # boolean
PDNS_SLAVE=${PDNS_SLAVE:-} # boolean
PDNS_ALLOW_AXFR_IPS=${PDNS_ALLOW_AXFR_IPS:-} # IP ranges
PDNS_ALLOW_DNSUPDATE_FROM=${PDNS_ALLOW_DNSUPDATE_FROM:-} # IP ranges
PDNS_ALLOW_NOTIFY_FROM=${PDNS_ALLOW_NOTIFY_FROM:-} # IP ranges
PDNS_ALLOW_UNSIGNED_NOTIFY=${PDNS_ALLOW_UNSIGNED_NOTIFY:-} # boolean
PDNS_TRUSTED_NOTIFICATION_PROXY=${PDNS_TRUSTED_NOTIFICATION_PROXY:-} # String / IP ranges
PDNS_DNSUPDATE=${PDNS_DNSUPDATE:-} # boolean



MYSQL_HOST=${MYSQL_HOST:-localhost}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_USER=${MYSQL_USER:-dbuser}
MYSQL_NAME=${MYSQL_NAME:-powerdns}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-}
MYSQL_DNSSEC=${MYSQL_DNSSEC:-no}

MYSQL_CLI="/usr/bin/mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} --port=${MYSQL_PORT} -r -N"

trap "pdns_control quit" SIGINT SIGTERM

# default database file path
SQLITE3_PATH=${SQLITE3_PATH:-/var/lib/powerdns/pdns.db}

# PowerDNS config file on default path
PDNS_CONFIG_FILE=/etc/powerdns/pdns.conf

PDNS_API_KEY=${PDNS_API_KEY:-none}


if ${PDNS_AUTOCONFIG} ; then

  case ${PDNS_API_KEY} in
    none)
      echo "No API";
      ;;
    *)
      echo "API Key used";

      grep -q "^api=" ${PDNS_CONFIG_FILE} || echo "api=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^api=)(.*)/\1yes/g" ${PDNS_CONFIG_FILE};

      grep -q "^api-key=" ${PDNS_CONFIG_FILE} || echo "api-key=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^api-key=)(.*)/\1${PDNS_API_KEY}/g" ${PDNS_CONFIG_FILE};

      grep -q "^webserver=" ${PDNS_CONFIG_FILE} || echo "webserver=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^webserver=)(.*)/\1yes/g" ${PDNS_CONFIG_FILE};

      grep -q "^webserver-address=" ${PDNS_CONFIG_FILE} || echo "webserver-address=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^webserver-address=)(.*)/\10\.0\.0\.0/g" ${PDNS_CONFIG_FILE};

      grep -q "^webserver-port=" ${PDNS_CONFIG_FILE} || echo "webserver-port=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^webserver-port=)(.*)/\18081/g" ${PDNS_CONFIG_FILE};

      grep -q "^webserver-allow-from=" ${PDNS_CONFIG_FILE} || echo "webserver-allow-from=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^webserver-allow-from=)(.*)/\10\.0\.0\.0\/0/g" ${PDNS_CONFIG_FILE};


    ;;
  esac


  case ${PDNS_BACKEND} in
    mysql)
      echo "MySQL backend, configuring...";
      
      grep -q "^launch=" ${PDNS_CONFIG_FILE} || echo "launch=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^launch=)(.*)/\1g${PDNS_BACKEND}/g" ${PDNS_CONFIG_FILE};

      grep -q "^gmysql-host=" ${PDNS_CONFIG_FILE} || echo "gmysql-host=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^gmysql-host=)(.*)/\1${MYSQL_HOST}/g" ${PDNS_CONFIG_FILE};
      grep -q "^gmysql-port=" ${PDNS_CONFIG_FILE} || echo "gmysql-port=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^gmysql-port=)(.*)/\1${MYSQL_PORT}/g" ${PDNS_CONFIG_FILE};
      grep -q "^gmysql-user=" ${PDNS_CONFIG_FILE} || echo "gmysql-user=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^gmysql-user=)(.*)/\1${MYSQL_USER}/g" ${PDNS_CONFIG_FILE};
      grep -q "^gmysql-dbname=" ${PDNS_CONFIG_FILE} || echo "gmysql-dbname=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^gmysql-dbname=)(.*)/\1${MYSQL_NAME}/g" ${PDNS_CONFIG_FILE};
      grep -q "^gmysql-password=" ${PDNS_CONFIG_FILE} || echo "gmysql-password=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^gmysql-password=)(.*)/\1${MYSQL_PASSWORD}/g" ${PDNS_CONFIG_FILE};
      grep -q "^gmysql-dnssec=" ${PDNS_CONFIG_FILE} || echo "gmysql-dnssec=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^gmysql-dnssec=)(.*)/\1${MYSQL_DNSSEC}/g" ${PDNS_CONFIG_FILE};

      ;;
    sqlite3)
      echo "SQLite3 backend, configuring...";

      grep -q "^launch=" ${PDNS_CONFIG_FILE} || echo "launch=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s/(^launch=)(.*)/\1g${PDNS_BACKEND}/g" ${PDNS_CONFIG_FILE};

      grep -q "^gsqlite3-database=" ${PDNS_CONFIG_FILE} || echo "gsqlite3-database=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
      sed -i -E "s,(^gsqlite3-database=)(.*),\1${SQLITE3_PATH},g" ${PDNS_CONFIG_FILE}; # don't use / as delimiter because of path string

      ;;   
    *)
      echo "No backend or backend not supported, please mount your own pdns.conf";
      ;;
  esac
fi


if [[ ! -z "$PDNS_LOCAL_ADDRESS" ]] ; then

  grep -q "^local-address=" ${PDNS_CONFIG_FILE} || echo "local-address=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
  PDNS_LOCAL_ADDRESS="$(echo $PDNS_LOCAL_ADDRESS | sed 's/\./\\\./g')"
  PDNS_LOCAL_ADDRESS="$(echo $PDNS_LOCAL_ADDRESS | sed 's/\,/\\\,/g')"
  PDNS_LOCAL_ADDRESS="$(echo $PDNS_LOCAL_ADDRESS | sed 's,\/,\\\/,g')"
  sed -i -E "s,(^local-address=)(.*),\1${PDNS_LOCAL_ADDRESS},g" ${PDNS_CONFIG_FILE};

fi

if [[ ! -z "$PDNS_LOCAL_PORT" ]] ; then

  grep -q "^local-port=" ${PDNS_CONFIG_FILE} || echo "local-port=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
  PDNS_LOCAL_PORT="$(echo $PDNS_LOCAL_PORT | sed 's/\./\\\./g')"
  PDNS_LOCAL_PORT="$(echo $PDNS_LOCAL_PORT | sed 's/\,/\\\,/g')"
  PDNS_LOCAL_PORT="$(echo $PDNS_LOCAL_PORT | sed 's,\/,\\\/,g')"
  sed -i -E "s,(^local-port=)(.*),\1${PDNS_LOCAL_PORT},g" ${PDNS_CONFIG_FILE};

fi

if [[ ! -z "$PDNS_ALLOW_AXFR_IPS" ]] ; then

  grep -q "^allow-axfr-ips=" ${PDNS_CONFIG_FILE} || echo "allow-axfr-ips=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
  PDNS_ALLOW_AXFR_IPS="$(echo $PDNS_ALLOW_AXFR_IPS | sed 's/\./\\\./g')"
  PDNS_ALLOW_AXFR_IPS="$(echo $PDNS_ALLOW_AXFR_IPS | sed 's/\,/\\\,/g')"
  PDNS_ALLOW_AXFR_IPS="$(echo $PDNS_ALLOW_AXFR_IPS | sed 's,\/,\\\/,g')"
  sed -i -E "s,(^allow-axfr-ips=)(.*),\1${PDNS_ALLOW_AXFR_IPS},g" ${PDNS_CONFIG_FILE};

fi

if [[ ! -z "$PDNS_ALLOW_DNSUPDATE_FROM" ]] ; then

  grep -q "^allow-dnsupdate-from=" ${PDNS_CONFIG_FILE} || echo "allow-dnsupdate-from=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
  PDNS_ALLOW_DNSUPDATE_FROM="$(echo $PDNS_ALLOW_DNSUPDATE_FROM | sed 's/\./\\\./g')"
  PDNS_ALLOW_DNSUPDATE_FROM="$(echo $PDNS_ALLOW_DNSUPDATE_FROM | sed 's/\,/\\\,/g')"
  PDNS_ALLOW_DNSUPDATE_FROM="$(echo $PDNS_ALLOW_DNSUPDATE_FROM | sed 's,\/,\\\/,g')"
  sed -i -E "s,(^allow-dnsupdate-from=)(.*),\1${PDNS_ALLOW_DNSUPDATE_FROM},g" ${PDNS_CONFIG_FILE};

fi

if [[ ! -z "$PDNS_ALLOW_NOTIFY_FROM" ]] ; then

  grep -q "^allow-notify-from=" ${PDNS_CONFIG_FILE} || echo "allow-notify-from=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
  PDNS_ALLOW_NOTIFY_FROM="$(echo $PDNS_ALLOW_NOTIFY_FROM | sed 's/\./\\\./g')"
  PDNS_ALLOW_NOTIFY_FROM="$(echo $PDNS_ALLOW_NOTIFY_FROM | sed 's/\,/\\\,/g')"
  PDNS_ALLOW_NOTIFY_FROM="$(echo $PDNS_ALLOW_NOTIFY_FROM | sed 's,\/,\\\/,g')"
  sed -i -E "s,(^allow-notify-from=)(.*),\1${PDNS_ALLOW_NOTIFY_FROM},g" ${PDNS_CONFIG_FILE};

fi

if [[ ! -z "$PDNS_TRUSTED_NOTIFICATION_PROXY" ]] ; then

  grep -q "^trusted-notification-proxy=" ${PDNS_CONFIG_FILE} || echo "trusted-notification-proxy=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
  PDNS_TRUSTED_NOTIFICATION_PROXY="$(echo $PDNS_TRUSTED_NOTIFICATION_PROXY | sed 's/\./\\\./g')"
  PDNS_TRUSTED_NOTIFICATION_PROXY="$(echo $PDNS_TRUSTED_NOTIFICATION_PROXY | sed 's/\,/\\\,/g')"
  PDNS_TRUSTED_NOTIFICATION_PROXY="$(echo $PDNS_TRUSTED_NOTIFICATION_PROXY | sed 's,\/,\\\/,g')"
  sed -i -E "s,(^trusted-notification-proxy=)(.*),\1${PDNS_TRUSTED_NOTIFICATION_PROXY},g" ${PDNS_CONFIG_FILE};

fi


if [[ ! -z "$PDNS_MASTER" ]] ; then

  grep -q "^master=" ${PDNS_CONFIG_FILE} || echo "master=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
  sed -i -E "s,(^master=)(.*),\1${PDNS_MASTER},g" ${PDNS_CONFIG_FILE};

fi

if [[ ! -z "$PDNS_SLAVE" ]] ; then

  grep -q "^slave=" ${PDNS_CONFIG_FILE} || echo "slave=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
  sed -i -E "s,(^slave=)(.*),\1${PDNS_SLAVE},g" ${PDNS_CONFIG_FILE};

fi

if [[ ! -z "$PDNS_ALLOW_UNSIGNED_NOTIFY" ]] ; then

  grep -q "^allow-unsigned-notify=" ${PDNS_CONFIG_FILE} || echo "allow-unsigned-notify=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
  sed -i -E "s,(^allow-unsigned-notify=)(.*),\1${PDNS_ALLOW_UNSIGNED_NOTIFY},g" ${PDNS_CONFIG_FILE};

fi

if [[ ! -z "$PDNS_DNSUPDATE" ]] ; then

  grep -q "^dnsupdate=" ${PDNS_CONFIG_FILE} || echo "dnsupdate=" | tee --append ${PDNS_CONFIG_FILE} > /dev/null;
  sed -i -E "s,(^dnsupdate=)(.*),\1${PDNS_DNSUPDATE},g" ${PDNS_CONFIG_FILE};

fi


appCheck () {
  echo "Check PowerDNS database..."
  case ${PDNS_BACKEND} in
    mysql)
      echo "MySQL backend, starting PowerDNS server...";
      /app/wait-for-it.sh -t 30 ${MYSQL_HOST}:${MYSQL_PORT} 
      if [ $? -ne 0 ]; then
        echo "Error by connecting MySQL database, could not initialize check."
        return 1 # error
      else
        echo "Check database..."
        # The query command is taken from https://github.com/psi-4ward/docker-powerdns/blob/master/entrypoint.sh
        if [ "$(echo "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = \"$MYSQL_NAME\";" | $MYSQL_CLI)" -ne 0 ]; then
          echo "Check successful, database exists..."
          return 0
        else
          appInit
          return $?
        fi
      fi
      ;;
    sqlite3)
      echo "Check database...";

      if [ ! -f "$SQLITE3_PATH" ]; then
        echo "Database file does not exist, creating..."
        touch ${SQLITE3_PATH}
      fi
      echo "Check tables in database..."
      if [ "$(echo ".tables" | sqlite3 ${SQLITE3_PATH} | wc -w)" -ne 0 ]; then
          echo "Check successful, database exists..."
          return 0
        else
          appInit
          return $?
        fi
      return 0
    
      ;;   
    *)
      echo "No backend or backend not supported, omit check...";
      return 0
      ;;
  esac

}


appStart () {
    
  # start Powerdns
  echo "Starting PowerDNS Server..."
  appCheck
  if [ $? -ne 0 ] 
  then
    echo "Error by checking, exit..."
    return 0
  else

    case ${PDNS_BACKEND} in
      mysql)
        
        echo "MySQL backend, starting PowerDNS server...";
        /app/wait-for-it.sh -t 30 ${MYSQL_HOST}:${MYSQL_PORT} 
        if [ $? -ne 0 ]; then
          echo "Error by connecting MySQL database, could not start PowerDNS."
          return 1
        else
          echo "start PowerDNS..."

          exec /usr/sbin/pdns_server --daemon=no --guardian=no --loglevel=9
          return 0
        fi
      
        ;;
      sqlite3)
        echo "SQLite3 backend, starting PowerDNS server...";
        exec /usr/sbin/pdns_server --daemon=no --guardian=no --loglevel=9
      
        ;;   
      *)
        echo "No backend or backend not supported, starting...";
        exec /usr/sbin/pdns_server --daemon=no --guardian=no --loglevel=9
        ;;
    esac
  fi
}


appInit () {
  echo "Initializing PowerDNS, create tables..."

  case ${PDNS_BACKEND} in
    mysql)
      echo "MySQL backend, initializing...";
      /app/wait-for-it.sh -t 30 ${MYSQL_HOST}:${MYSQL_PORT} 
      if [ $? -ne 0 ]; then
        echo "Error by connecting MySQL database, could not initialize."
        return 1
      else
      
        echo "CREATE DATABASE IF NOT EXISTS ${MYSQL_NAME};" | ${MYSQL_CLI}
        ${MYSQL_CLI} ${MYSQL_NAME} < /usr/share/pdns-backend-mysql/schema/schema.mysql.sql
        return $?
      fi
    
      ;;
    sqlite3)
      echo "SQLite3 backend, initializing...";
      cat /usr/share/pdns-backend-sqlite3/schema/schema.sqlite3.sql | /usr/bin/sqlite3 ${SQLITE3_PATH}
      return $?
      
      ;;   
    *)
      echo "No backend or backend not supported, doing nothing...";
      return 0
      ;;
  esac
  
}


appHelp () {
  echo "Available options:"
  echo " app:start          - Starts Powerdns Server (default)"
  echo " app:init           - Initialize Database"
  echo " [command]          - Execute the specified linux command eg. bash."
}


case ${1} in
  app:start)
    appStart
    ;;
  app:init)
    appInit	
    ;;
  app:help)
    appHelp
    ;;   
  *)
    if [[ -x $1 ]]; then
      $1
    else
      prog=$(which $1)
      if [[ -n ${prog} ]] ; then
        shift 1
        $prog $@
      else
        appHelp
      fi
    fi
    ;;
esac

exit 0