{ pkgs, cfg }:

pkgs.writeTextFile {
  name = "contrail-collector.conf";
  text = ''
    [DEFAULT]
    log_level = ${cfg.logLevel}
    log_local = 0
    log_file = /var/log/contrail/collector.log
    use_syslog = 1

    cassandra_server_list = localhost:9042
    zookeeper_server_list = localhost:2181
    uve_proxy_list =
    kafka_broker_list =
    partitions = 0

    [CONFIGDB]
    rabbitmq_server_list = localhost:5672
    rabbitmq_user = guest
    rabbitmq_password = guest

    [API_SERVER]
    api_server_list = 127.0.0.1:8082
    api_server_use_ssl = false

    [REDIS]
    server = 127.0.0.1
    port = 6379
  '';
}
