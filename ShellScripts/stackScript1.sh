#!/bin/bash


########Variables#######
ID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

rm -rf /tmp/stack
LOG=/tmp/stack
MOD_JK_URL=http://redrockdigimark.com/apachemirror/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.42-src.tar.gz
MOD_JK_TAR=$(echo $MOD_JK_URL | cut -d / -f8) #echo $MOD_JK_URL | awk -F / '{print $1}'
MOD_JK_DIR=$(echo $MOD_JK_TAR | sed -e 's/.tar.gz//g')

TOMCAT_URL=$(curl -s https://tomcat.apache.org/download-90.cgi | grep Core -A 20 | grep nofollow | grep tar.gz | cut -d '"' -f2)
TOMCAT_TAR=$(echo $TOMCAT_URL | awk -F / '{print $NF}')
TOMCAT_DIR=$(echo $TOMCAT_TAR | sed -e 's/.tar.gz//g')

STUDENT_WAR_URL=https://github.com/devops2k18/DevOpsDecember/raw/master/APPSTACK/student.war
JDBC_URL=https://github.com/devops2k18/DevOpsDecember/raw/master/APPSTACK/mysql-connector-java-5.1.40.jar
JDBC_FILE=$(echo $JDBC_URL | awk -F / '{print $NF}')


#######Functions#######

VALIDATE(){
	if [ $1 -eq 0 ]; then
		echo -e "$2 .... $G SUCCESS $N"
	else
		echo -e "$2 .... $R FAILURE $N"
		exit 1
	fi
}

SKIP(){
	echo -e "$1 ... $Y SKIPPING $N"

}

if [ $ID -ne 0 ]; then
	echo "You need to be root to run this script"
	exit 2
else
	echo "you are root user, script is running"
fi

echo "Installing Web Server"

yum install httpd httpd-devel gcc -y &>>$LOG

VALIDATE $? "Installing HTTPD"

systemctl enable httpd &>>$LOG

VALIDATE $? "Enabling HTTPD"

systemctl start httpd &>>$LOG

VALIDATE $? "Starting HTTPD"


echo "Downloading MOD_JK"

cd /opt

if [ -f $MOD_JK_TAR ]; then
	SKIP "Downloading MOD_JK"
else
	wget $MOD_JK_URL -O /opt/$MOD_JK_TAR &>>$LOG
	VALIDATE $? "Downloading MOD_JK"
fi

cd /opt

if [ -d $MOD_JK_DIR ]; then
	SKIP "Extracting MOD_JK"
else
	tar -xf $MOD_JK_TAR &>>$LOG
	VALIDATE $? "Extracting MOD_JK"
fi

if [ -f /etc/httpd/modules/mod_jk.so ]; then
	SKIP "Compiling MOD_JK"
else
	cd $MOD_JK_DIR/native
	echo "Compiling MOD_JK"
	./configure --with-apxs=/bin/apxs &>>$LOG && make clean &>>$LOG && make &>>$LOG && make install &>>$LOG
	VALIDATE $? "Compiling MOD_JK"
fi


echo -e "\nInstalling Java"
yum install java -y &>>$LOG
VALIDATE $? "Installing JAVA"

echo -e "\nInstalling TOMCAT"

cd /opt

if [ -f $TOMCAT_TAR ]; then
	SKIP "Downloading TOMCAT"
else
	wget $TOMCAT_URL &>>$LOG
	VALIDATE $? "Downloading TOMCAT"
fi

if [ -d $TOMCAT_DIR ]; then
	SKIP "Extracting TOMCAT"
else
	tar -xf $TOMCAT_TAR
	VALIDATE $? "Extracting TOMCAT"
fi

cd $TOMCAT_DIR/webapps

rm -rf *

wget $STUDENT_WAR_URL &>>$LOG
VALIDATE $? "Downloading student.war"

cd ../lib

if [ -f $JDBC_FILE ]; then
	SKIP "Downloading MySQL driver"
else
	wget $JDBC_URL &>>$LOG
	VALIDATE $? "Downloading MySQL driver"
fi

cd ../conf

sed -i -e '/TestDB/ d' context.xml

sed -i -e '$ i <Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxTotal="100" maxIdle="30" maxWaitMillis="10000" username="student" password="student@1" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://localhost:3306/studentapp"/>' context.xml

VALIDATE $? "Configuring context.xml"

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

VALIDATE $? "Creating modjk.conf"

rm -rf workers.properties

echo '### Define workers
worker.list=tomcatA
### Set properties
worker.tomcatA.type=ajp13
worker.tomcatA.host=localhost
worker.tomcatA.port=8009' > workers.properties

VALIDATE $? "Creating workers.properties"

echo -e "\nInstalling DB"

yum install mariadb mariadb-server -y &>>$LOG
VALIDATE $? "Installing MariaDB"

systemctl enable mariadb &>>$LOG
VALIDATE $? "Enabling MariaDB"

systemctl start mariadb &>>$LOG
VALIDATE $? "Starting mariadb"

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

mysql < /tmp/student.sql

VALIDATE $? "Creating Students DB"

cd /opt/$TOMCAT_DIR/bin
sh shutdown.sh &>>$LOG

sh startup.sh &>>$LOG
VALIDATE $? "Starting TOMCAT"

systemctl restart httpd &>>$LOG
VALIDATE $? "Restarting HTTPD"
