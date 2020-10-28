_copy_keystore

_copy_keystore() {

  # Copy Energi3 keystore file to computer

  # Download ffsend if needed
    # Install ffsend and jq as well.
  if [ ! -x "$( command -v snap )" ] || [ ! -x "$( command -v jq )" ] || [ ! -x "$( command -v column )" ]
  then
    echo "Installing snap, snapd, bsdmainutils"
    ${SUDO} apt-get install -yq snap 2>/dev/null
    ${SUDO} apt-get install -yq snapd 2>/dev/null
    ${SUDO} apt-get install -yq jq bsdmainutils 2>/dev/null
  fi
  if [ ! -x "$( command -v ffsend )" ]
  then
    ${SUDO} snap install ffsend
  fi

  if [ ! -x "$( command -v ffsend )" ]
  then
    FFSEND_URL=$( wget -4qO- -o- https://api.github.com/repos/timvisee/ffsend/releases/latest | jq -r '.assets[].browser_download_url' | grep static | grep linux )
    cd "${ENERGI3_HOME}/bin/"
    wget -4q -o- "${FFSEND_URL}" -O "ffsend"
    chmod 755 "ffsend"
    cd -
  fi
  
  clear
  echo
  echo "Next we will copy the keystore file from your desktop to the VPS."
  echo "To start click on link below:"
  echo
  echo "https://send.firefox.com/"
  echo
  echo "Once upload completes, copy the URL from Firefox and paste below:"
  sleep .3
  echo
  REPLY=''
  while [[ -z "${REPLY}" ]] || [[ "$( echo "${REPLY}" | grep -c 'https://send.firefox.com/download/' )" -eq 0 ]]
  do
    read -p "Paste URL (leave blank and hit ENTER to do it manually): " -r
    if [[ -z "${REPLY}" ]]
    then      
      echo "Please copy the keystore file to ${CONF_DIR}/keystore directory on your own using"
      echo "an sftp software WSFTP or "
      read -p "Press Enter Once Done: " -r
      if [[ ${EUID} = 0 ]]
      then
        chown -R "${USRNAME}":"${USRNAME}" "${CONF_DIR}"
      fi
      chmod 600 "${CONF_DIR}/keystore/UTC*"
    fi
  done

  while :
  do
    TEMP_DIR_NAME=$( mktemp -d -p "${USRHOME}" )
    if [[ -z "${REPLY}" ]]
    then
      read -p "URL (leave blank to skip): " -r
      if [[ -z "${REPLY}" ]]
      then
        break
      fi
    fi

    # Trim white space.
    REPLY=$( echo "${REPLY}" | xargs )
    if [[ -f "${ENERGI3_HOME}/bin/ffsend" ]]
    then
      "${ENERGI3_HOME}/bin/ffsend" download -y --verbose "${REPLY}" -o "${TEMP_DIR_NAME}/"
    else
      ffsend download -y --verbose "${REPLY}" -o "${TEMP_DIR_NAME}/"
    fi

    KEYSTOREFILE=$( find "${TEMP_DIR_NAME}/" -type f )
    BASENAME=$( basename "${KEYSTOREFILE}" )
    ACCTNUM="0x`echo ${BASENAME} | awk -F\-\- '{ print $3 }'`"
    if [[ -z "${KEYSTOREFILE}" ]]
    then
      echo "Download failed; try again."
      REPLY=''
      continue
    fi
    
    if [ -d ${CONF_DIR}/keystore ]
    then
      KEYSTORE_EXIST=`find ${CONF_DIR}/keystore -name ${BASENAME} -print`
    else
      mkdir -p ${CONF_DIR}/keystore
      chmod 700 ${CONF_DIR}/keystore
      if [[ ${EUID} = 0 ]]
      then
        chown -R "${USRNAME}":"${USRNAME}" "${CONF_DIR}"
      fi
      KEYSTORE_EXIST=''
    fi
    
    if [[ ! -z "${KEYSTORE_EXIST}" ]]
    then
      echo "Backing up ${BASENAME} file"
      mkdir -p ${ENERGI3_HOME}/backups
      mv "${CONF_DIR}/keystore/${BASENAME}" "${ENERGI3_HOME}/backups/${BASENAME}.bak"
      if [[ ${EUID} = 0 ]]
      then      
        chown "${USRNAME}":"${USRNAME}" ${ENERGI3_HOME}/backups
      fi
    fi
    
    #
    mv "${KEYSTOREFILE}" "${CONF_DIR}/keystore/${BASENAME}"   
    chmod 600 "${CONF_DIR}/keystore/${BASENAME}"
    if [[ ${EUID} = 0 ]]
    then
      chown "${USRNAME}":"${USRNAME}" "${CONF_DIR}/keystore/${BASENAME}"
    fi
    
    echo "Keystore Account ${ACCTNUM} copied to:"
    echo "${CONF_DIR}/keystore on VPS"
    
    # Remove temp directory
    rm -rf "${TEMP_DIR_NAME}"
    REPLY=''

  done

}
