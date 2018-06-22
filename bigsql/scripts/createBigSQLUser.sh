#!/bin/sh

host=`hostname -f`

printf "\n Creating BigSQL user in $host \n"

groupadd -g 1001 hadoop

useradd -u 2824 -g hadoop bigsql

printf "\n Changing BigSQL password \n"
echo bigsql:passw0rd | chpasswd

rm -rf /var/run/nologin /run/nologin

printf "\n Setting up the SSH Key for $host \n"
mkdir /home/bigsql/.ssh
chown bigsql:hadoop /home/bigsql/.ssh
sudo -u bigsql ssh-keygen -f /home/bigsql/.ssh/id_rsa -t rsa -N ''


printf "\n Completed the BigSQL user creation on $host \n\n"
