#!/bin/bash
###############################################################################
# Script Clerk
#
# Manager for automatically starting multiple applications in development
# environments. Allows for automatic patching of development configurations
# before building or running.
#
# Create the CONFIG_DIRECTORY and place scripts with extensions '.sh' to 
# call your applications.
#
# Patches need to be stagged with git and are associated with a script of the
# same name. Script Clerk requires a functional git repo in its working 
# directory, as it uses git to create, check and apply patches.
#
# Author: John Shield
# Date: 2018
# Repo: https://github.com/JohnShield/scriptclerk
# License: BSD-3-New 
# (Free to use or modify for any purpose; Keep the git repo link; Don't sue me)
###############################################################################

CONFIG_DIRECTORY="scriptclerk"

BUILD="echo TO BUILD A PROJECT, CHANGE THIS BUILD DEFINITION AT THE START OF THE FILE: $0"
STARTUP_SCRIPT=""

# If TERMINAL_TAB_TITLE defined will run:
#   TERMINAL_PROGRAM TERMINAL_TAB_TITLE <script name> TERMINAL_RUN_ARGS <script>
# Otherwise it will run: 
#   TERMINAL_PROGRAM TERMINAL_RUN_ARGS <script>

TERMINAL_PROGRAM="gnome-terminal"
TERMINAL_TAB_TITLE="--tab -t"
TERMINAL_RUN_ARGS="-- /bin/bash -c"

# Ordering argument for patches and scripts retrieved by "ls"
FILE_SORT="-t"

WORKING_DIR=`pwd`

####################################################################
# Internal Global Variable Setup
####################################################################

CONFIG_FILE="config"
APP_ENABLE="app_enable"
PATCH_ENABLE="patch_enable"

MENU_SIZE="23 78 16"
MSGBOX_SIZE="8 78"

# PID of current process appended on startup
SCRIPT_TAG="SCRIPT_CLERK_IDENTIFIER"

# patches need to know where they're applied from
cd $WORKING_DIR
PATCH_ROOT=`git rev-parse --show-toplevel 2> /dev/null`
if [ -z $PATCH_ROOT ]; then
    PATCH_ROOT=$WORKING_DIR
fi

PATCH_CMD="patch -d $PATCH_ROOT -N -p1"

# used to record applications that had patches applied
global_patches_applied_list=""
####################################################################
# Menu Choices
####################################################################

main_menu() {
    zombie_apps=`check_for_applications $SCRIPT_TAG`

    if [ -z "$zombie_apps" ]; then
        var_select=$(whiptail --title "Application Management" --menu "Choose an Option" $MENU_SIZE \
        "[Auto-start]" "Run Auto-start Applications" \
        "[Build]" "Run the configured build comand" \
        "[Select]" "Select Auto-start Applications" \
        "[Patches]" "Manage application patches" \
        "[Config]" "Configuration Options" \
        "[Exit]" "Exit Program" 3>&2 2>&1 1>&3)
    else
        var_select=$(whiptail --title "Application Management" --menu "Choose an Option" $MENU_SIZE \
        "[Auto-start]" "Run Auto-start Applications" \
        "[ClearZombies]" "Previous applications running detected. Clear them?"\
        "[Build]" "Run the configured build comand" \
        "[Select]" "Select Auto-start Applications" \
        "[Patches]" "Manage application patches" \
        "[Config]" "Configuration Options" \
        "[Exit]" "Exit Program" 3>&2 2>&1 1>&3)
    fi

    case "$var_select" in
        \[Auto-start\])
            start_applications
            1_menu_auto_start
            main_menu
            ;;
        \[ClearZombies\])
            close_applications $SCRIPT_TAG
            main_menu
            ;;
        \[Build\])
            run_build
            main_menu
            ;;
        \[Select\])
            2_menu_select
            main_menu
            ;;
        \[Patches\])
            3_menu_patches
            main_menu
            ;;
        \[Config\])
            4_menu_config
            main_menu
            ;;
        *)
            exit 1
    esac
}

1_menu_auto_start() {
    app_list=`generate_app_list`

    var_select=$(whiptail --title "Start and Stop Applications" --menu "Start/Stop Applications" $MENU_SIZE \
    "[<<<Close]" "Quit all applications and return to main menu" \
    "[Refresh]"  "Refresh of list of applications" \
    ${app_list} 3>&2 2>&1 1>&3)

    case "$var_select" in
        \[\<\<\<Close\])
            uninstall_temporary_patches
            close_applications $SCRIPT_IDENTIFIER
            ;;
        "")
            uninstall_temporary_patches
            close_applications $SCRIPT_IDENTIFIER
            ;;
        \[Refresh\])
            1_menu_auto_start
            ;;
        *)
            toggle_application_run $var_select
            1_menu_auto_start
    esac
}

