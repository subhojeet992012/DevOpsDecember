#!/bin/bash

ID=$(id -u)
LOG=/tmp/stack.log
CONN_HTTP_URL=http://www-eu.apache.org/dist/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.42-src.tar.gz
CONN_TAR_FILE=$(echo $CONN_HTTP_URL | awk -F / '{print $NF}')
CONN_DIR_HOME=$(echo $CONN_TAR_FILE | sed -e 's/.tar.gz//g')

TOMCAT_HTTP_URL=$(curl https://tomcat.apache.org/download-90.cgi | grep Core: -A 20 | grep nofollow | grep .tar.gz | cut -d '"' -f2)
TOMCAT_TAR_FILE=$(echo $TOMCAT_HTTP_URL | awk -F / '{print $NF}')
TOMCAT_DIR_HOME=$(echo $TOMCAT_TAR_FILE | sed -e 's/.tar.gz//g')

STUDENT_WAR_FILE=https://github.com/devops2k18/DevOpsDecember/raw/master/APPSTACK/student.war
MYSQL_LIB_URL=https://github.com/devops2k18/DevOpsDecember/raw/master/APPSTACK/mysql-connector-java-5.1.40.jar
MYSQL_DRIVER=$(echo $MYSQL_LIB_URL | cut -d / -f9)

G="\e[32m"
R="\e[31m"
N="\e[0m"
Y="\e[33m"

if [ $ID -ne 0 ]; then
	echo "You should be root user to run this script"
	exit 1
fi


VALIDATE(){
	if [ $1 -ne 0 ];then
		echo -e "$2 ... $R FAILED $N"
		exit 2
	else
		echo -e "$2 ... $G SUCCESS $N"
	fi

}

SKIP(){
	echo -e "$1 ...$Y SKIPPING $N"
}

yum install httpd -y &>>$LOG

VALIDATE $? "WebServer installation"

systemctl start httpd &>>$LOG

VALIDATE $? "Restarting Web Server"

cd /opt/

if [ -f $CONN_TAR_FILE ];then
	SKIP "Downloading The MOD_JK"
else
	wget $CONN_HTTP_URL &>>$LOG
	VALIDATE $? "Downloading The MOD_JK"
fi

if [ -d $CONN_DIR_HOME ];then
	SKIP "Extracting MOD_JK"
else
	tar -xf $CONN_TAR_FILE
	VALIDATE $? "Extracting MOD_JK"
fi

yum install gcc httpd-devel java -y &>>$LOG

VALIDATE $? "Installing gcc and httpd-devel"

cd $CONN_DIR_HOME/native

if [ -f /etc/httpd/modules/mod_jk.so ];then
	SKIP "Compiling MOD_JK"
else
	./configure --with-apxs=/bin/apxs &>>$LOG && make &>>$LOG && make install &>>$LOG
	VALIDATE $? "Compiling MOD_JK"
fi

cd /etc/httpd/conf.d

if [ -f modjk.conf ];then
	SKIP "Creating modjk.conf"
else
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
fi

if [ -f workers.properties ];then
	SKIP "Creating workers.properties"
else
	echo '### Define workers
	worker.list=tomcatA
	### Set properties
	worker.tomcatA.type=ajp13
	worker.tomcatA.host=localhost
	worker.tomcatA.port=8009' > workers.properties

	VALIDATE $? "Creating workers.properties"
fi

cd /opt/

pwd

if [ -f $TOMCAT_TAR_FILE ]; then
	SKIP "Downloading TOMCAT"
else
	wget $TOMCAT_HTTP_URL &>>$LOG
	VALIDATE $? "Downloading TOMCAT"
fi

if [ -d $TOMCAT_DIR_HOME ];then
	SKIP "Extracting TOMCAT"
else
	tar -xf $TOMCAT_TAR_FILE
	VALIDATE $? "Extracting TOMCAT"
fi

pwd
echo $TOMCAT_DIR_HOME

cd $TOMCAT_DIR_HOME/webapps/

pwd

rm -rf *;

wget $STUDENT_WAR_FILE &>>$LOG

VALIDATE $? "Downloading student project"

cd ../lib

if [ -f $MYSQL_DRIVER ];then
	SKIP "Downloading MySQL driver"
else
	wget $MYSQL_LIB_URL &>>$LOG
	VALIDATE $? "Downloading MySQL driver"
fi

cd ../conf

sed -i -e '/TestDB/ d' context.xml

sed -i -e '$ i <Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxTotal="100" maxIdle="30" maxWaitMillis="10000" username="student" password="student@1" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://localhost:3306/studentapp"/>' context.xml

VALIDATE $? "Modifying context.xml"

yum install mariadb mariadb-server -y &>>$LOG

VALIDATE $? "Installing mariadb"

systemctl restart mariadb &>>$LOG

VALIDATE $? "Restarting mariadb"

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

VALIDATE $? "Creation of student.sql"

mysql < /tmp/student.sql

cd /opt/$TOMCAT_DIR_HOME/bin

sh shutdown.sh &>>$LOG

sh startup.sh &>>$LOG

VALIDATE $? "Restarting TOMCAT"

systemctl restart httpd &>>$LOG

VALIDATE $? "Restarting Apache"

