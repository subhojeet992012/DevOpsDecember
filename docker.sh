#!/bin/bash

## Source Common Functions
curl -s "https://raw.githubusercontent.com/devops2k18/scripts/master/common-functions.sh" >/tmp/common-functions.sh
#source /root/scripts/common-functions.sh
source /tmp/common-functions.sh

## Checking Root User or not.
CheckRoot

## Checking SELINUX Enabled or not.
CheckSELinux

## Checking Firewall on the Server.
CheckFirewall

## Setting Up Docker Repository.
DockerCERepo

## Installing Docker
yum install bind-utils docker-ce http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.21-1.el7.noarch.rpm -y &>/dev/null
if [ $? -eq 0 ]; then  
	success "Installed Docker-CE Successfully"
else
	error "Installing Docker-CE Failure"
	exit 1
fi

## Starting Docker Service
systemctl enable docker &>/dev/null
systemctl start docker &>/dev/null
if [ $? -eq 0 ]; then 
	success "Started Docker Engine Successfully"
else
	error "Starting Docker Engine Failed"
	exit 1
fi