#!/bin/bash
apt update -y
apt install curl gnupg gnupg2 docker.io docker-compose -y
mkdir /opt/monitoring && cd /opt/monitoring

echo 'version: "2"
services:
  grafana:
    image: grafana/grafana
    container_name: grafana
    restart: always
    ports:
      - 3000:3000
    networks:
      - monitoring
    volumes:
      - grafana-volume:/var/lib/grafana
  influxdb:
    image: influxdb
    container_name: influxdb
    restart: always
    ports:
      - 8086:8086
    networks:
      - monitoring
    volumes:
      - influxdb-volume:/var/lib/influxdb
networks:
  monitoring:
volumes:
  grafana-volume:
    external: true
  influxdb-volume:
    external: true' > /opt/monitoring/docker-compose.yml

docker network create monitoring
docker volume create grafana-volume
docker volume create influxdb-volume

cd /opt/monitoring/ && server1$ docker run --rm -e INFLUXDB_DB=telegraf -e INFLUXDB_ADMIN_ENABLED=true -e INFLUXDB_ADMIN_USER=user -e INFLUXDB_ADMIN_PASSWORD=123456 -e INFLUXDB_USER=user -e INFLUXDB_USER_PASSWORD=123456 -v influxdb-volume:/var/lib/influxdb influxdb /init-influxdb.sh

docker-compose up -d

#### Create systemd units for autostart containers

echo '[Unit]
Description=influxdb container
Requires=docker.service                            
After=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker start -a influxdb
ExecStop=/usr/bin/docker stop -t 2 influxdb
TimeoutSec=30

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/influxdb.service

echo '[Unit]
Description=grafana container
Requires=docker.service                            
After=docker.service influxdb.service

[Service]
Restart=always
ExecStart=/usr/bin/docker start -a grafana
ExecStop=/usr/bin/docker stop -t 2 grafana
TimeoutSec=30

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/grafana.service

systemctl enable influxdb.service
systemctl enable influxdb.service
systemctl daemon-reload
