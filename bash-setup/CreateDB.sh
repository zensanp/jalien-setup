#!/bin/bash
sql_home="${HOME}/.j/testVO/sql"
sql_socket="${sql_home}/jalien-mysql.sock"
sql_pid_file="/tmp/jalien-mysql.pid"
sql_log="${sql_home}/jalien-mysql.log"
sql_port=3307
systemDB="testVO_system"
dataDB="testVO_data"
userDB="testVO_users"
my_cnf="${sql_home}/my.cnf"
mysql_pass="pass"
VO_name=localhost
base_home_dir="/localhost/localdomain/user/"
act_base_home_dir="localhost/localdomain/user/"
[[ -z $USER ]] && username=$(id -u -n) || username=$USER 
my_cnf_content="[mysqld]\n
                sql_mode=\n
                user= ${username}\n
                datadir=${sql_home}/data\n
                port= ${sql_port}\n 
                socket= ${sql_socket}\n\n

                [mysqld_safe]\n
                log-error=${sql_log}\n
                pid-file=${sql_pid_file}\n\n 

                [client]\n
                port=${sql_port}\n
                user=${username}\n
                socket=${sql_socket}\n\n

                [mysqladmin]\n
                user=root\n
                port=${sql_port}\n
                socket=${sql_socket}\n\n

                [mysql]\n
                port=${sql_port}\n
                socket=${sql_socket}\n\n

                [mysql_install_db]\n
                user=${username}\n
                port=${sql_port}\n
                datadir=${sql_home}/data\n
                socket=${sql_socket}\n\n\n"


function die(){ 
	if [[ $? -ne 0 ]]; then {
		echo "$1"
		exit 1
	}
	fi
}

function initializeDB() {
    echo -e $my_cnf_content > $my_cnf
    mysqld --defaults-file=$my_cnf --initialize-insecure --datadir="${sql_home}/data" 
}

function startDB(){
    mysqld_safe --defaults-file=$my_cnf &> /dev/null&
}

function fillDatabase(){
    cp /jalien/docker-setup/mysql_passwd.txt /tmp
    sed -i -e "s:sql_pass:${mysql_pass}:g" -e "s:systemDB:${systemDB}:g" -e "s:dataDB:${dataDB}:g" -e "s:userDB:${userDB}:g" /tmp/mysql_passwd.txt

    mysql --verbose -u root -h 127.0.0.1 -P $sql_port -D mysql < /tmp/mysql_passwd.txt
}

function createCatalogueDB(){
    cp /jalien/docker-setup/createCatalogue.txt /tmp
    sed -i -e "s:catDB:${1}:g" /tmp/createCatalogue.txt
    mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql < /tmp/createCatalogue.txt
}

function addToHOSTSTABLE(){
    cp /jalien/docker-setup/hostIndex.txt /tmp
    sed -i -e "s:systemDB:${systemDB}:g" -e "s:dataDB:${dataDB}:g" -e "s:userDB:${userDB}:g" -e "s:hostIndex:${1}:g" -e "s~address~${2}~g" -e "s:db:${3}:g" /tmp/hostIndex.txt  
    mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql < /tmp/hostIndex.txt 
}

function addToINDEXTABLE(){
    cp /jalien/docker-setup/addIndexTable.txt /tmp
    sed -i -e "s:systemDB:${systemDB}:g" -e "s:dataDB:${dataDB}:g" -e "s:userDB:${userDB}:g" -e "s:hostIndex:${1}:g" -e "s:tableName:${2}:g" -e "s:lfn:${3}:g" /tmp/addIndexTable.txt  
    mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql < /tmp/addIndexTable.txt
}

function addToGUIDINDEXTABLE(){
    cp /jalien/docker-setup/addGUIDIndex.txt /tmp
    sed -i -e "s:systemDB:${systemDB}:g" -e "s:dataDB:${dataDB}:g" -e "s:userDB:${userDB}:g" -e "s:indexId:${1}:g" -e "s:hostIndex:${2}:g" -e "s:tableName:${3}:g" -e "s:guidTime:${4}:g" -e "s:guid2Time2:${5}:g" /tmp/addGUIDIndex.txt  
    mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql < /tmp/addGUIDIndex.txt
}


