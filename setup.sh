#!/bin/bash

# Configuration.

APT_PACKAGES="ncat lsof"
DNF_PACKAGES="nmap-ncat lsof"

# Pretty feedback.

GOTO_COLUMN="\\033[72G"
COLOUR_RED='\033[00;31m'
COLOUR_YELLOW='\033[00;33m'
COLOUR_GREEN='\033[00;32m'
COLOUR_CLEAR='\033[00m'

pass () {
  echo -e "${GOTO_COLUMN}${COLOUR_GREEN}Done${COLOUR_CLEAR}"
}

fail () {
  if [ ! -z ${1:+z} ]
  then
    echo -e "${GOTO_COLUMN}${COLOUR_RED}Failed${COLOUR_CLEAR}"
    echo -e "${COLOUR_RED}Error:${COLOUR_CLEAR} ${1}"
    exit 1
  else
    echo -e "${GOTO_COLUMN}${COLOUR_YELLOW}Failed${COLOUR_CLEAR}"
    return 1
  fi
}

# Locate the base directory of the repository.

SCRIPT_PATH=$(readlink -f $0)
BASE_DIR=$(dirname $SCRIPT_PATH)

# Work out whether to run commands using sudo.

echo -n "Checking sudo access... "
if sudo -n /bin/true 2>/dev/null
then
  pass
else
  fail
  sudo -v
  echo -n "Checking sudo access again... "
  sudo -n /bin/true 2>/dev/null && pass || fail "no sudo access"
fi

# Update bashrc and ssh config if asked.

case ${1} in
  append)

    # Check whether the bash script is being sourced from the .bashrc file.

    if ! grep -q 'source.*\.bashrc_jumphost' ~/.bashrc
    then
      echo -n "Adding section to source .bashrc_jumphost into .bashrc... "
      cat $BASE_DIR/etc/bashrc_section >> ~/.bashrc && pass || fail
    fi

    # Check whether the host wildcard is defined in the ssh config file.
    if ! grep -q '^Host\s*\*' ~/.ssh/config
    then
      echo -n "Adding proxy section to .ssh/config... "
      cat $BASE_DIR/etc/ssh_config_section >> ~/.ssh/config && pass || fail
    fi
esac

# Work out how to install required packages.

source /etc/os-release

echo -n "Getting package manager commands... "
case $ID in
  debian|ubuntu)
    ALL_PACKAGES=$APT_PACKAGES
    PACKAGE_CHECK_CMD='/bin/dpkg-query -W'
    UPDATE_CMD='/bin/apt update -y'
    INSTALL_CMD='/bin/apt install -y'
    ;;
  fedora|rocky)
    ALL_PACKAGES=$DNF_PACKAGES
    PACKAGE_CHECK_CMD='/bin/rpm -q'
    INSTALL_CMD='/sbin/dnf install -y'
    ;;
  *)
    fail "operating system ${ID} not recognised"
    ;;
esac
pass

# Work out what packages need to be installed.

PACKAGES=""
for PACKAGE in $ALL_PACKAGES
do
  if ! $PACKAGE_CHECK_CMD $PACKAGE &>/dev/null
  then
    PACKAGES="${PACKAGES} ${PACKAGE}"
  fi
done

# Install any packages that are missing.

if [ ! -z ${PACKAGES:+z} ]
then
  if [ ! -z ${UPDATE_CMD:+z} ]
  then
    echo -n "Updating package lists... "
    sudo $UPDATE_CMD &>/dev/null && pass || fail
  fi
  if [ ! -z ${INSTALL_CMD:+z} ]
  then
    echo -n "Installing required packages... "
    sudo $INSTALL_CMD $PACKAGES &>/dev/null && pass || fail
  fi
fi

# Create any directories that are needed.

echo -n "Creating directories in ${HOME} ... "
for DIR in $(cd $BASE_DIR; find . -type d -not -path "."  | sed  's#^./##')
do
  case $DIR in

    # Ignore the git directory.

    \.git) ;;
    \.git/*) ;;

    # Ignore the etc directory.

    etc) ;;
    etc/*) ;;


    # Create other directories under the home directory.

    *)
      if [ ! -d "${HOME}/.${DIR}" ]
      then
        mkdir "${HOME}/.${DIR}" &>/dev/null \
         || fail "could not create directory .${DIR} in ${HOME}"
      fi
      ;;
  esac
done
pass

# Copy the files.

echo -n "Copying files into ${HOME} ... "
for ITEM in $(cd $BASE_DIR; find . -type f  | sed  's#^./##')
do
  case $ITEM in

    # Ignore the git files.

    \.git/*) ;;
    \.git*) ;;

    # Ignore the files in the etc directory.

    etc/*) ;;

    # Ignore the README and the setup script.

    README.md) ;;
    setup.sh) ;;

    # Copy everything else.

    *)
      cp $BASE_DIR/$ITEM "$HOME/.${ITEM}" &>/dev/null \
       || fail "could not copy ${ITEM} into ${HOME}" ;;
  esac
done
pass

# Add the current user to the jumphost SSH config.

echo -n "Updating UUN in ~/.ssh/config_jumphost to ${USER}..."
sed -i -e "/UUN/s/UUN/${USER}/g" "${HOME}/.ssh/config_jumphost" &>/dev/null \
 && pass || fail
