version: '3.1'
services:
  zabbix-postgresql:
    container_name: zabbix-postgresql
    image: postgres:latest
    restart: always
    environment:
      - POSTGRES_PASSWORD=zabbix
      - POSTGRES_USER=zabbix
      - POSTGRES_DB=zabbix
    networks:
      - monitoring
    volumes:
      - postgresql-volume:/var/lib/postgresql/data

  zabbix-server:
    container_name: zabbix-server
    image: zabbix/zabbix-server-pgsql:ubuntu-5.0.1
    restart: always
    environment:
      - ZBX_SERVER_HOST=zabbix-server
      - DB_SERVER_HOST=zabbix-postgresql
      - DB_SERVER_DBNAME=zabbix
      - POSTGRES_USER=zabbix
      - POSTGRES_PASSWORD=zabbix
      - POSTGRES_DB=zabbix
    depends_on:
      - zabbix-postgresql
    networks:
      monitoring:
        ipv4_address: 172.10.0.100
    volumes:
      - alertscripts:/usr/lib/zabbix/alertscripts
      - snmptraps:/var/lib/zabbix/snmptraps:rw
    ports:
      - '10051:10051'

  zabbix-web:
    container_name: zabbix-web
    image: zabbix/zabbix-web-apache-pgsql:ubuntu-5.0.1
    restart: always
    environment:
      - ZBX_SERVER_HOST=zabbix-server
      - DB_SERVER_HOST=zabbix-postgresql
      - DB_SERVER_DBNAME=zabbix
      - POSTGRES_USER=zabbix
      - POSTGRES_PASSWORD=zabbix
      - POSTGRES_DB=zabbix
      - PHP_TZ=Europe/Moscow
    networks:
      -  monitoring
    depends_on:
      - zabbix-postgresql
      - zabbix-server
    ports:
      - '81:8080'
      - '8443:443'

  zabbix-agent:
    container_name: zabbix-agent
    image: zabbix/zabbix-agent:latest
    privileged: true
    restart: always
    environment:
      - ZBX_SERVER_HOST=zabbix-server
    depends_on:
      - zabbix-server
    links:
      - zabbix-server
    ports:
      - '10055:10050'
    networks:
      - monitoring

  grafana:
    container_name: grafana
    image: grafana/grafana:latest-ubuntu
    restart: always
    ports:
     - 3000:3000
    environment:
      - GF_INSTALL_PLUGINS=alexanderzobnin-zabbix-app
      - GF_SECURITY_ADMIN_USER=user
      - GF_SECURITY_ADMIN_PASSWORD=123456
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
    environment:
      - INFLUXDB_DB=telegraf
      - INFLUXDB_ADMIN_USER=user
      - INFLUXDB_ADMIN_PASSWORD=123456

  pgadmin:
    image: dpage/pgadmin4
    container_name: pgadmin
    restart: unless-stopped
    environment:
      - PGADMIN_DEFAULT_EMAIL=user@itrium.ru
      - PGADMIN_DEFAULT_PASSWORD=123456
      - PGADMIN_LISTEN_PORT=80
    ports:
      - 8080:80
    depends_on:
      - zabbix-postgresql
    networks:
      - monitoring
    volumes:
      - pgadmin-data:/var/lib/pgadmin

  zabbix-snmptraps:
    image: zabbix/zabbix-snmptraps:ubuntu-5.0.1
    ports:
     - "162:1162/udp"
    volumes:
      - snmptraps:/var/lib/zabbix/snmptraps:rw
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
    ipam:
     config:
       - subnet: 172.10.0.0/16

volumes:
  postgresql-volume:
  alertscripts:
  grafana-volume:
  snmptraps:
  influxdb-volume:
  pgadmin-data:
