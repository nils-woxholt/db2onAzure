#!/bin/bash

userPubKeyValue=$1
rhelPrivKeyValue=$2
rhelPubKeyValue=$3
rootPrivKeyValue=$4
rootPubKeyValue=$5
db2bits=$6
nbDb2MemberVms=$7
nbDb2CfVms=$8
logPath=$9

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

bash -v ${DIR}/startnetwork_root.sh &> >(tee -a $logPath)
bash -v ${DIR}/setsshkeys_root.sh "$userPubKeyValue" "$rhelPrivKeyValue" "$rhelPubKeyValue" "$rootPrivKeyValue" "$rootPubKeyValue" &> >(tee -a $logPath)
bash -v ${DIR}/db2_root.sh "$db2bits" "$nbDb2MemberVms" "$nbDb2CfVms" &> >(tee -a $logPath)
