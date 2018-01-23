#!/bin/bash

LOG=/tmp/appStack
ID=$(id -u)

CONN_URL=http://redrockdigimark.com/apachemirror/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.42-src.tar.gz
CONN_TAR_FILE=$(echo $CONN_URL | cut -d / -f8) # echo $CONN_URL | awk -F / '{print $NF}'
CONN_DIR_HOME=$(echo $CONN_TAR_FILE | sed -e 's/.tar.gz//g' )

TOMCAT_URL=$(curl https://tomcat.apache.org/download-90.cgi | grep Core: -A 20 | grep nofollow | grep tar.gz | cut -d '"' -f2)
TOMCAT_TAR_FILE=$(echo $TOMCAT_URL | awk -F / '{print $NF}')
TOMCAT_DIR_HOME=$(echo $TOMCAT_TAR_FILE | sed -e 's/.tar.gz//g')

JDBC_URL=https://github.com/devops2k18/DevOpsDecember/raw/master/APPSTACK/mysql-connector-java-5.1.40.jar
JDBC_DRIVER=$(echo $JDBC_URL | awk -F / '{print $NF}')

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"



echo "Installing Web server"

if [ $ID -ne 0 ];then
	echo "You are not the root user, you dont have permission to run this script"
	exit 12
fi

VALIDATE(){
	if [ $? -eq 0 ]; then
		echo -e "$2 .... $G SUCCESS $N"
	else
		echo -e  "$2 .... $R FAILED $N"
		exit 2
	fi

}

SKIP(){
	echo -e "$1 Exist... $Y SKIPPING $N"
}

yum install httpd httpd-devel gcc -y &>>$LOG

VALIDATE $? "HTTPD installation"

systemctl enable httpd &>>$LOG

VALIDATE $? "Enabling HTTPD"

systemctl restart httpd &>>$LOG

VALIDATE $? "Starting HTTPD"

if [ -f /opt/$CONN_TAR_FILE ]; then

	SKIP "MOD_JK"
else
	wget $CONN_URL -O /opt/$CONN_TAR_FILE &>>$LOG
	VALIDATE $? "Downloading MOD_JK"
fi


cd /opt

if [ -d $CONN_DIR_HOME ]; then
	SKIP "MOD_JK Extraction"
else
	tar -xf $CONN_TAR_FILE
	VALIDATE $? "Extracting MOD_JK"
fi


if [ -f /etc/httpd/modules/mod_jk.so ]; then
	SKIP "Compiling MOD_JK"
else
	cd $CONN_DIR_HOME/native
	./configure --with-apxs=/bin/apxs &>>$LOG && make clean &>>$LOG && make &>>$LOG && make install &>>$LOG
	VALIDATE $? "Compiling MOD_JK"
fi

cd /etc/httpd/conf.d
rm -rf modjk.conf
echo 'LoadModule jk_module modules/mod_jk.so
JkWorkersFile conf.d/workers.properties
JkLogFile logs/mod_jk.log
JkLogLevel info
JkLogStampFormat "[%a %b %d %H:%M:%S %Y]"
JkOptions +ForwardKeySize +ForwardURICompat -ForwardDirectories
JkRequestLogFormat "%w %V %T"
JkMount /student tomcatA
JkMount /student/* tomcatA' > modjk.conf
rm -rf workers.properties
echo "### Define workers
worker.list=tomcatA
### Set properties
worker.tomcatA.type=ajp13
worker.tomcatA.host=localhost
worker.tomcatA.port=8009" > workers.properties

echo -e "\n Installing JAVA"
yum install java -y &>$LOG
VALIDATE $? "Installing JAVA"

echo -e "\nInstalling App Server"

if [ -f /opt/$TOMCAT_TAR_FILE ]; then
	SKIP "Downloading Tomcat"
else
	wget $TOMCAT_URL -O /opt/$TOMCAT_TAR_FILE &>>$LOG
	VALIDATE $? "Downloading Tomcat"
fi

cd /opt

if [ -d $TOMCAT_DIR_HOME ]; then
	SKIP "Extracting Tomcat"
else
	tar -xf $TOMCAT_TAR_FILE &>>$LOG
	VALIDATE $? "Extracting Tomcat"
fi

cd $TOMCAT_DIR_HOME/webapps

rm -rf *;

wget https://github.com/devops2k18/DevOpsDecember/raw/master/APPSTACK/student.war &>>$LOG
VALIDATE $? "Downloading student.war"

cd ../lib

if [ -f $JDBC_DRIVER ]; then
	SKIP "Downloading MySQL driver"
else
	wget $JDBC_URL &>>$LOG
	VALIDATE $? "Downloading MySQL driver"
fi

cd /opt/$TOMCAT_DIR_HOME/conf

sed -i -e '/TestDB/ d' context.xml

sed -i -e  '$ i <Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxTotal="100" maxIdle="30" maxWaitMillis="10000" username="student" password="student@1" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://localhost:3306/studentapp"/>' context.xml
VALIDATE $? "Configuring database info in oontext.xml"

echo -e "\nInstalling MARIADB"
yum install mariadb mariadb-server -y &>>$LOG
VALIDATE $? "Installing MARIADB"

systemctl enable mariadb &>>$LOG
VALIDATE $? "Enabling MARIADB"

systemctl start mariadb
VALIDATE $? "Starting MARIADB"


echo "create database if not exists studentapp;
use studentapp;
CREATE TABLE if not exists Students(student_id INT NOT NULL AUTO_INCREMENT,
	student_name VARCHAR(100) NOT NULL,
    student_addr VARCHAR(100) NOT NULL,
	student_age VARCHAR(3) NOT NULL,
	student_qual VARCHAR(20) NOT NULL,
	student_percent VARCHAR(10) NOT NULL,
	student_year_passed VARCHAR(10) NOT NULL,
	PRIMARY KEY (student_id)
);
grant all privileges on studentapp.* to 'student'@'localhost' identified by 'student@1';" > /tmp/student.sql

mysql </tmp/student.sql
VALIDATE $? "studentapp database creation"

cd /opt/$TOMCAT_DIR_HOME/bin
sh shutdown.sh &>>$LOG
sh startup.sh &>>$LOG

systemctl restart httpd