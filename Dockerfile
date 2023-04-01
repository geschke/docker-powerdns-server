FROM ubuntu:focal-20230308

LABEL maintainer="Ralf Geschke <ralf@kuerbis.org>"

LABEL last_changed="2023-04-01"


# necessary to set default timezone Etc/UTC
ENV DEBIAN_FRONTEND noninteractive


# testing Ubuntu 20.04 focal, in case of errors, switch to 18.04 again
RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get -y dist-upgrade \
  && apt-get install -y ca-certificates \
  && apt-get install -y --no-install-recommends \
  && apt-get install -y locales \
  && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
  && apt-get install -y curl git gnupg pdns-server pdns-backend-sqlite3 pdns-backend-mysql mysql-client \
  && rm -rf /var/lib/apt/lists/* 


EXPOSE 8081 53/udp 53/tcp 


USER root
RUN mkdir -p /app
COPY entrypoint.sh /app/entrypoint.sh
COPY wait-for-it.sh /app/wait-for-it.sh
RUN chmod 755 /app/entrypoint.sh && chmod 755 /app/wait-for-it.sh
RUN chown -R pdns:pdns /app

#USER pdns 
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["app:start"]
