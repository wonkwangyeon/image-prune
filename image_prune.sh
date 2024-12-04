#!/bin/bash


if [ -z $API_URL ] || [ -z $API_TOKEN ] || [ -z $KEY_NAME ] ; then
	echo "API URL or API_TOKEN or KEY_NAME is not blank"
	exit 1
fi

SSH_KEY=$(ls /etc/sshkey)

if [ -z "$SSH_KEY" ] ; then
	echo "Required Volume Mount : /etc/sshkey"	
	exit 1
fi

OS_USER="${OS_USER:=root}"
CRI_TYPE="${CRI_TYPE:=docker}"
IMAGE_PRUNE="docker image prune -a"
CONTROL_PLANE="${CONTROL_PLANE:=true}"
LOG_FILE="${LOG_FILE:=false}"
IP_LIST=""

if [ $CRI_TYPE == "crictl" ] ; then
	IMAGE_PRUNE="crictl rmi --prune"
fi

if [ $CONTROL_PLANE == "true" ] ; then
	echo "CONTROL_PLANE : true"
	
	IP_LIST=($(curl https://$API_URL:6443/api/v1/nodes --header "Authorization: Bearer $API_TOKEN" --insecure | jq '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True"))' | jq '.status.addresses[] | select(.type=="InternalIP") | .address'))
else
	echo "CONTROL_PLANE : false"
	
	IP_LIST=($(curl https://$API_URL:6443/api/v1/nodes --header "Authorization: Bearer $API_TOKEN" --insecure | jq '.items[] | select(.status.conditions[].type=="Ready" and .status.conditions[].status=="True" and .metadata.labels."node-role.kubernetes.io/control-plane"!="")' | jq '.status.addresses[] | select(.type=="InternalIP") | .address'))
fi

filename=image-prune_$(date '+%Y%m%d%H%M').log
for IP in "${IP_LIST[@]}"; do
	IP=${IP#\"}
	IP=${IP%\"}
	echo "CRI_TYPE : $CRI_TYPE"
        echo "IP : $IP"

	echo "OS_USER : $OS_USER"
	
	if [ $LOG_FILE == "true" ]; then
		job_log=`ssh -i /etc/sshkey/$KEY_NAME -o StrictHostKeyChecking=no $OS_USER@$IP $IMAGE_PRUNE`
		echo $job_log
		echo "===== start : $IP =====" >> /var/log/$filename
		echo $job_log >> /var/log/$filename
		echo "==========end==========" >> /var/log/$filename
	else
		ssh -i /etc/sshkey/$KEY_NAME -o StrictHostKeyChecking=no $OS_USER@$IP $IMAGE_PRUNE
	fi
done       

echo "done"
