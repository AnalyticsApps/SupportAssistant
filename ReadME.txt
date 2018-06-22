# SupportAssistant
SupportAssistant -  is used by Dev/Support Engineer to setup the BigSQL for replicating a scenario/customer issues and analyse the BigSQL Logs.

**All the containers are created in a single physical machine so should not use this project for performance/load testing or in Production**


## Internal Architecture

Creates docker container based on the host names mentioned in conf/server & conf/agents. Docker container will have the same name has the host names. The ambari server will be installed in the container that have the name mentioned conf/server and Ambari Agents will be installed on all the container mentioned in conf/agents. After installing, ambari server & agents, installs the ambari bluprints for the dependent components and uses amabri rest API to install BigSQL.

Head node will be installed in the amabri server container and worker node will be installed only in one ambari agent container.



## Usage

**1) bin/setupDocker.sh**  - Used to setup the Docker in a fresh Linux Machine.

![](img/setupDocker.png)
 
**2) bin/setupCluster.sh** - Used to setup the container/cluster based on the nodes mentioned in the configuration files. The Amabri server will be created based on the hostname mentioned in conf/server. The Ambari agent containers will be created based on conf/agent. This script will install only the BigSQL and its dependent components. 
 
 
![](img/setupCluster_1.png)
   
   
*bin/setupCluster.sh createBigSQL* - The engineer need to provide the URL for ambari.repo file and BigSQL repository to setup BigSQL.

The path for Ambari repo is available in Hortonworks URL (https://docs.hortonworks.com/HDPDocuments/Ambari-2.6.1.5/bk_ambari-installation/content/ambari_repositories.html )
  
  
![](img/setupCluster_Create_1.png)
![](img/setupCluster_Create_2.png)
  
To test the bigsql, User can login to ssh -p 21 root@localhost 
Credentials are root/password or bigsql/passw0rd
  
  
![](img/setupCluster_Create_3.png) 
  
Credentials for Ambari UI is admin/passw0rd
  
![](img/setupCluster_Create_4.png)
![](img/setupCluster_Create_5.png)
  
  
  
*bin/setupCluster.sh stop*
  
  
![](img/setupCluster_stop.png)
  
  
    
*bin/setupCluster.sh start*
  
  
![](img/setupCluster_start.png)
  
  
**3) bin/kill_all.sh** - Used to kill the containers created by SupportAssistant.
  
  
![](img/Kill_All.png)
 
     
**4) bin/setupCluster.sh createLogAnalyzer ** - Create the cluster for Log Analysis. If you 

#Get the nodes information from Log Collector Script
tar -C . -zxvf <provideTheTarGZFileGotFromCustomerLogCollectorScript> nodes.info

# Update the ambari-Server and ambari-agent nodes
head -n 1 nodes.info > conf/server
tail -n +2 nodes.info > conf/agents

After updating the configuration file conf/server & conf/agents, run the setupCluster.sh createLogAnalyzer to setup the Log Analyzer.
  
![](img/createLogAnalyzer_1.png)
![](img/createLogAnalyzer_2.png)
![](img/createLogAnalyzer_3.png)
  
  

**5) bin/logDistribute.sh** - Used for distributing the customer logs to existing log analyzer cluster. If the engineer uses the bin/setupCluster.sh createLogAnalyzer to setup the cluster, then to distribute the customer logs, support engineer has to run the log distribute script.
  
    
![](img/LogDistribute.png) 
![](img/LogDistribute_out_1.png) 
![](img/LogDistribute_out_2.png)
![](img/LogDistribute_out_3.png)
![](img/LogDistribute_out_4.png)
  
  
  
**6) bin/logDistribute.sh** - Used for distributing the customer logs to existing cluster. If the engineer uses the bin/setupCluster.sh createBigSQL or  bin/setupCluster.sh createLogAnalyzer to setup the cluster, then to distribute the customer logs, support engineer has to run the log distribute script.
  
    
![](img/LogDistribute.png) 

  
  
  
  
    
## Author

**Nisanth Simon** - [NisanthSimon@LinkedIn]

[NisanthSimon@LinkedIn]: https://au.linkedin.com/in/nisanth-simon-03b2149
 
