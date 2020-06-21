#!/bin/bash

# Source the default/user configuration:
source .scripts/config

# Backing up the system files requires elevated privileges:
if [[ ${FILES_TYPE} == system && ${EUID} != 0 ]]; then
  echo "$(basename "${0}"): ERROR: elevated privileges are required"
  exit 1
fi

# Make a cleanup before re-syncing the necessary files:
rm -rf $(grep -E -v -e '^#.*$' -e '^[[:space:]]*$' -e '^.*\.git(/|\*).*$' "${FILES_CLEAN}")

# Sync the specified files into this repository:
rsync ${RSYNC_OPTIONS} \
      --files-from="${FILES_SYNC}" \
      --exclude='^[[:space:]]#.*$' \
      / "${RSYNC_DEST}"               # Source : Destination

# Update the git tracked files of this repository:
git add --all .

# Make a metadata backup of files that are in current git repository:
$metadata ${META_OPTIONS} \
          --target "${FILES_META}" \
          --store

# Also update the newly created metadata file:
git add --force "${FILES_META}"

# Restore ownership of files/folders for easier management via git:
chown -R "${USERNAME}:${USERNAME}" ./*
chown -R "${USERNAME}:${USERNAME}" .git/
chown -R "${USERNAME}:${USERNAME}" "${RSYNC_DEST}"
chown -R "${USERNAME}:${USERNAME}" "${FILES_SYNC}" "${FILES_META}" "${FILES_CLEAN}"

# Make sure all the folders in this repository have '0755' permissions so they
# can be correctly read and traversed...

find ${PWD} -type d -not -perm 0755 -exec chmod 0755 {} +
