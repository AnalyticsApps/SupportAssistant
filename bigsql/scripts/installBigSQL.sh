#!/bin/sh


function checkPrereqServiceInstalledOrStarted(){

     printf "\n Checking Service Installed or Started \n"

     services=$(curl --silent -u admin:passw0rd -X GET http://localhost:8080/api/v1/clusters/BigSQLCluster/services  | grep  service_name | sed -e 's,.*:.*"\(.*\)".*,\1,g')

     for serv in $services
     do 
        while :
        do
                if curl -u admin:passw0rd -H "X-Requested-By: ambari" -i -X GET http://localhost:8080/api/v1/clusters/BigSQLCluster/services/$serv 2>&1 | grep "INSTALLED\|STARTED" > /dev/null  2>&1
                then
                        break
                fi
                printf "\n Sleeping 30s \n"
                sleep 30s
        done
     done
}

function recheckPrereqServiceStarted(){

     printf "\n Rechecking all Service Started \n"

     services=$(curl --silent -u admin:passw0rd -X GET http://localhost:8080/api/v1/clusters/BigSQLCluster/services  | grep  service_name | sed -e 's,.*:.*"\(.*\)".*,\1,g')

     for serv in $services
     do 

        if curl -u admin:passw0rd -H "X-Requested-By: ambari" -i -X GET http://localhost:8080/api/v1/clusters/BigSQLCluster/services/$serv 2>&1 | grep "STARTED" > /dev/null  2>&1
        then
            break
        fi

        printf "\n Starting the service - $serv \n"
        curl -u admin:passw0rd -H "X-Requested-By: ambari" -i -X PUT -d '{"ServiceInfo": {"state" : "STARTED"}}'  http://localhost:8080/api/v1/clusters/BigSQLCluster/services/$serv
        sleep 15s

        while :
        do
                if curl -u admin:passw0rd -H "X-Requested-By: ambari" -i -X GET http://localhost:8080/api/v1/clusters/BigSQLCluster/services/$serv 2>&1 | grep "STARTED" > /dev/null  2>&1
                then
                        break
                fi
                printf "\n Sleeping $serv 10s \n"
                sleep 10s
        done

     done

}

function setupPrereqService(){

     printf "\n Installing Prereq Services. \n"

     cd /opt/SupportAssistant/bigsql

     # Register the Blueprint
     curl -H 'X-Requested-By:ambari' -X POST -u admin:passw0rd http://localhost:8080/api/v1/blueprints/BigSQLBlueprint -d @Blueprints.json

     # Deploy the blueprint
     curl -H 'X-Requested-By:ambari' -X POST -u admin:passw0rd http://localhost:8080/api/v1/clusters/BigSQLCluster -d @Hostmapping.json

     sleep 490s

     checkPrereqServiceInstalledOrStarted

     recheckPrereqServiceStarted

     printf "\n Prereq Service Installed and Started. \n"

}

function checkBigSQLInstalled(){
     while :
     do
         if curl -u admin:passw0rd -H "X-Requested-By: ambari" -i -X GET http://localhost:8080/api/v1/clusters/BigSQLCluster/services/BIGSQL 2>&1 | grep "INSTALLED" > /dev/null  2>&1
         then
              break
         fi
         printf "\n Sleeping 120s \n"
         sleep 120s
     done
}

function setupBigSQLService(){

     printf "\n Setting up BigSQL Service. \n"

     curl -i -u admin:passw0rd -H "X-Requested-By: ambari" -X POST -d '{"ServiceInfo":{"service_name":"BIGSQL"}}' http://localhost:8080/api/v1/clusters/BigSQLCluster/services
     sleep 1s

     curl -i -u admin:passw0rd -H "X-Requested-By: ambari" -X POST http://localhost:8080/api/v1/clusters/BigSQLCluster/services/BIGSQL/components/BIGSQL_HEAD
     sleep 1s

     curl -i -u admin:passw0rd -H "X-Requested-By: ambari" -X POST http://localhost:8080/api/v1/clusters/BigSQLCluster/services/BIGSQL/components/BIGSQL_WORKER
     sleep 1s

     printf "\n Adding Configuration. \n"

     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X POST -d '
     {
        "type":"bigsql-conf",
	"tag":"version1", 
        "properties_attributes" : { },
        "properties" : {
          "biginsights.stats.auto.analyze.post.load" : "ONCE",
          "biginsights.stats.auto.analyze.task.retention.time" : "1MONTH",
          "scheduler.autocache.poolsize" : "0",
          "scheduler.cache.exclusion.regexps" : "None",
          "bigsql.load.jdbc.jars" : "/tmp/jdbcdrivers",
          "scheduler.parquet.rgSplit.minFileSize" : "2147483648",
          "fs.sftp.impl" : "org.apache.hadoop.fs.sftp.SFTPFileSystem",
          "scheduler.client.request.timeout" : "120000",
          "scheduler.service.timeout" : "3600000",
          "scheduler.parquet.rgSplits" : "true",
          "scheduler.cache.splits" : "true",
          "biginsights.stats.auto.analyze.newdata.min" : "50",
          "biginsights.stats.auto.analyze.concurrent.max" : "1",
          "scheduler.tableMetaDataCache.timeToLive" : "1200000",
          "scheduler.minWorkerThreads" : "8",
          "javaio.textfile.extensions" : ".snappy,.bz2,.deflate,.lzo,.lz4,.cmx",
          "scheduler.maxWorkerThreads" : "1024",
          "scheduler.autocache.ddlstate.file" : "/var/ibm/bigsql/logs/.AutoCacheDDLStateDoNotDelete",
          "biginsights.stats.auto.analyze.post.syncobj" : "DEFERRED",
          "scheduler.autocache.poolname" : "autocachepool",
          "scheduler.client.request.IUDEnd.timeout" : "600000",
          "scheduler.java.opts" : "-Xms512M -Xmx2G",
          "scheduler.tableMetaDataCache.numTables" : "1000"
        }
     }
     ' http://localhost:8080/api/v1/clusters/BigSQLCluster/configurations
     sleep 1s


     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X POST -d '
     { 
        "type":"bigsql-slider-flex", 
        "tag":"version1", 
        "properties":{ 
          "bigsql_capacity" : "50" 
        }
     }
     ' http://localhost:8080/api/v1/clusters/BigSQLCluster/configurations
     sleep 1s


     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X POST -d '
     { 
        "type":"bigsql-head-env", 
        "tag":"version1", 
        "properties_attributes":{ 
          "final" : {
            "fs.defaultFS" : "true"
          }
        }, 
        "properties":{ 
          "bigsql_active_primary" : "head_node" 
        } 
     }
     ' http://localhost:8080/api/v1/clusters/BigSQLCluster/configurations
     sleep 1s


     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X POST -d '
     {
        "type":"bigsql-env",
	"tag":"version1", 
        "properties_attributes" : { },
        "properties" : {
          "bigsql_hdfs_poolsize" : "0",
          "db2_fcm_port_number" : "28051",
          "apply_best_practice_configuration_changes" : "true",
          "bigsql_java_heap_size" : "2048",
          "enable_impersonation" : "false",
          "bigsql_ha_port" : "20008",
          "enable_auto_metadata_sync" : "true",
          "enable_metrics" : "true",
          "bigsql_hdfs_poolname" : "autocachepool",
          "db2_port_number" : "32051",
          "scheduler_service_port" : "7053",
          "bigsql_mln_inc_dec_count" : "1",
          "public_table_access" : "false",
          "bigsql_initial_install_mln_count" : "1",
          "scheduler_admin_port" : "7054",
          "bigsql_log_dir" : "/var/ibm/bigsql/logs",
          "bigsql_db_path" : "/var/ibm/bigsql/database",
          "enable_yarn" : "false",
          "bigsql_resource_percent" : "25",
          "enable_auto_log_prune" : "true",
          "bigsql_continue_on_failure" : "false",
          "dfs.datanode.data.dir" : "/hadoop/bigsql"
        }
     }
     ' http://localhost:8080/api/v1/clusters/BigSQLCluster/configurations
     sleep 1s


     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X POST -d '
     {
        "type":"bigsql-users-env",
        "tag":"version1", 
        "properties_attributes" : { 
		    "ambari_user_password" : {
              "toMask" : "false"
            },
            "bigsql_user_password" : {
              "toMask" : "false"
            }

		},
        "properties" : {
          "ambari_user_login" : "admin",
          "ambari_user_password" : "passw0rd",
          "bigsql_user_id" : "2824",
          "enable_ldap" : "false",
          "bigsql_user" : "bigsql",
          "bigsql_user_password" : "passw0rd",
          "bigsql_admin_group_name" : "bigsqladm",
          "bigsql_admin_group_id" : "43210",
          "bigsql_setup_ssh" : "false"
        }
     }
     ' http://localhost:8080/api/v1/clusters/BigSQLCluster/configurations
     sleep 1s


     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X POST -d '
     {
        "type":"bigsql-log4j",
	"tag":"version1", 		
        "properties_attributes" : { },
        "properties" : {
          "bigsql_log_number_of_backup_files" : "15",
          "bigsql_scheduler_log4j_content" : "\n# Logging is expensive, so by default we only log if the level is >= WARN.\n# If you want any other logging to be done, you need to set the below 'GlobalLog' logger to DEBUG,\n# plus any other logger settings of interest below.\nlog4j.logger.com.ibm.biginsights.bigsql.scheduler.GlobalLog=WARN\n\n# Define the loggers\nlog4j.rootLogger=WARN,verbose\nlog4j.logger.com.ibm.biginsights.bigsql.scheduler.server.RecurringDiag=INFO,recurringDiagInfo\nlog4j.additivity.com.ibm.biginsights.bigsql.scheduler.server.RecurringDiag=false\n\n# Suppress unwanted messages\n#log4j.logger.javax.jdo=FATAL\n#log4j.logger.DataNucleus=FATAL\n#log4j.logger.org.apache.hadoop.hive.metastore.RetryingHMSHandler=FATAL\n\n# Verbose messages for debugging purpose\n#log4j.logger.com.ibm=ALL\n#log4j.logger.com.thirdparty.cimp=ALL\n#log4j.logger.com.ibm.biginsights.bigsql.io=WARN\n#log4j.logger.com.ibm.biginsights.bigsql.hbasecommon=WARN\n#log4j.logger.com.ibm.biginsights.catalog.hbase=WARN\n\n# Uncomment this to print table-scan assignments (node-number to number-of-blocks)\n#log4j.logger.com.ibm.biginsights.bigsql.scheduler.Assignment=DEBUG\n\n# setup the verbose logger\nlog4j.appender.verbose=org.apache.log4j.RollingFileAppender\nlog4j.appender.verbose.file={{bigsql_log_dir}}/bigsql-sched.log\nlog4j.appender.verbose.layout=org.apache.log4j.PatternLayout\nlog4j.appender.verbose.layout.ConversionPattern=%d{ISO8601} %p %c [%t] : %m%n\nlog4j.appender.verbose.MaxFileSize={{bigsql_log_max_backup_size}}MB\nlog4j.appender.verbose.MaxBackupIndex={{bigsql_log_number_of_backup_files}}\n\n# setup the recurringDiagInfo logger\nlog4j.appender.recurringDiagInfo=org.apache.log4j.RollingFileAppender\nlog4j.appender.recurringDiagInfo.file={{bigsql_log_dir}}/bigsql-sched-recurring-diag-info.log\nlog4j.appender.recurringDiagInfo.layout=org.apache.log4j.PatternLayout\nlog4j.appender.recurringDiagInfo.layout.ConversionPattern=%d{ISO8601} %p %c [%t] : %m%n\nlog4j.appender.recurringDiagInfo.MaxFileSize=10MB\nlog4j.appender.recurringDiagInfo.MaxBackupIndex=1\n\n# Setting this to DEBUG will cause ALL queries to be traced, INFO will cause\n# only sessions that specifically request it to be traced\nlog4j.logger.bigsql.query.trace=INFO\n\n# Silence hadoop complaining about forcing hive properties\nlog4j.logger.org.apache.hadoop.conf.Configuration=ERROR\n# Silence warnings about non existing hive properties\nlog4j.logger.org.apache.hadoop.hive.conf.HiveConf=ERROR\n\n# Uncomment and restart bigsql to get the details. Use INFO for less detail, DEBUG for more detail, TRACE for even more\n#log4j.logger.com.ibm.biginsights.bigsql.scheduler.Dev.Assignment=DEBUG,AssignStatInfo\n#log4j.appender.AssignStatInfo=org.apache.log4j.RollingFileAppender\n#log4j.appender.AssignStatInfo.file={{bigsql_log_dir}}/dev_pestats.log\n#log4j.appender.AssignStatInfo.layout=org.apache.log4j.PatternLayout\n#log4j.appender.AssignStatInfo.layout.ConversionPattern=%d{ISO8601} %p %c [%t] : %m%n\n#log4j.appender.AssignStatInfo.MaxFileSize=10MB\n#log4j.appender.AssignStatInfo.MaxBackupIndex=1\n\n# Uncomment and restart bigsql to get the details. Use INFO for less detail, DEBUG for more detail, TRACE for even more\n#log4j.logger.com.ibm.biginsights.bigsql.scheduler.Dev.PEStats=DEBUG,PEStatInfo\n#log4j.appender.PEStatInfo=org.apache.log4j.RollingFileAppender\n#log4j.appender.PEStatInfo.file={{bigsql_log_dir}}/dev_pestats.log\n#log4j.appender.PEStatInfo.layout=org.apache.log4j.PatternLayout\n#log4j.appender.PEStatInfo.layout.ConversionPattern=%d{ISO8601} %p %c [%t] : %m%n\n#log4j.appender.PEStatInfo.MaxFileSize=10MB\n#log4j.appender.PEStatInfo.MaxBackupIndex=1",
          "bigsql_log4j_content" : "\n# This file control logging for all Big SQL Java I/O and support processes\n# housed within FMP processes\nlog4j.rootLogger=WARN,verbose\n\nlog4j.appender.verbose=com.ibm.biginsights.bigsql.log.SharedRollingFileAppender\nlog4j.appender.verbose.file={{bigsql_log_dir}}/bigsql.log\nlog4j.appender.verbose.jniDirectory=/usr/ibmpacks/current/bigsql/bigsql/lib/native\nlog4j.appender.verbose.pollingInterval=30000\nlog4j.appender.verbose.layout=com.ibm.biginsights.bigsql.log.SharedServiceLayout\nlog4j.appender.verbose.layout.ConversionPattern=%d{ISO8601} %p %c [%t] : %m%n\nlog4j.appender.verbose.MaxFileSize={{bigsql_log_max_backup_size}}MB\nlog4j.appender.verbose.MaxBackupIndex={{bigsql_log_number_of_backup_files}}\n\n# Setting this to DEBUG will cause ALL queries to be traced, INFO will cause\n# only sessions that specifically request it to be traced\nlog4j.logger.bigsql.query.trace=INFO\n\n# Silence warnings about trying to override final parameters\nlog4j.logger.org.apache.hadoop.conf.Configuration=ERROR\n# Silence warnings about non existing hive properties\nlog4j.logger.org.apache.hadoop.hive.conf.HiveConf=ERROR\n\n# log4j.logger.com.ibm.biginsights.catalog=DEBUG\n# log4j.logger.com.ibm.biginsights.biga=DEBUG",
          "bigsql_log_max_backup_size" : "32"
        }
     }
     ' http://localhost:8080/api/v1/clusters/BigSQLCluster/configurations
     sleep 1s


     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X POST -d '
     {
        "type":"bigsql-logsearch-conf",
	"tag":"version1", 
        "properties_attributes" : { },
        "properties" : {
          "component_mappings" : "BIGSQL_HEAD:bigsql_server,bigsql_scheduler;BIGSQL_WORKER:bigsql_server",
          "content" : "\n{\n  \"input\":[\n    {\n     \"type\":\"bigsql_server\",\n     \"rowtype\":\"service\",\n     \"path\":\"{{default('/configurations/bigsql-env/bigsql_log_dir', '/var/ibm/bigsql/logs')}}/bigsql.log\"\n    },\n    {\n     \"type\":\"bigsql_scheduler\",\n     \"rowtype\":\"service\",\n     \"path\":\"{{default('/configurations/bigsql-env/bigsql_log_dir', '/var/ibm/bigsql/logs')}}/bigsql-sched.log\"\n    }\n  ],\n  \"filter\":[\n   {\n      \"filter\":\"grok\",\n      \"conditions\":{\n        \"fields\":{\n            \"type\":[\n                \"bigsql_server\",\n                \"bigsql_scheduler\"\n              ]\n            }\n      },\n      \"log4j_format\":\"%d{ISO8601} %p %c [%t] : %m%n\",\n      \"multiline_pattern\":\"^(%{TIMESTAMP_ISO8601:logtime})\",\n      \"message_pattern\":\"(?m)^%{TIMESTAMP_ISO8601:logtime}%{SPACE}%{LOGLEVEL:level}%{SPACE}%{JAVACLASS:logger_name}%{SPACE}\\\\[%{DATA:thread_name}\\\\]%{SPACE}:%{SPACE}%{GREEDYDATA:log_message}\",\n      \"post_map_values\":{\n        \"logtime\":{\n         \"map_date\":{\n          \"target_date_pattern\":\"yyyy-MM-dd HH:mm:ss,SSS\"\n         }\n       }\n     }\n    }\n   ]\n}",
          "service_name" : "IBM Big SQL"
        }
     }
     ' http://localhost:8080/api/v1/clusters/BigSQLCluster/configurations
     sleep 1s


     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X POST -d '
     {
        "type":"bigsql-slider-env",
	"tag":"version1", 	  
        "properties_attributes" : { },
        "properties" : {
          "use_yarn_node_labels" : "false",
          "bigsql_yarn_label" : "bigsql",
          "bigsql_yarn_queue" : "default",
          "enforce_single_container" : "false",
          "bigsql_container_mem" : "28672",
          "bigsql_container_vcore" : "0"
        }
     }
     ' http://localhost:8080/api/v1/clusters/BigSQLCluster/configurations
     sleep 1s

     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X PUT -d '{"Clusters": {"desired_configs": { "type": "bigsql-conf", "tag" :"version1" }}}' http://localhost:8080/api/v1/clusters/BigSQLCluster
     sleep 1s

     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X PUT -d '{"Clusters": {"desired_configs": { "type": "bigsql-slider-flex", "tag" :"version1" }}}' http://localhost:8080/api/v1/clusters/BigSQLCluster
     sleep 1s

     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X PUT -d '{"Clusters": {"desired_configs": { "type": "bigsql-head-env", "tag" :"version1" }}}' http://localhost:8080/api/v1/clusters/BigSQLCluster
     sleep 1s

     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X PUT -d '{"Clusters": {"desired_configs": { "type": "bigsql-env", "tag" :"version1" }}}' http://localhost:8080/api/v1/clusters/BigSQLCluster
     sleep 1s

     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X PUT -d '{"Clusters": {"desired_configs": { "type": "bigsql-users-env", "tag" :"version1" }}}' http://localhost:8080/api/v1/clusters/BigSQLCluster
     sleep 1s

     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X PUT -d '{"Clusters": {"desired_configs": { "type": "bigsql-log4j", "tag" :"version1" }}}' http://localhost:8080/api/v1/clusters/BigSQLCluster
     sleep 1s

     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X PUT -d '{"Clusters": {"desired_configs": { "type": "bigsql-logsearch-conf", "tag" :"version1" }}}' http://localhost:8080/api/v1/clusters/BigSQLCluster
     sleep 1s

     curl -u admin:passw0rd -H "X-Requested-By: ambari" -X PUT -d '{"Clusters": {"desired_configs": { "type": "bigsql-slider-env", "tag" :"version1" }}}' http://localhost:8080/api/v1/clusters/BigSQLCluster
     sleep 1s

     curl -u admin:passw0rd -H "X-Requested-By: ambari" -i -X POST -d '{"host_components" : [{"HostRoles":{"component_name":"BIGSQL_HEAD"}}] }' http://localhost:8080/api/v1/clusters/BigSQLCluster/hosts?Hosts/host_name=head_node
     sleep 1s

     curl -u admin:passw0rd -H "X-Requested-By: ambari" -i -X POST -d '{"host_components" : [{"HostRoles":{"component_name":"BIGSQL_WORKER"}}] }' http://localhost:8080/api/v1/clusters/BigSQLCluster/hosts?Hosts/host_name=worker_node
     sleep 1s

     printf "\n Installing BigSQL Service. \n"
     curl -u admin:passw0rd -H "X-Requested-By: ambari" -i -X PUT -d '{"ServiceInfo": {"state" : "INSTALLED"}}'  http://localhost:8080/api/v1/clusters/BigSQLCluster/services/BIGSQL

     sleep 300s
     checkBigSQLInstalled


     curl -u admin:passw0rd -H "X-Requested-By: ambari" -i -X PUT -d '{"ServiceInfo": {"state" : "STARTED"}}'  http://localhost:8080/api/v1/clusters/BigSQLCluster/services/BIGSQL
     sleep 1s

     printf "\n Setting up BigSQL Service Completed. \n"

}

setupPrereqService
setupBigSQLService