2_menu_select() {
    check_menu_list=`generate_app_list_with_description`

    var_select=$(whiptail --title "Select Auto-start Applications" --checklist "Select Applications" $MENU_SIZE \
    ${check_menu_list} 3>&2 2>&1 1>&3)

    # if not cancelled
    if [ $? == 0 ]; then
        echo -n > $CONFIG_DIRECTORY/$APP_ENABLE
        for ii in $var_select; do
            echo $ii ON >> $CONFIG_DIRECTORY/$APP_ENABLE
        done
    fi
}

3_menu_patches() {
    var_select=$(whiptail --title "Manage Application Patches" --menu "Choose an Option" $MENU_SIZE \
    "[<<<Return]" "Return to Main Menu" \
    "[Toggle]" "Manually install or uninstall a patch" \
    "[Set]" "Set Active Patches" \
    "[Apply]" "Apply the active patches" \
    "[Remove]" "Remove the active patches" \
    "[Apply-All]" "Apply every available patch" \
    "[Remove-All]" "Remove every available patch" \
    "[Generate]" "Generate a new patch for an application" \
    "[Delete]" "Delete patches" \
    3>&2 2>&1 1>&3)

    case "$var_select" in
        \[Toggle\])
            3_1_menu_toggle_patches
            3_menu_patches
            ;;
        \[Set\])
            3_2_menu_select_patches
            3_menu_patches
            ;;
        \[Apply\])
            install_patch_list check_active install
            3_menu_patches
            ;;
        \[Remove\])
            install_patch_list check_active uninstall
            3_menu_patches
            ;;
        \[Apply-All\])
            install_patch_list all install
            3_menu_patches
            ;;
        \[Remove-All\])
            install_patch_list all uninstall
            3_menu_patches
            ;;
        \[Generate\])
            3_3_menu_generate
            3_menu_patches
            ;;
        \[Delete\])
            3_4_menu_delete
            3_menu_patches
            ;;
        *)
    esac
}


3_1_menu_toggle_patches() {
    patch_list=`generate_patch_list_with_status`
    var_select=$(whiptail --title "Manual Install and Uninstall Patches" --menu "Select Patch to Toggle" $MENU_SIZE \
    "[<<<Return]" "Return to previous menu" \
    ${patch_list} 3>&2 2>&1 1>&3)
    case "$var_select" in
        \[\<\<\<Return\])
            ;;
        "")
            ;;
        *)
            toggle_patch $var_select
            3_1_menu_toggle_patches
    esac
}

3_2_menu_select_patches() {
    check_menu_list=`generate_patch_list_with_description`
    var_select=$(whiptail --title "Set Active Patches" --checklist "Select Patches" $MENU_SIZE \
    ${check_menu_list} 3>&2 2>&1 1>&3)
    ret=$?

    echo $? $var_select

    # if not cancelled
    if [ $ret == 0 ]; then
        echo -n > $CONFIG_DIRECTORY/$PATCH_ENABLE
        for ii in $var_select; do
            echo $ii ON >> $CONFIG_DIRECTORY/$PATCH_ENABLE
        done
    fi
}

3_3_menu_generate() {
    staged=`git diff --cached --binary`
    if [ $? != 0 ] || [ -z "$staged" ]; then
        echo ERROR: Git diff failed to provide changes to create a patch.
        if (whiptail --title "Error: Cannot Find Staged Changes Needed to Create a Patch" --yesno \
                             "Attempt Retry?" $MSGBOX_SIZE); then
            3_3_menu_generate
        fi
    else
        app_list=`generate_app_list_menu_generate`
        var_select=$(whiptail --title "Generate a Patch from Staged Changes" --menu \
        "Select an Application to Generate a Patch for" $MENU_SIZE \
        ${app_list} 3>&2 2>&1 1>&3)
        if [ $? == 0 ]; then
            patch_file=${var_select/%sh/patch}
            git diff --cached --binary > $CONFIG_DIRECTORY/$patch_file
        fi
    fi
}

3_4_menu_delete() {
    check_menu_list=`generate_patch_list_for_deletion`
    var_select=$(whiptail --title "Delete Patches" --checklist "Select Patches for Deletion" $MENU_SIZE \
    ${check_menu_list} 3>&2 2>&1 1>&3)
    ret=$?

    # if not cancelled
    if [ $ret == 0 ]; then
        delete_patches $var_select
    fi
}

