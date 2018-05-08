#!/bin/bash

nbDb2MemberVms=$1
nbDb2CfVms=$2

scp -o StrictHostKeyChecking=no /tmp/fromg0_root.sh 192.168.0.10:/tmp/
ssh -o StrictHostKeyChecking=no 192.168.0.10 sudo -n -u root -s bash /tmp/fromg0_root.sh


db2servers=()
for (( i=0; i<$nbDb2MemberVms; i++ ))
do
    db2servers+=(192.168.0.2$i)
done

for (( i=0; i<$nbDb2MemberVms; i++ ))
do
    db2servers+=(192.168.0.3$i)
done

ssh -o StrictHostKeyChecking=no 192.168.0.20 << 'EOSSH'
sudo -n -u root -s fdisk -l | grep /dev/mapper/3 > /tmp/iscsidisks.txt
EOSSH
scp 192.168.0.20:/tmp/iscsidisks.txt .

ssh -o StrictHostKeyChecking=no 192.168.0.20 sudo -n -u root -s bash /tmp/fromd0getwwids_root.sh
scp 192.168.0.20:/tmp/initwwids.sh /tmp/initwwids.sh
source /tmp/initwwids.sh

for db2srv in "${db2servers[@]}"
do
ssh -o StrictHostKeyChecking=no $db2srv << 'EOSSH'
sudo sed -i "s/36001405149ee39c319845aaa710099a7/${wwiddb2data1}/g" /etc/multipath.conf
sudo sed -i "s/36001405bfc71ff861174f2bbb0bfea37/${wwiddb2log1}/g" /etc/multipath.conf
sudo sed -i "s/36001405484ba6ab80934f2290a2b579f/${wwiddb2shared}/g" /etc/multipath.conf
sudo sed -i "s/36001405645b2e72c56142ef97932cb95/${wwiddb2tieb}/g" /etc/multipath.conf

sudo -n -u root -s shutdown -r now
EOSSH
done

scp -o StrictHostKeyChecking=no /tmp/fromd0_root.sh 192.168.0.20:/tmp/


#TODO wait for the reboot to finish

ssh -o StrictHostKeyChecking=no 192.168.0.20 sudo -n -u root -s bash /tmp/fromd0_root.sh $nbDb2MemberVms $nbDb2CfVms $wwiddb2data1 $wwiddb2log1 $wwiddb2shared $wwiddb2tieb