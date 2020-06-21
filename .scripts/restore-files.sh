#!/bin/bash

PROG="$(basename ${0})"

# -----------------------------------------------------------------------------

function sysf_backup()
{
  if [[ ${FILES_TYPE} == system ]]; then
    if grep -q -e '/etc/fstab' -e '/etc/default/grub' "${FILES_SYNC}"; then
      # Make a backup of fstab & grub configs, which are often causing troubles
      # booting up when incorrectly restored:
      cp -a /etc/fstab        /etc/fstab.init
      cp -a /etc/default/grub /etc/default/grub.init
    fi
  fi
}

function sysf_restore()
{
  if [[ ${FILES_TYPE} == system ]]; then
    if [[ -e /etc/fstab.init || -e /etc/default/grub.init ]]; then
      # Restore the initial fstab & grub config:
      mv /etc/fstab        /etc/fstab.rpmnew
      mv /etc/default/grub /etc/default/grub.rpmnew

      mv /etc/fstab.init        /etc/fstab
      mv /etc/default/grub.init /etc/default/grub

      echo "${PROG}: INFO: Manual merging of these files is required:"
      echo "${PROG}:        - /etc/fstab.rpmnew"
      echo "${PROG}:        - /etc/default/grub.rpmnew"
    fi

    echo "${PROG}: INFO: Restoring SELinux context of all restored files to default"
    echo "${PROG}:       ... This may take a while. Do NOT interrupt!"

    grep -q -v -e '^#.*' "${FILES_SYNC}" > .restorecon.files

    restorecon -p -i -R -f .restorecon.files

    rm -f .restorecon.files
  fi
}

# -----------------------------------------------------------------------------

# Source the default/user configuration:
source .scripts/config

if [[ ${FILES_TYPE} == system ]]; then
  # Restoring the system files requires elevated privileges:
  if [[ ${EUID} != 0 ]]; then
    echo "$(basename "${0}"): ERROR: elevated privileges are required"
    exit 1
  fi

  # Some of the configuration may be hostname specific and break the system,
  # if no hostname is set. Force the use to set the hostname:
  if [[ "$(uname -n)" == localhost* ]]; then
    echo "$(basename "${0}"): ERROR: hostname must be set"
    exit 1
  fi
fi

sysf_backup                           # Backup system files if necessary.

# Restore all files metadata (except SELLinux context):
$metadata ${META_OPTIONS} \
          --target "${FILES_META}" \
          --apply

# Sync the backed up files into this corresponding paths:
rsync ${RSYNC_OPTIONS} \
      --exclude='^[[:space:]]#.*$' \
      --files-from="${FILES_SYNC}" \
      "${PWD}" /                      # Source : Destination

sysf_restore                          # Restore system files & SELinux context.

# Restore ownership of files/folders for easier management via git:
chown -R "${USERNAME}:${USERNAME}" ./*
chown -R "${USERNAME}:${USERNAME}" .git/
chown -R "${USERNAME}:${USERNAME}" "${RSYNC_DEST}"
chown -R "${USERNAME}:${USERNAME}" "${FILES_SYNC}" "${FILES_META}" "${FILES_CLEAN}"

# Make sure all the folders in this repository have '0755' permissions so they
# can be correctly read and traversed...

find ${PWD} -type d -not -perm 0755 -exec chmod 0755 {} +