4_menu_config() {
    auto_patch=`get_setting $CONFIG_FILE "[Auto-patch]"`
    auto_build=`get_setting $CONFIG_FILE "[Auto-build]"`
    auto_start=`get_setting $CONFIG_FILE "[Auto-start]"`

    var_select=$(whiptail --title "Configuration Options" --checklist "Toggle Options" $MENU_SIZE \
    "[Auto-patch]" "Automatically apply patches when running apps " $auto_patch \
    "[Auto-build]" "Automatically run \"BUILD\" before running apps " $auto_build \
    "[Auto-start]" "Enter the \"Start Stop Apps\" window on startup " $auto_start \
    3>&2 2>&1 1>&3)

    # if not cancelled
    if [ $? == 0 ]; then
        echo -n > $CONFIG_DIRECTORY/$CONFIG_FILE
        for ii in $var_select; do
            echo $ii ON >> $CONFIG_DIRECTORY/$CONFIG_FILE
        done
    fi
}

####################################################################
# Script Execution Management
####################################################################

check_for_applications() {
    ps -ef | grep ${1}  | grep \\.sh | awk '{print $2}'
}

close_applications() {
    kill_list=`check_for_applications ${1}`
    if [ ! -z "$kill_list" ]; then
        for apps in $kill_list; do
            kill -- -$apps
        done
    fi
}

start_applications() {
    global_patches_applied_list=""

    if [ ! -z $STARTUP_SCRIPT ]; then
        bash $STARTUP_SCRIPT $CONFIG_DIRECTORY
    fi

    auto_patch_enabled_apps install
    auto_run_build

    apps_to_start=`list_of_enabled_applications`
    echo Launching Applications $apps_to_start
    terminal_start_list $apps_to_start
}


start_scriptclerk() {
    auto_start_setting=`get_setting $CONFIG_FILE "[Auto-start]"`
    if [ $auto_start_setting == "ON" ]; then
        start_applications
        1_menu_auto_start
        main_menu 
    else
        main_menu
    fi
}

auto_run_build() {
    auto_build_setting=`get_setting $CONFIG_FILE "[Auto-build]"`
    if [ $auto_build_setting == "ON" ]; then
        run_build
    fi
}

run_build() {
    $BUILD
    if [ $? != 0 ]; then
        whiptail --title "ERROR" --msgbox "ERROR: Failed build command:\n$BUILD" $MSGBOX_SIZE
        echo "ERROR: Failed build command \"$BUILD\""
        exit 1
    fi
}

