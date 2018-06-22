#!/bin/sh

sdir="`dirname \"$0\"`"

function installpreReqRPMS(){
    printf "\n\n Installing prereq RPMs"
    echo "Installing prereq RPMs " >> $sdir/../../log/bigsql_setup.log                
    for i in `cat $sdir/../../conf/server $sdir/../../conf/agents`
    do
        node=${i}
        command="docker exec $node bash -c 'rpm -Uvh http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm'"
        eval $command >> $sdir/../../log/bigsql_setup.log

        command="docker exec $node bash  -c 'yum install -y which ksh sudo lsof'"
        eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

    done
    echo "Install prereq RPMs Completed" >> $sdir/../../log/bigsql_setup.log

}

function createBigSQLUser(){

       printf "\n\n Setting up BigSQL User and ssh across bigsql user "


       for i in `cat $sdir/../../conf/server $sdir/../../conf/agents`
       do
           node="${i}"
           printf "\n\n Setting up the node - $node " >> $sdir/../../log/bigsql_setup.log

           command="docker exec $node bash  -c 'rm -rf /opt/SupportAssistant/bigsql && mkdir /opt/SupportAssistant/bigsql'"
           eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

           command="docker cp $sdir/../../bigsql/scripts/createBigSQLUser.sh $node:/opt/SupportAssistant/bigsql"
           eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

           command="docker exec $node bash  -c 'chmod 777 /opt/SupportAssistant/bigsql/createBigSQLUser.sh'"
           eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

           command="docker exec $node bash  -c '/opt/SupportAssistant/bigsql/createBigSQLUser.sh'"
           eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

       done

       for i in `cat $sdir/../../conf/server $sdir/../../conf/agents`
       do
            node="${i}"

            for j in `cat $sdir/../../conf/server $sdir/../../conf/agents`
            do
               agent=${j}
               command="docker exec $node bash -c 'sshpass -p \"passw0rd\" ssh-copy-id -i /home/bigsql/.ssh/id_rsa.pub -o StrictHostKeyChecking=no bigsql@${agent}'"
               eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

               command="docker exec $node bash -c 'ssh-keyscan -t ecdsa ${agent} >> /home/bigsql/.ssh/known_hosts'"
               eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

               
            done

       done
       printf "\n Setting up the BigSQL user and ssh Completed \n" >> $sdir/../../log/bigsql_setup.log



}

function installBigSQLRPM(){
    server=`head -n 1 $sdir/../../conf/server`


    printf "\n\n Installing BigSQL RPM and Enabling BigSQL Extension \n\n"
    read -p " Enter BigSQL Repo URL : " buildURL

    rm -rf $sdir/../../tmp/IBM-Big_SQL-*.rpm

    # Download the RPM 
    wget --recursive --level=1 --no-parent --no-directories --accept 'IBM-Big_SQL-*.rpm' --directory-prefix=$sdir/../../tmp $buildURL >> $sdir/../../log/bigsql_setup.log 2>&1

    command="docker cp $sdir/../../tmp/IBM-Big_SQL-*.rpm $server:/opt/SupportAssistant/bigsql"
    eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

    command="docker exec $server bash  -c 'chmod 777 /opt/SupportAssistant/bigsql/IBM-Big_SQL-*.rpm'"
    eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

    command="docker exec $server bash  -c 'rpm -ivh /opt/SupportAssistant/bigsql/IBM-Big_SQL-*.rpm'"
    eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

    command="docker exec $server bash  -c '/var/lib/ambari-server/resources/extensions/IBM-Big_SQL/*/scripts/EnableBigSQLExtension.py -U admin -P passw0rd -NI'"
    eval $command >> $sdir/../../log/bigsql_setup.log 2>&1
    sleep 5s

    printf "\n\n BigSQL RPM and Enabling BigSQL Extension Completed \n" >> $sdir/../../log/bigsql_setup.log

}