function catalogueInitialDirectories(){
    addToGUIDINDEXTABLE 1 1 0
    addToINDEXTABLE 1 0 /
    addToINDEXTABLE 2 0 $base_home_dir
    addToHOSTSTABLE 1 "${VO_name}:${sql_port}" $dataDB
    addToHOSTSTABLE 2 "${VO_name}:${sql_port}" $userDB
    sql_cmd="USE ${dataDB};LOCK TABLES L0L WRITE;INSERT INTO L0L VALUES (0,'admin',0,'2011-10-06 17:07:26',NULL,NULL,NULL,'',0,NULL,0,NULL,'admin','d',NULL,NULL,'755');UNLOCK TABLES;"
    echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql
    sql_cmd="select entryId from ${dataDB}.L0L where lfn = '';"
    parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
    local IFS="/"
    arr=$act_base_home_dir
    new_path=''
    echo "finished out of loop"
    for i in $arr
    do
        unset IFS
        new_path+="${i}/"
        echo $new_path
        sql_cmd="USE ${dataDB};LOCK TABLES L0L WRITE;INSERT INTO L0L VALUES (0,'admin',0,'2011-10-06 17:07:26',NULL,NULL,NULL,'${new_path}',0,NULL,0,${parentDir},'admin','d',NULL,NULL,'755');UNLOCK TABLES;"
        echo $sql_cmd
        echo $sql_cmd | mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql
        sql_cmd="select entryId from ${dataDB}.L0L where lfn = '${new_path}';"
        parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
        echo "reached so far ${parentDir}"
    done
    echo $new_path
    sql_cmd="select entryId from ${dataDB}.L0L where lfn = '${new_path}';"
    parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
    sql_cmd="UNLOCK TABLES;USE ${userDB};LOCK TABLES L0L WRITE;INSERT INTO L0L VALUES (0,'admin',0,'2011-10-06 17:07:26',NULL,NULL,NULL,'',0,NULL,0,${parentDir},'admin','d',NULL,NULL,'755');UNLOCK TABLES;"
    echo $sql_cmd | mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql
}

function userAddSubTable(){
    sql_cmd="select entryId from ${userDB}.L0L where lfn = '';"
    parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
    sub_string=$(echo $1 | cut -c1)
    addToINDEXTABLE 2 $2 "${base_home_dir}${sub_string}/$1/"
    sql_cmd="USE ${userDB};LOCK TABLES L0L WRITE;INSERT INTO L0L VALUES (0,'admin',0,'2011-10-06 17:07:26',NULL,NULL,NULL,'${sub_string}/',0,NULL,0,${parentDir},'admin','d',NULL,NULL,'755');UNLOCK TABLES;"
    echo $sql_cmd | mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql
    sql_cmd="select entryId from ${userDB}.L0L where lfn = '${sub_string}/';"
    parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
    sql_cmd="USE ${userDB};LOCK TABLES L0L WRITE;INSERT INTO L0L VALUES (0,'${1}',0,'2011-10-06 17:07:26',NULL,NULL,NULL,'$sub_string/${1}/',0,NULL,0,${parentDir},'admin','d',NULL,NULL,'755');UNLOCK TABLES;"
    echo $sql_cmd | mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql
}

function userIndexTable(){
    sub_string=$(echo $1 | cut -c1)
    sql_cmd="select entryId from ${userDB}.L0L where lfn = '${sub_string}/';"
    parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
    cp /jalien/docker-setup/userindextable.txt /tmp
    sed -i -e "s:userDB:${userDB}:g" -e "s:username:${1}:g" -e "s:actuid:${2}:g" -e "s:parentDir:${parentDir}:g" /tmp/userindextable.txt
    mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql < /tmp/userindextable.txt
}

function addUserToDB(){
    userAddSubTable $1 $2
    userIndexTable $1 $2
}

function addSEtoDB(){
    cp /jalien/docker-setup/addSE.txt /tmp
    sub_string=$(echo $4 | cut -d':' -f1)
    sed -i -e "s:dataDB:${dataDB}:g" -e "s:userDB:${userDB}:g" -e "s:systemDB:${systemDB}:g" -e "s:VO_name:${VO_name}:g" -e "s:sub_string:${sub_string}:g" \
    -e "s:seName:${1}:g" -e "s:seNumber:${2}:g" -e "s:site:${3}:g" -e "s~iodeamon~${4}~g" \
    -e "s:storedir:${5}:g" -e "s:qos:${6}:g" -e "s:freespace:${7}:g" /tmp/addSE.txt
    mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql < /tmp/addSE.txt
}

function main(){
    ( 
        set -e
        if [[ ! -z $1 && "$1" = "addUserToDB" ]]; then {
            addUserToDB $2 $3
        }
        elif [[ ! -z $1 && "$1" = "addSEtoDB" ]]; then {
            addSEtoDB $2 $3 $4 $5 $6 $7 $8
        }
        else {
            echo "here is 1:${1}"
            initializeDB
            startDB
            
            sleep 6
            
            fillDatabase
            createCatalogueDB $systemDB
            createCatalogueDB $dataDB
            createCatalogueDB $userDB

            catalogueInitialDirectories
        }
        fi
		exit 0

    )
    die "DB setup failed!"
}
main $1