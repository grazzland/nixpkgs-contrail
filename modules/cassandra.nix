{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.cassandra;

  cassandraPkg = pkgs.cassandra_3_0.overrideAttrs (oldAttrs: {
    name = "cassandra-2.1.20";
    src = pkgs.fetchurl {
      sha1="9efe609848fadefd6adbf5de89b888ad57e2af17";
      url = "mirror://apache/cassandra/2.1.20/apache-cassandra-2.1.20-bin.tar.gz";
    };
  });

  cassandraConfigDir = pkgs.runCommand "cassandraConfDir" {} ''
    mkdir -p $out
    cat ${cassandraPkg}/conf/cassandra.yaml > $out/cassandra.yaml
    sed -i 's/^rpc_address.*/rpc_address: ${cfg.rpcAddress}/' $out/cassandra.yaml
    sed -i 's/^# broadcast_rpc_address.*/broadcast_rpc_address: ${cfg.broadcastRpcAddress}/' $out/cassandra.yaml
    cat >> $out/cassandra.yaml << EOF
    data_file_directories:
        - /tmp
    commitlog_directory:
        - /tmp
    saved_caches_directory:
        - /tmp
    #hints_directory:
    #    - /tmp/cassandra-data/hints
    start_rpc: true
    batch_size_warn_threshold_in_kb: 500
    #batch_size_fail_threshold_in_kb: 2000
    EOF

    cat >> $out/logback.xml << EOF
    <configuration scan="true">
      <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>/var/log/cassandra/system.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.FixedWindowRollingPolicy">
          <fileNamePattern>/var/log/cassandra/system.log.%i.zip</fileNamePattern>
          <minIndex>1</minIndex>
          <maxIndex>20</maxIndex>
        </rollingPolicy>

        <triggeringPolicy class="ch.qos.logback.core.rolling.SizeBasedTriggeringPolicy">
          <maxFileSize>20MB</maxFileSize>
        </triggeringPolicy>
        <encoder>
          <pattern>%-5level [%thread] %date{ISO8601} %F:%L - %msg%n</pattern>
          <!-- old-style log format
          <pattern>%5level [%thread] %date{ISO8601} %F (line %L) %msg%n</pattern>
          -->
        </encoder>
      </appender>

      <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
          <pattern>%-5level %date{HH:mm:ss,SSS} %msg%n</pattern>
        </encoder>
      </appender>

      <root level="WARN">
        <appender-ref ref="FILE" />
        <appender-ref ref="STDOUT" />
      </root>

      <logger name="com.thinkaurelius.thrift" level="ERROR"/>
    </configuration>
    EOF
  '';

in {
  options = {
    cassandra = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      rpcAddress = mkOption {
        description = "rpc listener address";
        default = "0.0.0.0";
        type = types.str;
      };
      broadcastRpcAddress = mkOption {
        description = "broadcast rpc address";
        default = "127.0.0.1";
        type = types.str;
      };
      postStart = mkOption {
        type = types.lines;
        default = "";
      };
    };
  };
  config = mkIf cfg.enable {

    # to have cqlsh easily accessible in the VM
    environment.systemPackages = with pkgs; [
      cassandraPkg
    ];

    boot.kernel.sysctl = {
      "vm.max_map_count" = "1048575";
      "fs.file-max" = "100000";
    };

    systemd.services.cassandra = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ cassandraPkg ];
      serviceConfig = {
        TimeoutSec = "infinity";
        LimitNOFILE = 100000;
      };
      environment = {
        CASSANDRA_CONFIG = cassandraConfigDir;
      };
      script = ''
        mkdir -p /tmp/cassandra-data/
        chmod a+w /tmp/cassandra-data
        export CASSANDRA_CONF=${cassandraConfigDir}
        export JVM_OPTS="$JVM_OPTS -Dcassandra.jmx.remote.port=7199"
        export JVM_OPTS="$JVM_OPTS -Dcassandra.jmx.remote.ssl=false"
        export JVM_OPTS="$JVM_OPTS -Dcassandra.jmx.remote.authenticate=false"
        ${cassandraPkg}/bin/cassandra -f -R
      '';
      postStart = ''
        sleep 2
        while ! ${cassandraPkg}/bin/nodetool status >/dev/null 2>&1; do
          sleep 2
        done

        ${cfg.postStart}
      '';
    };

  };
}
