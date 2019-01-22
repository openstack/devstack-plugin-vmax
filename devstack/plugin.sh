#!/bin/bash

# devstack/plugin.sh
# Setup PowerMax as backend for Devstack

function update_volume_type {
# Update volume types
    for be in ${CINDER_ENABLED_BACKENDS//,/ }; do
        be_name=${be##*:}
        be_type=${be%%:*}
        if [[ ${be_type} == "powermax" ]]; then
            array="${be_name}_Array"
            srp="${be_name}_SRP"
            slo="None"
            workload="None"
            pool_name=${!srp}+${!array}
            powermax_temp="${be_name}_WORKLOAD"
            if [  -n "${!powermax_temp}" ]; then
                workload="${be_name}_WORKLOAD"
                pool_name=${!workload}+${pool_name}
            else
                pool_name=${workload}+${pool_name}
            fi
            powermax_temp="${be_name}_SLO"
            if [  -n "${!powermax_temp}" ]; then
                slo="${be_name}_SLO"
                pool_name=${!slo}+${pool_name}
            else
                pool_name=${slo}+${pool_name}
            fi
            openstack volume type set --property pool_name="${pool_name}" \
            ${be_name}
        fi
    done
}

function configure_port_groups {
    local be_name=$1
    powermax_temp="${be_name}_PortGroup"
    dell_emc_portGroups=0
    for i in ${!PowerMax*}; do
        temp1=${i##${powermax_temp}}
        if [[ "$temp1" == "$i" ]]; then
            continue
        fi
        arrIN=(${temp1//_/ })
        if [[ "${arrIN[0]}" -gt "$dell_emc_portGroups" ]]; then
            dell_emc_portGroups=${arrIN[0]}
        fi
    done
    pg_list="["
    for (( m=1 ; m<=dell_emc_portGroups ; m++ )) ; do
        powermax_temp="${be_name}_PortGroup${m}"
        pg_list="${pg_list}${!powermax_temp}"
        if (( m!=dell_emc_portGroups )) ; then
            pg_list="${pg_list},"
        fi
    done
    pg_list="${pg_list}]"
    iniset ${CINDER_CONF} ${be_name} powermax_port_groups ${pg_list}
}

function configure_single_pool {
    local be_name=$1
    configure_port_groups ${be_name}
    for val in "SSLVerify"  "Array" "SRP" "RestPassword" "RestUserName"\
    "RestServerPort" "RestServerIp" ; do
        powermax_temp="${be_name}_${val}"
        if [  -n "${!powermax_temp}" ]; then
            if [[ "${val}" == "RestServerIp" ]]; then
                iniset ${CINDER_CONF} ${be_name} san_ip ${!powermax_temp}
            elif [[ "${val}" == "RestServerPort" ]]; then
                iniset ${CINDER_CONF} ${be_name} san_rest_port ${!powermax_temp}
            elif [[ "${val}" == "RestUserName" ]]; then
                iniset ${CINDER_CONF} ${be_name} san_login ${!powermax_temp}
            elif [[ "${val}" == "RestPassword" ]]; then
                iniset ${CINDER_CONF} ${be_name} san_password ${!powermax_temp}
            elif [[ "${val}" == "Array" ]]; then
                iniset ${CINDER_CONF} ${be_name} powermax_array ${!powermax_temp}
            elif [[ "${val}" == "SRP" ]]; then
                iniset ${CINDER_CONF} ${be_name} powermax_srp ${!powermax_temp}
            elif [[ "${val}" == "SSLVerify" ]]; then
                if [[ "${!powermax_temp}" != "False" ]]; then
                    iniset ${CINDER_CONF} ${be_name} driver_ssl_cert_verify \
                    True
                    iniset ${CINDER_CONF} ${be_name} driver_ssl_cert_path \
                    ${!powermax_temp}
                fi
            fi
        fi
    done
}

function configure_cinder_backend_powermax {
    local be_name=$1
    local emc_multi=${be_name%%_*}

    configure_single_pool ${be_name}

    storage_proto="${be_name}_StorageProtocol"
    powermax_directory="cinder.volume.drivers.dell_emc.powermax."
    if [[ "${!storage_proto}" == "iSCSI" ]]; then
        iniset ${CINDER_CONF} ${be_name} volume_driver \
        "${powermax_directory}iscsi.PowerMaxISCSIDriver"
    fi
    if [ "${!storage_proto}" = "FC" ]; then
        iniset ${CINDER_CONF} ${be_name} volume_driver \
        "${powermax_directory}fc.PowerMaxFCDriver"
    fi
    iniset ${CINDER_CONF} ${be_name} volume_backend_name ${be_name}
}

if [[ "$1" == "stack" && "$2" == "pre-install" ]]; then
    # no-op
    :
elif [[ "$1" == "stack" && "$2" == "install" ]]; then
    # no-op
    :
elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
    # no-op
    :
elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
    update_volume_type
elif [[ "$1" == "stack" && "$2" == "post-extra" ]]; then
    # no-op
    :
fi

if [[ "$1" == "unstack" ]]; then
    # no-op
    :
fi

if [[ "$1" == "clean" ]]; then
    # no-op
:
fi
