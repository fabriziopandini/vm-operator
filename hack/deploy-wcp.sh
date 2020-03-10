#!/usr/bin/env bash
# Deploy VMOP and install required CRDs in the given WCP supervisor cluster
#
# Usage:
# $ deploy-wcp.sh

set -o errexit
set -o nounset
set -o pipefail

SSHCommonArgs=("-o PubkeyAuthentication=no" "-o UserKnownHostsFile=/dev/null" "-o StrictHostKeyChecking=no")

# Change directories to the parent directory of the one in which this
# script is located.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

error() {
    echo "${@}" 1>&2
}

verifyEnvironmentVariables() {
    if [[ -z ${WCP_LOAD_K8S_MASTER:-} ]]; then
        error "Error: The WCP_LOAD_K8S_MASTER environment variable must be set" \
             "to point to a copy of load-k8s-master"
        exit 1
    fi

    if [[ ! -x $WCP_LOAD_K8S_MASTER ]]; then
        error "Error: Could not find the load-k8s-master script. Please " \
             "verify the environment variable WCP_LOAD_K8S_MASTER is set " \
             "properly. The load-k8s-master script is found at " \
             "bora/vpx/wcp/support/load-k8s-master in a bora repo."
        exit 1
    fi

    if [[ -z ${VCSA_IP:-} ]]; then
        error "Error: The VCSA_IP environment variable must be set" \
             "to point to a valid VCSA"
        exit 1
    fi

    if [[ -z ${VCSA_PASSWORD:-} ]]; then
        # Often the VCSA_PASSWORD is set to a default. The below sets a
        # common default so the user of this script does not need to set it.
        VCSA_PASSWORD="vmware"
    fi

    output=$(SSHPASS="$VCSA_PASSWORD" sshpass -e ssh "${SSHCommonArgs[@]}" \
            root@"$VCSA_IP" "/usr/lib/vmware-wcp/decryptK8Pwd.py" 2>&1)
    WCP_SA_IP=$(echo "$output" | grep -oEI "IP: (\\S)+" | cut -d" " -f2)
    #   WCP_SA_PASSWORD=$(echo "$output" | grep -oEI "PWD: (\\S)+" | cut -d" " -f2)

    if ! ping -c 3 -i 0.25 "$WCP_SA_IP" > /dev/null 2>&1 ; then
        error "Error: Could not access WCP Supervisor Cluster API Server at" \
            "$WCP_SA_IP"
        exit 1
    fi

    if [[ -z ${SKIP_YAML:-} ]] ; then
        if [[ -z ${VCSA_DATACENTER:-} ]]; then
            echo "Error: The VCSA_DATACENTER environment variable must be set" \
                 "to point to a valid VCSA Datacenter"
            exit 1
        fi

        VCSA_DATASTORE=${VCSA_DATASTORE:-nfs0-1}

        if [[ -z ${VCSA_WORKER_DNS:-} ]]; then
            cmd="grep WORKER_DNS /var/lib/node.cfg | cut -d'=' -f2 | sed -e 's/^[[:space:]]*//'"
            output=$(SSHPASS="$WCP_SA_PASSWORD" sshpass -e ssh "${SSHCommonArgs[@]}" \
                        "root@$WCP_SA_IP" "$cmd")
            if [[ -z $output ]]; then
                echo "You did not specify env VCSA_WORKER_DNS and we couldn't fetch it from the SV cluster."
                echo "Run the following on your SV node: $cmd"
                exit 1
            fi
            VCSA_WORKER_DNS=$output
        fi
    fi
}

patchWcpDeploymentYaml() {
    if [[ -f  "artifacts/wcp-deployment.yaml" ]]; then
        sed -i'' "s,<vc_pnid>,$VCSA_IP,g" "artifacts/wcp-deployment.yaml"
        sed -i'' "s,<datacenter>,$VCSA_DATACENTER,g" "artifacts/wcp-deployment.yaml"
        sed -i'' "s, Datastore: .*, Datastore: $VCSA_DATASTORE," "artifacts/wcp-deployment.yaml"
        sed -i'' "s,<worker_dns>,$VCSA_WORKER_DNS," "artifacts/wcp-deployment.yaml"
    fi
}

deploy() {
    local yamlArgs=""

    if [[ -z ${SKIP_YAML:-} ]]; then
        patchWcpDeploymentYaml
        yamlArgs+="--yamlToCopy artifacts/wcp-deployment.yaml,/usr/lib/vmware-wcp/objects/PodVM-GuestCluster/30-vmop/vmop.yaml"
    fi

    # shellcheck disable=SC2086
    PATH="/usr/local/opt/gnu-getopt/bin:/usr/local/bin:$PATH" \
      $WCP_LOAD_K8S_MASTER \
        --component vmop \
        --binary bin/wcp/manager \
        --vc-ip "$VCSA_IP" \
        --vc-user root \
        --vc-password $VCSA_PASSWORD \
        $yamlArgs
}

verifyEnvironmentVariables
deploy

# vim: tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=sh