#!/usr/bin/env bash
# Usage
# This script takes no arguments.
# Execute this script after doing your initial setup to automatically generate
# the sessions necessary for working with kubectl.

. ./utils.sh

# global variables
declare REGION='us-east-1'

###### FUNCTIONS ######
#
# function to create a chained leapp session given a parent session id
# Args:
# 1: name of environment ("playground", "staging", etc.)
# 2: name of service ("k8s" or "DBs", reflecting naming of parent Leapp sessions)
# 3: sso role name to use for the parent session
# 4: scope of the IAM role ("panorama" or "eks" or "rds").
# 5: name of the persona (e.g. admin, dev-writer, etc.) the new session is for
function createLeappSession {
    green_echo "creating chained session for $1 with persona $5"
    environment_name=$1
    service_name=$2
    parent_session_name="panorama-${service_name}-${environment_name}"
    parent_role_name=$3
    iam_role_scope=$4
    persona_name=$5
    # check if the parent session exists for the role. We do this because
    # not all users have access to all roles. We want to only create sessions
    # for roles that people have access to.
    parent_session_id=$(leappSessionId "$parent_session_name" "$parent_role_name")
    if [[ -z "${parent_session_id}" ]]; then
        green_echo "    No parent session found for ${parent_session_name} with role ${parent_role_name}"
        return
    fi

    chained_session_name="${service_name}-${environment_name}-${persona_name}"

    green_echo "    looking for existing session ${chained_session_name}"
    iam_role_name="${iam_role_scope}-${persona_name}"
    chained_session_id=$(leappSessionId "$chained_session_name" "$iam_role_name")

    if [[ -z "${chained_session_id}" ]]; then
        green_echo "    no existing session found; starting session for ${parent_session_name} to get role arn"

        # use the parent session to get the role arn
        # so we don't have to hard-code account ids
        leapp session start --sessionId "$parent_session_id" > /dev/null 2> >(logStdErr)
        role_arn=$(aws iam get-role --role-name $iam_role_name --query Role.Arn | tr -d '"')
        leapp session stop --sessionId "$parent_session_id" > /dev/null 2> >(logStdErr)

        green_echo "    creating new profile"
        profile_id=$(createLeappProfile "${chained_session_name}")

        green_echo "    creating new session"
        leapp session add --providerType aws --sessionType awsIamRoleChained \
            --sessionName "$chained_session_name" --region "$REGION" \
            --roleArn "$role_arn" --parentSessionId "$parent_session_id" \
            --profileId "$profile_id" > /dev/null 2> >(logStdErr)

    else
        yellow_echo "    existing session found"
    fi
}

#
# function to delete an existing chained leapp session
# Args:
# 1: name of environment ("playground", "staging", etc.)
# 2: name of service ("k8s" or "DBs", reflecting naming of parent Leapp sessions)
# 3: sso role name to use for the parent session
# 4: name of the persona (e.g. admin, dev-writer, etc.) the new session is for
function deleteLeappSession {
  environment_name=$1
  service_name=$2
  iam_role_scope=$3
  persona_name=$4
  iam_role_name="${iam_role_scope}-${persona_name}"

  session_name="${service_name}-${environment_name}-${persona_name}"
  session_id=$(leappSessionId "$session_name" "$iam_role_name")

  if [[ -n "${session_id}" ]]; then
    green_echo "deleting session ${session_name}"

    leapp session delete --sessionId "$session_id" > /dev/null 2> >(logStdErr)
  fi
}

# @return the Leapp session ID of the session whose name is the first argument
#   to this function, if one exists.
function leappSessionId {
    # The ^ and $ in the session filter are regex anchors to ensure we don't
    # match e.g. both `chained-from-panorama-k8s-playground` and
    # `chained-from-panorama-k8s-playground-2`.
    leapp session list -x --filter="Session Name=^${1}$" --output json | jq -r ".[] | select(.role==\"${2}\") | .id"
}

# function to create a leapp profile to associate with the chained k8s or DBs sessions
# stores the new profile id in PROFILE_ID
function createLeappProfile {
    # The ^ and $ in the session filter are regex anchors to ensure we are
    # finding an exact match. Otherwise, we risk accidentially matching multiple
    # Leapp profiles and using the wrong one.
    profile_name="${1}-access"
    profile_id=$(leapp profile list -x --output json --filter="Profile Name=^${profile_name}$" | jq -r '.[].id')
    if [[ -n "${profile_id}" ]]; then
        echo "${profile_id}"
        return
    fi
    leapp profile create --profileName "$profile_name" > /dev/null 2> >(logStdErr)
    leapp profile list -x --output json --filter="Profile Name=^${profile_name}$" | jq -r '.[].id'
}
#
###### END FUNCTIONS ######

# session names from Leapp for each k8s or DBs account
ENV_NAMES="playground playground-2 staging sandbox production"

for env in $ENV_NAMES
do
    createLeappSession "$env" "k8s" "AWSAdministratorAccess" "eks" "admin"
    createLeappSession "$env" "k8s" "PanoramaK8sEngineeringDefault" "panorama" "dev-writer"
    createLeappSession "$env" "k8s" "PanoramaK8sEngineeringDefault" "panorama" "dev-reader"
    createLeappSession "$env" "k8s" "PanoramaK8sDSAR" "panorama" "data-science-tester"

    createLeappSession "$env" "DBs" "AWSAdministratorAccess" "rds" "admin"

    if [[ "$env" == "production" ]]; then
      # This session may have been previously created with the
      #  "PanoramaDBsEngineeringDefault" role.
      # We delete any existing session to make sure we are creating one with the correct role.
      deleteLeappSession "$env" "DBs" "panorama" "dev-writer"
      createLeappSession "$env" "DBs" "PanoramaDBsProdAccess" "panorama" "dev-writer"

      # This session may have been previously created with the
      #  "PanoramaDBsEngineeringDefault" role.
      # We delete any existing session to make sure we are creating one with the correct role.
      deleteLeappSession "$env" "DBs" "panorama" "dev-reader"
      createLeappSession "$env" "DBs" "PanoramaDBsProdAccess" "panorama" "dev-reader"
    else
      createLeappSession "$env" "DBs" "PanoramaDBsEngineeringDefault" "panorama" "dev-writer"
      createLeappSession "$env" "DBs" "PanoramaDBsEngineeringDefault" "panorama" "dev-reader"
    fi
done
