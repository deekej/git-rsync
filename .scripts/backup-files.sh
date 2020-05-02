#!/bin/bash

# Backing up the system files requires elevated privileges:
if [[ ${EUID} != 0 ]]; then
  echo "$(basename "${0}"): ERROR: elevated privileges are required"
  exit 1
fi

# Source the default/user configuration:
source .scripts/config

# Make a cleanup before re-syncing the necessary files:
rm -rf "$(grep -E -v '^#.*' "${FOLDERS_TO_CLEAN}")"

# Sync the specified files into this repository:
rsync ${RSYNC_OPTIONS} \
      --files-from="${FILES_SYNC}" \
      --exclude='^[[:space:]]#.*$' \
      / ./.                           # Source : Destination

# Update the git tracked files of this repository:
git add --all --force .

# Make a metadata backup of files that are in current git repository:
$store_metadata ${META_OPTIONS} \
                --store \
                --target "${FILES_META}"

# Restore ownership of files/folders for easier management via git:
chown -R "${USER}:${USER}" ./*
chown -R "${USER}:${USER}" .git/
chown -R "${USER}:${USER}" "${FILES_SYNC}" "${FILES_META}" "${FOLDERS_TO_CLEAN}"

# Make sure all the folders in this repository have '0755' permissions so they
# can be correctly read and traversed...

find ${PWD} -type d -not -perm 0755 -exec chmod 0755 {} +
