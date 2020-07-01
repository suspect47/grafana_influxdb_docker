# после установки скрипта веб-интерфейс графаны будет находиться по адресу: http://your_host_ip:3000
# учетные данные для входа в веб-интерфейс: admin/123456 
# названия нужных плагинов для предустановки из скрипта указываются в блоке "Get grafana plugins"
# в данном скрипте предустанавливается три плагина - clock panel, influx admin и kubernetes

#!/bin/bash

##### Installing dependencies

apt update
apt install -y curl gnupg gnupg2 docker.io docker-compose
mkdir /opt/monitoring && cd /opt/monitoring

##### Creating docker-compose file

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
    
##### Creating docker networking and docker-volumes

docker network create monitoring
docker volume create grafana-volume
docker volume create influxdb-volume

cd /opt/monitoring/ && docker run --rm -e INFLUXDB_DB=telegraf -e INFLUXDB_ADMIN_ENABLED=true -e INFLUXDB_ADMIN_USER=user -e INFLUXDB_ADMIN_PASSWORD=123456 -e INFLUXDB_USER=user -e INFLUXDB_USER_PASSWORD=123456 -v influxdb-volume:/var/lib/influxdb influxdb /init-influxdb.sh

docker-compose up -d

#### Create systemd unit for docker-compose

echo '[Unit]
Description=docker-compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/monitoring
ExecStart=/usr/local/bin/docker-compose -pabc up -d
ExecStop=/usr/local/bin/docker-compose -pabc down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/docker-compose.service

systemctl enable docker-compose.service

#### Installing telegraf

curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add -
source /etc/lsb-release
echo "deb https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/influxdb.list

apt-get update && apt-get install telegraf -y
service telegraf start

###### Get grafana plugins

docker exec grafana grafana-cli plugins install grafana-clock-panel
docker exec grafana grafana-cli plugins install natel-influx-admin-panel
docker exec grafana grafana-cli plugins install grafana-kubernetes-app

#### Indicate datasource parameters

echo 'apiVersion: 1

datasources:
  - name: Influxdb
    type: influxdb
    url: http://influxdb:8086
    database: telegraf
    user: user
    password: 123456' > /opt/monitoring/datasource.yml

docker cp /opt/monitoring/datasource.yml grafana:/etc/grafana/provisioning/datasources/datasource.yml
rm -f /opt/monitoring/datasource.yml

#### Setting admin password

docker exec grafana grafana-cli admin reset-admin-password 123456

#### Restarting grafana container

docker container restart grafana
