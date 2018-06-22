#!/bin/sh

packArtifacts(){

    ##################################################
    ##### Package the collected logs
    ##################################################

    currentNode=`hostname -f`

    for node in $nodes
        do
                if (ssh $node "test -d $pmrDIR/*/"); then
            ssh $node "cd $pmrDIR/*/;tar czf $pmrDIR/$node.tar.gz * ;"
            scp $node:$pmrDIR/$node.tar.gz $pmrDIR
            if [ "$node" != "$currentNode" ]; then
                ssh $node "rm -rf  $pmrDIR"
            fi
        else
            if [ "$node" != "$currentNode" ]; then
                ssh $node "rm -rf  $pmrDIR"
            fi
        fi

    done 

    rm -rf $pmrDIR/*/
    cd $pmrDIR

    count=`ls -1 $pmrDIR/*.tar.gz 2>/dev/null | wc -l`

    if [ $count != 0 ]; then
        echo " "
        echo "Packaging PMRStamping data..."
        echo " "

        tar czf "$pmrDIR".tar.gz *
        rm -rf $pmrDIR
        echo " "
        echo "!!!!!!!!!!!!! Execution completed.!!!!!!!!!!!!"
        echo "!!!!!!!!!!!!! Please check in $pmrDIR.tar.gz !!!!!!!!!!!!"
        echo " "


    else
        echo " "
        rm -rf $pmrDIR
        echo "!!!!!!!!!!!!! No Logs are modified after $previousDate from nodes: $inputNodes for the selected Service. !!!!!!!!!!!!"
        echo "!!!!!!!!!!!!! Execution completed. No Logs collected. !!!!!!!!!!!!"
        echo " "


    fi



}

writeLogs(){
    node=$1
    srcLogPath=$2
    targetLogPath=$3
    commandSEDArg="s|$srcLogPath||"
    if (ssh $node "test -d $srcLogPath"); then

    echo " "
    command=`ssh $node find $srcLogPath -type d | sed $commandSEDArg`
    directories=$(echo $command | tr " " "\n")
    command=`ssh $node find $srcLogPath -type f -newermt $previousDate`
    files=$(echo $command | tr " " "\n")
    for srcfile in ${files[@]}
    do
        targetfile=$targetLogPath`echo $srcfile | sed $commandSEDArg`
        ssh $node mkdir -p "$targetLogPath"
        ssh $node cp $srcfile $targetLogPath
    done
    else
        echo " "
    
    fi

}

collectLogs(){

    for node in $nodes
    do
        for lPath in $logPath
        do
            echo ""
            echo "Collecting Logs from path : $lPath from Node: $node and path $pmrDIR/$node$lPath"
            writeLogs $node $lPath $pmrDIR/$node$lPath
        done
    
    done 
}

echo " "
echo " "
read -p " PMR No# : " pmrNo
if [ "$pmrNo" == "" ]; then
    printf "\n  Enter a valid PMR NO#. \n"
    exit 1
fi

echo " "
echo " "
read -p  " Date (yyyy-mm-dd) issue happened : " issueDate
issueDate=$(date -d "$issueDate" +%F)
previousDate=$(date -d "$issueDate -1 days" +%F)

echo " "
echo " "
read -p  " Component : " component


echo " "
echo " "
echo " Description of the issue (\"ctrl+d\" when done) : " 
issueDesc=$(cat)


echo " "
echo " "
read -p "Location where the logs need to be collected (Default Path - \tmp) : " loc
if [ "$loc" == "" ]; then
    loc="/tmp"
fi

echo " "
echo " "
echo "Services running in your Cluster       "
echo " "
echo " "
echo "1)  HDFS"
echo "2)  Yarn"
echo "3)  MapReduce2"
echo "4)  Zookeeper"
echo "5)  Hive"
echo "6)  Hbase"
echo "7)  BigSQL"
echo " "
echo " "
read -p  "Enter the service no# for collecting the logs. If you have multiple service logs to be collected, provide the service no# delimited by comma : " serviceNos



services=$(echo $serviceNos | tr "," "\n")

logPath=";"
addedMapReduceLog="false"
for service in $services
do
    service="${service#"${service%%[![:space:]]*}"}"
    service="${service%"${service##*[![:space:]]}"}"
    if [ "$service" = "1" ]; then
        logPath="${logPath}/var/log/hadoop/hdfs;"
    elif [ "$service" = "2" ]; then
        logPath="${logPath}/var/log/hadoop-yarn/yarn;"
        if [ "$addedMapReduceLog" == "false" ]; then
            logPath="${logPath}/var/log/hadoop-mapreduce;"
            addedMapReduceLog="true"
        fi

    elif [ "$service" = "3" ]; then
        if [ "$addedMapReduceLog" == "false" ]; then
            logPath="${logPath}/var/log/hadoop-mapreduce;"
            addedMapReduceLog="true"
        fi
    elif [ "$service" = "4" ]; then
        logPath="${logPath}/var/log/zookeeper;"
    elif [ "$service" = "5" ]; then
        logPath="${logPath}/var/log/hive;/var/log/webhcat;"
    elif [ "$service" = "6" ]; then
        logPath="${logPath}/var/log/hbase;"
    elif [ "$service" = "7" ]; then
        ## TODO - Need to get the latest diag logs
        logPath="${logPath}/var/ibm/bigsql/logs;/var/ibm/bigsql/diag/DIAG0000;"
    else
    echo ""
    fi

done

echo " "
echo " "
read -p  "Enter the full host names of the nodes. If you need to collect the logs from multiple nodes, provide the hostname delimited by comma : " inputNodes
logPath=${logPath:1}
#logPath=${logPath::-1}

pmrDIR=$loc/$pmrNo

nodes=$(echo $inputNodes | tr "," "\n")
logPath=$(echo $logPath | tr ";" "\n")

for node in $nodes
    do
        ssh $node rm -rf $pmrDIR
        ssh $node mkdir -p $pmrDIR

    done 

pmrfile=$pmrDIR/pmrstamp.info
touch $pmrfile
echo "Time and date of this collection: `date`" >> $pmrfile
echo "PMR No#   : $pmrNo" >> $pmrfile
echo "Location  : $loc" >> $pmrfile
echo "Log Path  : $logPath" >> $pmrfile


pa=$pmrDIR/problemStatement.info
echo "PMR No#   : $pmrNo" >> $pa
echo "Date issue happened   : $issueDate" >> $pa
echo "Component   : $component" >> $pa
echo "Issue Description   : $issueDesc" >> $pa

machineDetails=$pmrDIR/nodes.info
echo "$nodes" >> $machineDetails


collectLogs

packArtifacts
echo -e
