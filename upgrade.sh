#!/bin/bash
################
##       TO-DO     ##
################
# Backup Portion to work
# 
# Maybe kick off the upgrade at the end by calling a script? Greg mentioned it.
# Use arguments instead of input


if [[ "$(whoami)" != root ]]; then
  echo "Only user root can run this script."
  exit 1
fi

################
## VARIABLES ##
################
response=${response,,}
failure_message=$(su -c "cvpi status" cvp | grep failed:)
amount_failed=${failure_message: -1}
# Bucket Variables
awsAccess="${AWS_ACCESS_KEY}"
awsSecret="${AWS_SECRET_KEY}"
bucket='cvp-backup-test'
resource="/${bucket}/${file}"
contentType="application/x-compressed-tar"
date=$(date +"%a, %d %b %Y %T %z")
string="GET\n\n${contentType}\n${date}\n${resource}"
signature=$(echo -en "${string}" | openssl sha1 -hmac "$awsSecret" -binary | base64)


################
## FUNCTIONS ##
################
check_cvp_fails() {
  if [[ amount_failed -gt 0 ]]; then
    su -c "cvpi status" cvp
    read -r -p "Are you sure you want to upgrade with failures? (y/n) " response
    if [[ "$response" =~ ^(no|n)$ ]]; then
      echo -e "Exiting CloudVision Portal upgrade script"
      exit 1   
    fi
  fi
}

upgrade_folder() {
  if ! [[ -e /tmp/upgrade ]]; then
    su -c "mkdir /tmp/upgrade" cvp
  else
    read -r -p "Do you want to remove everything in /tmp/upgrade? *You must remove everything from /tmp/upgrade to upgrade* (y/n): " response
    if [[ "$response" =~ ^(no|n)$ ]]; then
      echo -e "Exitting CloudVision Portal upgrade script *You must remove everything from /tmp/upgrade to upgrade*"
      exit 1
    else
      rm -rf /tmp/upgrade/*
    fi
  fi
}
###########
## LOGIC ##
###########

# First checks if anything is failing if failure message grep isn't empty
if [[ -n "$failure_message" ]]; then
  check_cvp_fails
else
  echo -en "CVP is in good health. Continuing..."
fi

# Asks for which version is needed
read -r -p "Enter the version of CloudVision Portal(eg. 2021.1.0): " version
# Based of version given extracts what the release is
# release=${version::2}
filename="cvp-upgrade-${version}.tgz"
file="images/${filename}"
# Looks for the /tmp/upgrade folder and creates or clears it.
upgrade_folder

# Run a backup before upgrading
# echo -e "Running backups first..."
# cvpi backup cvp || echo -en "Couldn't execute cvpi backup cvp" && exit 1
# # shellcheck disable=SC1091
# source /cvpi/tools/backup.sh || echo -en "Couldn't execute ./cvpi/tools/backup.sh backup completely" && exit 1
# echo -e "Backup complete"

# Change to upgrade directory
cd /tmp/upgrade || echo -en "No /tmp/upgrade directory"
# Downloads the version specified
wget -O "${filename}" --header="Host: ${bucket}.s3.amazonaws.com" \
--header="Date: ${date}" \
--header="Content-Type: ${contentType}" \
--header="Authorization: AWS ${awsAccess}:${signature}" \
"https://${bucket}.s3.us-west-2.amazonaws.com/${file}" || echo -en "Failed to get the version ""${version}"" from the s3 bucket" && exit 1

# Confirmation
read -r -p "Ready to upgrade from ${CVP_VERSION} to ${version}? (y/n):" response
if [[ "$response" =~ ^(no|n)$ ]]; then
      echo -e "Exitting CloudVision Portal upgrade script"
      exit 1
elif [[ "$response" =~ ^(yes|y)$ ]]; then
      echo -e "Upgrading to ${version}"
else
      echo -e "Invalid input only *yes | y | no | n* allowed"
      exit 1
fi
# Performs Upgrade
if  [[ -e "cvp-upgrade-*.tgz" ]]; then
  su -c "upgrade" cvpadmin || exit 1 # This doesn't work but you will get into the cvpadmin prompt then you will need to press u or type upgrade
fi
