#!/bin/bash
##########################################################################
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
# Date:   2018
##########################################################################

BUILD="echo EXECUTE THIS FOR THE BUILD (EDIT THIS FOR YOUR CONFIGURATION)"
TERMINAL_PROGRAM="gnome-terminal --tab -- /bin/bash -c"

####################################################################
# Internal Globals
####################################################################

CONFIG_DIRECTORY="scriptclerk"
CONFIG_FILE="config"
APP_ENABLE="app_enable"
PATCH_ENABLE="patch_enable"

MENU_SIZE="22 78 14"
MSGBOX_SIZE="8 78"

#PID of current process appended on startup
SCRIPT_IDENTIFIER="SCRIPT_CLERK_IDENTIFIER"

# used to record applications that had patches applied
global_patches_applied_list=""
####################################################################
# Menu Choices
####################################################################

main_menu() {
    var_select=$(whiptail --title "Application Management" --menu "Choose an Option" $MENU_SIZE \
    "[Auto-start]" "Run Auto-start Applications" \
    "[Select]" "Select Auto-start Applications" \
    "[Patches]" "Manage application patches" \
    "[Config]" "Configuration Options" \
    "[Exit]" "Exit Program" 3>&2 2>&1 1>&3)
    case "$var_select" in
        \[Auto-start\])
            start_applications
            1_menu_auto_start
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
            close_applications
            ;;
        "")
            close_applications
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
    if [ $? != 0 ] || [ -z $staged ]; then
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

    var_select=$(whiptail --title "Configuration Options" --checklist "Toggle Options" $MENU_SIZE \
    "[Auto-patch]" "Automatically apply patches when running apps" $auto_patch \
    "[Auto-build]" "Automatically run \"BUILD\" before running apps" $auto_build \
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

close_applications() {
    uninstall_temporary_patches
    kill_list=`ps -ef | grep $SCRIPT_IDENTIFIER | grep \\.sh | awk '{print $2}'`
    if [ ! -z "$kill_list" ]; then
        kill $kill_list
    fi
}

start_applications() {
    global_patches_applied_list=""
    auto_patch_enabled_apps install
    auto_run_build

    apps_to_start=`list_of_enabled_applications`
    echo Launching Applications $apps_to_start
    terminal_start_list $apps_to_start
}

auto_run_build() {
    auto_build_setting=`get_setting $CONFIG_FILE "[Auto-build]"`
    if [ $auto_build_setting == "ON" ]; then
        $BUILD
        if [ $? != 0 ]; then
            whiptail --title "ERROR" --msgbox "ERROR: Failed build command:\n$BUILD" $MSGBOX_SIZE
            echo "ERROR: Failed build command \"$BUILD\""
            exit 1
        fi
    fi
}

list_of_enabled_applications() {
    for ii in `ls $CONFIG_DIRECTORY/*.sh`; do
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
        $TERMINAL_PROGRAM "${CONFIG_DIRECTORY}/./${1} ${SCRIPT_IDENTIFIER}"
    else
        echo Shutting down ${1} $PID
        kill $PID
    fi
}

check_app_running() {
    ps -ef | grep $SCRIPT_IDENTIFIER | grep ${1} | head -1 | awk '{print $2}'
}

terminal_start_list() {
    for ii in $@; do
        $TERMINAL_PROGRAM "${CONFIG_DIRECTORY}/./${ii} ${SCRIPT_IDENTIFIER}"
    done
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
    git apply --check $CONFIG_DIRECTORY/${1} 2>/dev/null
    if [ $? == 0 ]; then
        install_patch ${1}
    else
        git apply -R --check $CONFIG_DIRECTORY/${1} 2>/dev/null
        if [ $? == 0 ]; then
            uninstall_patch ${1}
        fi
    fi
}

# ARGS: ${1}=check active patches, ${2}=install or uninstall
install_patch_list () {
    echo DEBUGGING install_patch_list ${1} ${2}
    for ii in `ls $CONFIG_DIRECTORY/*.patch`; do
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
    git apply --check $CONFIG_DIRECTORY/${1} 2>/dev/null
    if [ $? == 0 ]; then
        echo NOT_INSTALLED
    else
        git apply -R --check $CONFIG_DIRECTORY/${1} 2>/dev/null
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
    git apply --check $CONFIG_DIRECTORY/${1} 2>/dev/null
    if [ $? == 0 ]; then
        git apply $CONFIG_DIRECTORY/${1}
        echo Installed ${1}
        global_patches_applied_list=$global_patches_applied_list" "${1}
    else
        git apply -R --check $CONFIG_DIRECTORY/${1} 2>/dev/null
        if [ $? == 0 ]; then
            echo Checked ${1} for install, but was already installed
        else
            echo ERROR: Patch $CONFIG_DIRECTORY/${1} failed install and uninstall test. Manual validity check required.
            exit 1
        fi
    fi
}

uninstall_patch() {
    git apply -R --check $CONFIG_DIRECTORY/${1} 2>/dev/null
    if [ $? == 0 ]; then
        git apply -R $CONFIG_DIRECTORY/${1}
        echo Uninstalled ${1}
    else
        git apply --check $CONFIG_DIRECTORY/${1} 2>/dev/null
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
        # remove the patch if applied
        git apply -R --check $CONFIG_DIRECTORY/$ii 2>/dev/null
        if [ $? == 0 ]; then
            echo Removing patch $CONFIG_DIRECTORY/$ii
            git apply -R $CONFIG_DIRECTORY/$ii
        fi
        # delete patch
        removed_first_quote="${ii%\"}"
        removed_quotes="${removed_first_quote#\"}"
        rm $CONFIG_DIRECTORY/$removed_quotes
    done
}

####################################################################
# Menu Listing Generators
####################################################################

# create list of "patches" for toggling with "status"
generate_patch_list_with_status() {
    for ii in `ls $CONFIG_DIRECTORY/*.patch`; do
        patch_file=${ii/#$CONFIG_DIRECTORY\//}
        echo $patch_file
        check_patch_status $patch_file
    done
}

# create list of "patches" with "application info" and "config state"
generate_patch_list_with_description() {
    for ii in `ls $CONFIG_DIRECTORY/*.patch`; do
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
    for ii in `ls $CONFIG_DIRECTORY/*.patch`; do
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
    for ii in `ls $CONFIG_DIRECTORY/*.sh`; do
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
    for ii in `ls $CONFIG_DIRECTORY/*.sh`; do
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
    for ii in `ls $CONFIG_DIRECTORY/*.sh`; do
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
SCRIPT_IDENTIFIER=${SCRIPT_IDENTIFIER}${$}
# Check and setup directory system
check_directory
# call the main menu
main_menu
