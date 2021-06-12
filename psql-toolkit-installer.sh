#! /bin/sh
#
# psql-toolkit-installer.sh
# Copyright (C) 2021 Jesus R. Sanchez <jesus@neotec.do>
#
# Distributed under terms of the BSD license.
#

splash() {
    echo "                #                                            # #    #"
    echo "                #   ####   ####     #      #####             # #    #"
    echo "                #    #  #   #  #   ###     # # #             # #      #"
    echo "####   ##   ### #    #   #  # #    # #       #    ###   ###  # #  # # ##"
    echo "#   # # # ##  # #    #   #  ###   #  #       #   #   # #   # # # #  # #"
    echo "#   #  #  #   # #    #   #  #  #  #####      #   #   # #   # # ###  # #"
    echo "#  ## # # #   # #    #  #   #  #  #   #      #   #   # #   # # #  # # #"
    echo "###   ##   #### #   ####   ####  ##   ##    ###   ###   ###  # ## # # ##"
    echo "#             #"
    echo "##           ##"
    return 0
}

install_process() {
    mkdir -p ${HOME}/.config/psql
    cp -frv .config/psql/* ${HOME}/.config/psql
    cp -frv .psqlrc ${HOME}/
    return $?
}


splash

if [ ! -d ${HOME}/.config/psql ];
then
    read -n 1 -s -r -p "Press any key to continue the install process..."
    install_process
    RETVAL=$?
else
    echo "psql DBA Toolkit already installed..."
    echo "creating backup to reinstall"
    mv -fv ${HOME}/.config/psql ${HOME}/.config/psql_backup
    mv -fv ${HOME}/.psqlrc ${HOME}/.psqlrc_backup

    read -n 1 -s -r -p "Press any key to continue the install process..."
    install_process
    RETVAL=$?
fi

echo "Install finished"

exit ${RETVAL}


