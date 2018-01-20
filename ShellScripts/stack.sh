#!/bin/bash

LOG=/tmp/appStack
ID=$(id -u)
CONN_URL=http://redrockdigimark.com/apachemirror/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.42-src.tar.gz
CONN_TAR_FILE=$(echo $CONN_URL | cut -d / -f8) # echo $CONN_URL | awk -F / '{print $NF}'
CONN_DIR_HOME=$(echo $CONN_TAR_FILE | sed -e 's/.tar.gz//g' )


echo "Installing Web server"

if [ $ID -ne 0 ];then
	echo "You are not the root user, you dont have permission to run this script"
	exit 12
fi

yum install httpd httpd-devel gcc -y &>>$LOG

if [ $? -ne 0 ];then
	echo "Installing HTTPD is ... FAILED"
	exit 1
else
	echo "Installing HTTPD is ... SUCCESS"
fi


systemctl enable httpd &>>$LOG

if [ $? -ne 0 ];then
	echo "Enabling HTTPD is ... FAILED"
	exit 1
else
	echo "Enabling HTTPD is ... SUCCESS"
fi


systemctl start httpd &>>$LOG

if [ $? -eq 0 ];then
	echo "Starting HTTPD is ... SUCCESS"
else
	echo "Starting HTTPD is ... FAILED"
	exit 1
fi


echo "Downloading the MOD_JK"

wget $CONN_URL -O /opt/$CONN_TAR_FILE &>>$LOG

if [ $? -eq 0 ]; then
	echo "Downloading MOD_JK ..... SUCCESS"
else
	echo "Downloading MOD_JK ..... FAILURE"
	exit 1
fi

cd /opt

tar -xf $CONN_TAR_FILE

if [ $? -eq 0 ]; then
	echo "Extracting MOD_JK ..... SUCCESS"
else
	echo "Extracting MOD_JK ..... FAILURE"
	exit 1
fi

cd $CONN_DIR_HOME/native

./configure --with-apxs=/bin/apxs &>>$LOG && make clean &>>$LOG && make &>>$LOG && make install &>>$LOG

if [ $? -eq 0 ]; then
	echo "Compiling MOD_JK ..... SUCCESS"
else
	echo "Compiling MOD_JK ..... FAILURE"
	exit 1
fi