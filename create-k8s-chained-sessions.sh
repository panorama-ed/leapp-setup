#!/usr/bin/env bash
# Usage
# This script takes no arguments.
# Execute this script after doing your initial setup to automatically generate
# the sessions necessary for working with kubectl.
# Do not run this script more than once without resetting your Leapp
# instance beforehand.

# global variables
declare K8S_PROFILE_ID
declare CHAINED_PROFILE_IDS="name,id\n"
declare REGION='us-east-1'

###### FUNCTIONS ######
#
# function to create a chained leapp session given a parent session id
# Args:
# 1: parent session id name from leapp
# appends new session id from the new chained session to CHAINED_PROFILE_IDS
function createLeappSession() {
    parent_session_name=$1
    chained_session_name="chained-from-${parent_session_name}"
    echo "starting session for ${parent_session_name} to get role arn"
    # this has funky piping because `--filter` is a fuzzy lookup and `panorama-k8s-playground` fuzzy matches `panorama-k8s-playground-2` as the first result
    parent_session_id=$(leapp session list -x --filter="Session Name=${parent_session_name}" --no-header | sort -k1 -r | sed -n 1p | awk '{print $1}')
    # start leapp session
    leapp session start --sessionId $parent_session_id
    # call to aws to get the role arn for `TerraformRole`
    role_arn=$(aws iam get-role --role-name TerraformRole --query Role.Arn | tr -d '"')
    # stop the leapp session
    leapp session stop --sessionId $parent_session_id

    echo "creating new session"
    # create new chained leapp session from parent
    leapp session add --providerType aws --sessionType awsIamRoleChained \
        --sessionName $chained_session_name --region $REGION \
        --roleArn $role_arn --parentSessionId $parent_session_id \
        --profileId $K8S_PROFILE_ID
    # add session id from the new session to CHAINED_PROFILE_IDS
    chained_session_id=$(leapp session list --columns=ID --filter="Session Name=${chained_session_name}" --no-header)
    CHAINED_PROFILE_IDS="${CHAINED_PROFILE_IDS}${chained_session_name},${chained_session_id}\n"
}

# function to create a leapp profile to associate with the chained k8s sessions
# stores the new profile id in K8S_PROFILE_ID
function createLeappProfile() {
    leapp profile create --profileName kubectl-access-role
    K8S_PROFILE_ID=$(leapp profile list --columns=ID --filter="Profile Name=kubectl-access-role" --no-header)
}
#
###### END FUNCTIONS ######

echo "Creating Leapp Profile for use with chained k8s sessions"
createLeappProfile
echo "new profile id: ${K8S_PROFILE_ID}"

echo "Creating Leapp Chained k8s sessions for k8s accounts"
# session names from Leapp for each k8s account
PARENT_SESSION_NAMES="panorama-k8s-playground panorama-k8s-playground-2 panorama-k8-integration panorama-k8s-staging panorama-k8s-production"

for session in $PARENT_SESSION_NAMES
do
    createLeappSession $session
done

echo "all sessions created. store IDs for future use:"
echo -e $CHAINED_PROFILE_IDS
