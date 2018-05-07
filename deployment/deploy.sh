#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#Parameters

usage() { 
    echo "Expected arguments are: "
    echo "- subscription (-s): Azure subscription name"
    echo "- resourceGroupName (-g): Azure resource group name"
    echo "- location (-l): Azure region where the resources will be created"
    echo "- deploymentName (-n): Azure region where the resources will be created"
    echo "- pubKeyPath (-k): path to the public key to be used for jumpbox access"
    echo "- adwinPassword (-p): password for the 'adwin' user on Windows boxes"
    echo "- db2bits (-d): location where the 'v11.1_linuxx64_server_t.tar.gz' file can be downloaded from"
    echo "- gitrawurl (-u): folder where this repo is, with a trailing /. E.g.: https://raw.githubusercontent.com/benjguin/db2onAzure/master/"
    echo "- jumpboxPublicName (-j): folder where this repo is, with a trailing /. E.g.: https://raw.githubusercontent.com/benjguin/db2onAzure/master/"
    echo ""
    echo "Usage: $0 -s <subscription> -g <resourceGroupName> -l <location> -n <deploymentName> -k pubKeyPath -p adwinPassword -d db2bits -u gitrawurl" 1>&2
    exit 1
}

declare subscription=""
declare rg=""
declare location=""
declare pubKeyPath=""
declare adwinPassword=""
declare db2bits=""
declare gitrawurl=""
declare jumpboxPublicName=""

# Initialize parameters specified from command line
while getopts ":d:g:k:l:n:p:s:u:" arg; do
	case "${arg}" in
		d)
			db2bits=${OPTARG}
			;;
		g)
			rg=${OPTARG}
			;;
		j)
			jumpboxPublicName=${OPTARG}
			;;
		k)
			pubKeyPath=${OPTARG}
			;;
		l)
			location=${OPTARG}
			;;
		n)
			deploymentName=${OPTARG}
			;;
		p)
			adwinPassword=${OPTARG}
			;;
		s)
			subscription=${OPTARG}
			;;
		u)
			gitrawurl=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))

#Prompt for parameters is some required parameters are missing
if [[ -z "$subscription" ]]; then
	echo "Your subscription name can be looked up with the CLI using: az account list"
	echo "Enter your subscription name:"
	read subscription
	[[ "${subscription:?}" ]]
fi

if [[ -z "$rg" ]]; then
	echo "This script will look for an existing resource group, otherwise a new one will be created "
	echo "You can create new resource groups with the CLI using: az group create "
	echo "Enter a resource group name"
	read rg
	[[ "${rg:?}" ]]
fi

if [[ -z "$location" ]]; then
	echo "If creating a *new* resource group, you need to set a location "
	echo "You can lookup locations with the CLI using: az account list-locations "
	echo "default value: westeurope"
	
	echo "Enter resource group location:"
	read location
    if [[ -z "$location" ]]; then
        location="westeurope"
    fi
fi

if [[ -z "$deploymentName" ]]; then
	echo "Enter a name for this deployment:"
	read deploymentName
    [[ "${deploymentName:?}" ]]
fi

if [[ -z "$pubKeyPath" ]]; then
	echo "Enter a name for the public key path (default value: ~/.ssh/id_rsa.pub):"
	read pubKeyPath
    if [[ -z "$pubKeyPath" ]]; then
        pubKeyPath=~/.ssh/id_rsa.pub
    fi
fi

if [[ -z "$adwinPassword" ]]; then
	echo "Enter a password for the 'adwin' user on Windows nodes:"
	read adwinPassword
    [[ "${adwinPassword:?}" ]]
fi

if [[ -z "$db2bits" ]]; then
	echo "Enter a URL where the 'v11.1_linuxx64_server_t.tar.gz' file can be downloaded from :"
	read db2bits
    [[ "${db2bits:?}" ]]
fi

if [[ -z "$gitrawurl" ]]; then
	echo "Enter a folder where this repo is, with a trailing /:"
	read gitrawurl
    [[ "${gitrawurl:?}" ]]
fi

if [[ -z "$jumpboxPublicName" ]]; then
	echo "Enter a jumpbox public name (a default random value would be provided otherwise):"
	read jumpboxPublicName
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#templateFile Path - template file to be used
templateFilePath="${DIR}/template.json"

if [ ! -f "$templateFilePath" ]; then
	echo "$templateFilePath not found"
	exit 1
fi

#parameter file path
parametersFilePath="${DIR}/parameters.json"

if [ ! -f "$parametersFilePath" ]; then
	echo "$parametersFilePath not found"
	exit 1
fi

if [ ! -f "$pubKeyPath" ]; then
	echo "$pubKeyPath not found"
	exit 1
fi

pubKeyValue=`cat $pubKeyPath`

#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
	az login
fi

#set the default subscription id
az account set -s "$subscription"

set +e

#Check for existing RG
az group show $rg 1> /dev/null

if [ $? != 0 ]; then
	echo "Resource group with name ${rg} could not be found. Creating new resource group.."
	set -e
	(
		set -x
		az group create --name ${rg} --location ${location} 1> /dev/null
	)
	else
	echo "Using existing resource group..."
fi

#Start deployment
echo "Starting deployment..."
(
	set -x

	# for production, Azure key vaults or othe means should be leveraged
	ssh-keygen -t rsa -f ${DIR}/rhelid_rsa -q -N ""
	ssh-keygen -t rsa -f ${DIR}/rootid_rsa -q -N ""
	rhelPrivKeyValue=`cat ${DIR}/rhelid_rsa`
	rhelPubKeyValue=`cat ${DIR}/rhelid_rsa.pub`
	rootPrivKeyValue=`cat ${DIR}/rootid_rsa`
	rootPubKeyValue=`cat ${DIR}/rootid_rsa.pub`

	az group deployment create --name "$deploymentName" --resource-group "$rg" --template-file "$templateFilePath" \
        --parameters "@${parametersFilePath}" \
        --parameters userPubKeyValue="$pubKeyValue" \
		--parameters rhelPrivKeyValue="$rhelPrivKeyValue" rhelPubKeyValue="$rhelPubKeyValue" \
		--parameters rootPrivKeyValue="$rootPrivKeyValue" rootPubKeyValue="$rootPubKeyValue" \
		--parameters adwinPassword="$adwinPassword" \
		--parameters db2bits="$db2bits" gitrawurl="$gitrawurl" jumpboxPublicName="$jumpboxPublicName"
	
	rm -f ${DIR}/rhelid_rsa
	rm -f ${DIR}/rhelid_rsa.pub
	rm -f ${DIR}/rootid_rsa
	rm -f ${DIR}/rootid_rsa.pub
)

if [ $?  == 0 ];
then
	echo "Template has been successfully deployed"
else
	echo "Template was NOT successfully deployed"
	exit 1
fi

jumpbox="${jumpboxPublicName}.${location}.cloudapp.azure.com"
nbDb2MemberVms=`az group deployment show -g $rg -n "$deploymentName" --query properties.outputs.nbDb2MemberVms.value`
nbDb2CfVms=`az group deployment show -g $rg -n "$deploymentName" --query properties.outputs.nbDb2CfVms.value`

scp -o StrictHostKeyChecking=no ${DIR}/postARMscripts/fromd0_root.sh rhel@$jumpbox:/tmp/
ssh -o StrictHostKeyChecking=no rhel@$jumpbox ${DIR}/postARMscripts/fromjumpbox.sh $nbDb2MemberVms $nbDb2CfVms