function createHostMapping(){

    cp -f $sdir/../../bigsql/blueprint/Hostmapping.json $sdir/../../tmp

    server=`head -n 1 $sdir/../../conf/server`

    serverDetails="\t{\n\t\t\"name\" : \"host_group_1\",\n\t\t\"hosts\" : [\n\t\t\t{\n\t\t\t\t\"fqdn\" : \"$server\"\n\t\t\t}\n\t\t]\n\t}\n"
    comm="sed -i 's/ADD_NODE_1/$serverDetails/g'  $sdir/../../tmp/Hostmapping.json"
    eval $comm


    if [[ $(wc -l $sdir/../../conf/agents | awk '{print $1}') -le 1 ]]
    then
        worker=`head -n 1 $sdir/../../conf/agents`
        workerDetails="\t,{\n\t\t\"name\" : \"host_group_2\",\n\t\t\"hosts\" : [\n\t\t\t{\n\t\t\t\t\"fqdn\" : \"$worker\"\n\t\t\t}\n\t\t]\n\t}\n"
        comm="sed -i 's/ADD_NODE_2/$workerDetails/g'  $sdir/../../tmp/Hostmapping.json"
        eval $comm

        comm="sed -i '/ADD_NODE_3/d'  $sdir/../../tmp/Hostmapping.json"
        eval $comm

    else

        worker=`head -n 1 $sdir/../../conf/agents`
        workerDetails="\t,{\n\t\t\"name\" : \"host_group_2\",\n\t\t\"hosts\" : [\n\t\t\t{\n\t\t\t\t\"fqdn\" : \"$worker\"\n\t\t\t}\n\t\t]\n\t}\n"
        comm="sed -i 's/ADD_NODE_2/$workerDetails/g'  $sdir/../../tmp/Hostmapping.json"
        eval $comm


        agentDetailsHead="\t,{\n\t\t\"name\" : \"host_group_3\",\n\t\t\"hosts\" : [\n\t\t\t"

        agentDetails=""
        declare -i start=1
   
        for i in `tail -n +2 $sdir/../../conf/agents`
        do
              agent=${i}

              if (( $start == 1 )) ; then
                    agentDetails="$agentDetails{\n\t\t\t\t\"fqdn\" : \"$agent\"\n\t\t\t}"
              else
                    agentDetails="$agentDetails\n\t\t\t,{\n\t\t\t\t\"fqdn\" : \"$agent\"\n\t\t\t}"
 
              fi
              start+=1
             
        done

        agentDetailsFooter="\n\t\t]\n\t}\n"
    
        agentDetails="$agentDetailsHead$agentDetails$agentDetailsFooter"


        comm="sed -i 's/ADD_NODE_3/$agentDetails/g'  $sdir/../../tmp/Hostmapping.json"
        eval $comm

    fi

      cp -f $sdir/../../bigsql/scripts/installBigSQL.sh $sdir/../../tmp
      comm="sed -i 's/head_node/$server/g'  $sdir/../../tmp/installBigSQL.sh"
      eval $comm
      agent=`head -1 $sdir/../../conf/agents`
      comm="sed -i 's/worker_node/$agent/g'  $sdir/../../tmp/installBigSQL.sh"
      eval $comm




}


function setupBigSQL(){

    printf "\n Setting up BigSQL "

    server=`head -n 1 $sdir/../../conf/server`

    command="docker cp $sdir/../../bigsql/scripts/installBigSQL.sh $server:/opt/SupportAssistant/bigsql"
    eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

    command="docker cp $sdir/../../bigsql/blueprint/Blueprints.json $server:/opt/SupportAssistant/bigsql"
    eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

    createHostMapping

    command="docker cp $sdir/../../tmp/Hostmapping.json $server:/opt/SupportAssistant/bigsql"
    eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

    command="docker cp $sdir/../../tmp/installBigSQL.sh $server:/opt/SupportAssistant/bigsql"
    eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

    command="docker exec $server bash  -c 'chmod -R 777 /opt/SupportAssistant/bigsql'"
    eval $command >> $sdir/../../log/bigsql_setup.log 2>&1


    command="docker exec $server bash  -c '/opt/SupportAssistant/bigsql/installBigSQL.sh'"
    eval $command >> $sdir/../../log/bigsql_setup.log 2>&1

    printf "\n Setting up BigSQL Completed \n" >> $sdir/../../log/bigsql_setup.log

}


function process(){

    if [[ $(wc -l < $sdir/../../conf/agents) -eq 0 ]]; then
           printf "\n\n ERROR !!!! BigSQL installation requires minimum 2 nodes. Add  a hostname for agent node under conf/agents \n"
           printf " Removing the containers \n\n"
           ../kill_all.sh
           exit 1
    fi
    
    printf "\n ****************************************************************************************************************"
    printf "\n Setting up the BigSQL \n"
    printf " ****************************************************************************************************************"

    installpreReqRPMS
    createBigSQLUser
    installBigSQLRPM
    setupBigSQL
}

process




