#!/bin/bash
set -e
[ -z $1 ] && echo "Usage: CreateLDAP.sh <testVO dir>" && exit 1

testVO=$(realpath -m $1)
ldap_conf_dir="$testVO/slapd/slapd.d"
jalien_setup="/jalien-setup/bash-setup"

ldap_port="8389"
ldap_pass="pass"

function ldap_apply_ldif () {
    file=$1
    ldapadd -x -w ${ldap_pass} -h localhost -p ${ldap_port} -D "cn=Manager,dc=localdomain" -f "$file"
}

function createConfig(){
    mkdir -p $ldap_conf_dir
    rsync -a "${jalien_setup}/ldap/config/" "$ldap_conf_dir"
}

function createSchema(){
    rsync -a "${jalien_setup}/ldap/schema/" "$ldap_conf_dir/cn=config"
}

function startLDAP(){
    ldap_log="$testVO/logs/ldap.log"

    mkdir -p $(dirname $ldap_log)
    nohup slapd -d -1 -s 0 -h ldap://:${ldap_port} -F ${ldap_conf_dir} > ${ldap_log} 2>&1> /dev/null&
}

function initializeLDAP(){
    arr=(
        # setup VO
        add_domain
        add_org
        add_packages
        add_institutions
        add_partitions
        add_people
        add_roles
        add_services
        add_sites
        ldap_init

        # add users
        add_user_admin
        add_role_admin

        # add roles
        add_user_jalien
        add_role_jalien

        # add site
        add_site_jtest
        add_config_jtest
        add_services_jtest
        add_SE_jtest
        add_CE_jtest
        add_FTD_jtest

        # add SE
        add_SE_firstse
    )

    for i in ${arr[@]}
    do
        echo $i
        ldap_apply_ldif $jalien_setup/ldap/ldif/${i}.ldif
    done
}

createConfig
createSchema
startLDAP
sleep 2
initializeLDAP
echo "CreateLDAP.sh done"