list_of_enabled_applications() {
    for ii in `ls $FILE_SORT $CONFIG_DIRECTORY/*.sh`; do
        script_file=${ii/#$CONFIG_DIRECTORY\//}
        active=`get_setting $APP_ENABLE $script_file`
        if [ $active == "ON" ]; then
            echo $script_file
        fi
    done
}

toggle_application_run() {
    PID=`check_app_running ${1}`
    if [ -z $PID ]; then
        auto_install_patch_for ${1}
        echo Starting up ${1}
        run_program ${1}
    else
        echo Shutting down ${1} $PID
        kill -- -$PID
    fi
}

check_app_running() {
    ps -ef | grep $SCRIPT_IDENTIFIER | grep ${1} | head -1 | awk '{print $2}'
}

terminal_start_list() {
    for ii in $@; do
        run_program $ii
    done
}

run_program() {
    if [ -z "$TERMINAL_TAB_TITLE" ]; then
            $TERMINAL_PROGRAM $TERMINAL_RUN_ARGS "${CONFIG_DIRECTORY}/./${1} ${SCRIPT_IDENTIFIER}"
        if [ $? -ne 0 ]; then
           echo ERROR: Terminal program returned error.
           echo ERROR CMD: $TERMINAL_PROGRAM $TERMINAL_RUN_ARGS \"${CONFIG_DIRECTORY}/./${1} ${SCRIPT_IDENTIFIER}\"
           exit 1
        fi
    else
        $TERMINAL_PROGRAM $TERMINAL_TAB_TITLE "${1}" $TERMINAL_RUN_ARGS "${CONFIG_DIRECTORY}/./${1} ${SCRIPT_IDENTIFIER}"
        if [ $? -ne 0 ]; then
            echo ERROR: Terminal program returned error.
            echo ERROR CMD: $TERMINAL_PROGRAM $TERMINAL_TAB_TITLE "${1}" $TERMINAL_RUN_ARGS "${CONFIG_DIRECTORY}/./${1} ${SCRIPT_IDENTIFIER}"
            exit 1
        fi
    fi
}


####################################################################
# Patch management
####################################################################

uninstall_temporary_patches () {
    echo Uninstalling the following patches $global_patches_applied_list
    for ii in $global_patches_applied_list; do
        uninstall_patch $ii
    done
}

toggle_patch() {
    $PATCH_CMD --dry-run < $CONFIG_DIRECTORY/${1} > /dev/null 2>&1
    if [ $? == 0 ]; then
        install_patch ${1}
    else
        $PATCH_CMD -R --dry-run < $CONFIG_DIRECTORY/${1} > /dev/null 2>&1
        if [ $? == 0 ]; then
            uninstall_patch ${1}
        fi
    fi
}

# ARGS: ${1}=check active patches, ${2}=install or uninstall
install_patch_list () {
    echo DEBUGGING install_patch_list ${1} ${2}
    for ii in `ls $FILE_SORT $CONFIG_DIRECTORY/*.patch`; do
        patch_file=${ii/#$CONFIG_DIRECTORY\//}
        if [ ${1} == "all" ] || [ `get_setting $PATCH_ENABLE $patch_file` == "ON" ]; then
            if [ ${2} == "install" ]; then
                install_patch $patch_file
            else
                uninstall_patch $patch_file
            fi
        fi
    done
}

# ARGS: ${1}=install or uninstall
auto_patch_enabled_apps() {
    auto_patch_setting=`get_setting $CONFIG_FILE "[Auto-patch]"`
    if [ $auto_patch_setting == "ON" ]; then
        echo Auto-installing patches for execution run
        # for the enabled scripts find any enabled patches
        for ii in `cat $CONFIG_DIRECTORY/$APP_ENABLE | awk '{if ($2=="ON") print $1}'`; do
            removed_first_quote=${ii%\"}
            script_file=${removed_first_quote#\"}
            patch_file=${script_file/%sh/patch}

            check_setting=`get_setting $PATCH_ENABLE $patch_file`
            if [ $check_setting == "ON" ]; then
                 if [ ${1} == "install" ]; then
                    install_patch $patch_file
                 else
                    uninstall_patch $patch_file
                 fi
            fi
        done
    fi
}

check_patch_status() {
    $PATCH_CMD --dry-run < $CONFIG_DIRECTORY/${1} > /dev/null 2>&1
    if [ $? == 0 ]; then
        echo NOT_INSTALLED
    else
        $PATCH_CMD -R --dry-run < $CONFIG_DIRECTORY/${1} > /dev/null 2>&1
        if [ $? == 0 ]; then
            echo INSTALLED
        else
            echo ERROR
        fi
    fi
}

auto_install_patch_for() {
    auto_patch_setting=`get_setting $CONFIG_FILE "[Auto-patch]"`
    if [ $auto_patch_setting == "ON" ]; then
        script_file=${1}
        patch_file=${script_file/%sh/patch}
        if [ -f $CONFIG_DIRECTORY/$patch_file ]; then
            install_patch $patch_file
        fi
    fi
}

install_patch() {
    $PATCH_CMD --dry-run < $CONFIG_DIRECTORY/${1} > /dev/null 2>&1
    if [ $? == 0 ]; then
        $PATCH_CMD < $CONFIG_DIRECTORY/${1} > /dev/null
        echo Installed ${1}
        global_patches_applied_list=$global_patches_applied_list" "${1}
    else
        $PATCH_CMD -R --dry-run < $CONFIG_DIRECTORY/${1} > /dev/null 2>&1
        if [ $? == 0 ]; then
            echo Checked ${1} for install, but was already installed
        else
            echo ERROR: Patch $CONFIG_DIRECTORY/${1} failed install and uninstall test. Manual validity check required.
            exit 1
        fi
    fi
}

uninstall_patch() {
    $PATCH_CMD -R --dry-run < $CONFIG_DIRECTORY/${1} > /dev/null 2>&1
    if [ $? == 0 ]; then
        $PATCH_CMD -R < $CONFIG_DIRECTORY/${1} > /dev/null
        echo Uninstalled ${1}
    else
        $PATCH_CMD --dry-run < $CONFIG_DIRECTORY/${1} > /dev/null 2>&1
        if [ $? == 0 ]; then
            echo Checked ${1} for uninstall, but was already uninstalled
        else
            echo ERROR: Patch $CONFIG_DIRECTORY/${1} failed install and uninstall test. Manual validity check required.
            exit 1
        fi
    fi
}

delete_patches() {
    for ii in $@; do
        removed_first_quote="${ii%\"}"
        patch_file="${removed_first_quote#\"}"

        # remove the patch if applied
        $PATCH_CMD -R --dry-run < $CONFIG_DIRECTORY/$patch_file > /dev/null 2>&1
        if [ $? == 0 ]; then
            echo Removing patch $CONFIG_DIRECTORY/$patch_file
            $PATCH_CMD -R < $CONFIG_DIRECTORY/$patch_file > /dev/null
        fi
        # delete patch
        rm $CONFIG_DIRECTORY/$patch_file
    done
}

####################################################################
# Menu Listing Generators
####################################################################

# create list of "patches" for toggling with "status"
generate_patch_list_with_status() {
    for ii in `ls $FILE_SORT $CONFIG_DIRECTORY/*.patch`; do
        patch_file=${ii/#$CONFIG_DIRECTORY\//}
        echo $patch_file
        check_patch_status $patch_file
    done
}

# create list of "patches" with "application info" and "config state"
generate_patch_list_with_description() {
    for ii in `ls $FILE_SORT $CONFIG_DIRECTORY/*.patch`; do
        patch_file=${ii/#$CONFIG_DIRECTORY\//}
        echo $patch_file
        script_file=${ii/%patch/sh}
        if [ -f $script_file ]; then
            echo Linked:${script_file/#$CONFIG_DIRECTORY\//}
        else
            echo _
        fi
        echo `get_setting $PATCH_ENABLE $patch_file`
    done
}

# create list of "patches" for deletion with "application info" and selection default "off"
generate_patch_list_for_deletion() {
    for ii in `ls $FILE_SORT $CONFIG_DIRECTORY/*.patch`; do
        patch_file=${ii/#$CONFIG_DIRECTORY\//}
        echo $patch_file
        script_file=${ii/%patch/sh}
        if [ -f $script_file ]; then
            echo Linked:${script_file/#$CONFIG_DIRECTORY\//}
        else
            echo _
        fi
        echo OFF
    done
}

# create list of "applications" with "config state"
generate_app_list() {
    for ii in `ls $FILE_SORT $CONFIG_DIRECTORY/*.sh`; do
        script_file=${ii/#$CONFIG_DIRECTORY\//}
        echo $script_file

        PID=`check_app_running $script_file`
        if [ -z $PID ]; then
            echo STOPPED
        else
            echo PID=$PID
        fi
    done
}

# create a list of "applications" with "status info" and "config state"
generate_app_list_with_description() {
    for ii in `ls $FILE_SORT $CONFIG_DIRECTORY/*.sh`; do
        script_file=${ii/#$CONFIG_DIRECTORY\//}
        echo $script_file
        active=`get_setting $APP_ENABLE $script_file`
        if [ $active == "ON" ]; then
            echo "ACTIVE" $active
        else
            echo "DISABLED" $active
        fi
    done
}

# create a list of "applications" with "patch info"
generate_app_list_menu_generate() {
    for ii in `ls $FILE_SORT $CONFIG_DIRECTORY/*.sh`; do
        script_file=${ii/#$CONFIG_DIRECTORY\//}
        echo $script_file
        patch_file=${ii/%sh/patch}
        if [ -f $patch_file ]; then
            echo OVERWRITE_PATCH
        else
            echo NEW_PATCH
        fi
    done
}

####################################################################
# Utility Functions
####################################################################

remove_repeats_in_string() {
    string=$@
    echo -e ${string// /\\n} | sort -u
}

del_setting() {
    if [ -f $CONFIG_DIRECTORY/${1} ]; then
        sed -i "/${2}/d" $CONFIG_DIRECTORY/${1}
    fi
}

get_setting() {
    if [ -f $CONFIG_DIRECTORY/${1} ]; then
        result_val=`grep -F ${2} $CONFIG_DIRECTORY/${1}`
        if [ $? == 0 ]; then
            if [ `echo $result_val | cut -d " " -f 2` == "ON" ]; then
                echo ON
                return
            fi
        fi
    fi
    echo OFF
}

check_directory() {
    if [ ! -d $CONFIG_DIRECTORY ]; then
        echo Please make the $CONFIG_DIRECTORY directory and provide scripts to call the applications.
        exit 1
    fi
}

####################################################################
# Script Startup
####################################################################

# Add the current PID to the identifier
SCRIPT_IDENTIFIER=${SCRIPT_TAG}${$}
# Check and setup directory system
check_directory
# start scriptclerk
start_scriptclerk
