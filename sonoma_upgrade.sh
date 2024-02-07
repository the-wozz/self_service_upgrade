#!/bin/bash

# What it do: S.U.P.E.R.M.A.N 4 [Jamf Pro] Self Service 'standalone' update check add-on with progressive windows and messages prior to being prompted with S.U.P.E.R.M.A.N.
# built-in failsafes and System Preferences fallback 
# Author: Zachary 'Woz'nicki
# Last updated: 1/22/24

############################## Assets Required ############################
# Jamf Pro 10.x
# macOS 11 [Big Sur] - macOS 14 [Sonoma], macOS 10 [Catalina] will only open System Preferences!
# S.U.P.E.R.M.A.N [4] https://github.com/Macjutsu/super (not tested with other versions!)
# SwiftDialog v2.3.2 [min] https://github.com/swiftDialog/swiftDialog
# Icon image for Swift Dialog [OPTIONAL]
############################################################################

# Adjustable Variables #
# Swift Dialog Jamf Pro Policy
swiftPolicy=""
# Swift Dialog icon location
swiftIcon=""
# Swift Dialog icon Jamf Pro Policy
iconPolicy=""
# S.U.P.E.R.M.A.N Jamf Pro Policy
superPolicy=""
# IBM Notifier Jamf Pro Policy
ibmNotifierPolicy=""
# Fallback Method allows the script to open System Preferences/Settings if device does not have a Managed S.U.P.E.R.M.A.N plist
fallbackMethod=1
# Deployed S.U.P.E.R.M.A.N version in environment
deployedSuperVersion="4.0.2"

# Static'ish' Variables
# Swift Dialog binary
swiftDialogBin="/usr/local/bin/dialog"
# Swift Dialog Command File
commandFile="/var/tmp/dialog.log"
# S.U.P.E.R.M.A.N file
superBin="/Library/Management/super/super"
# S.U.P.E.R.M.A.N version
superVersion=$(defaults read /Library/Management/super/com.macjutsu.super.plist SuperVersion)
# S.U.P.E.R.M.A.N log file
superLog="/Library/Management/super/logs/super.log"
# S.U.P.E.R.M.A.N plist
#realSuperPlist="/Library/Management/super/com.macjutsu.super.plist"
# MANAGED (Jamf) S.U.P.E.R.M.A.N plist
superPlist="/Library/Managed Preferences/com.macjutsu.super.plist"
# macOS version
osVersion=$(sw_vers -productVersion)
osVersionSimple=$(sw_vers -productVersion | cut -d'.' -f1)

# End Variables #
## Start Functions ##

iconCheck() {
	echo "* SWIFT DIALOG ICON CHECK *"
        if [[ ! -f "$swiftIcon" ]]; then
            echo "*** WARNING: Icon image set but icon NOT found at location. ***"
                if [[ -z "$iconPolicy" ]]; then
                    echo "* WARNING: No icon policy set! Using default 'Swift Dialog' System Preferences/Settings icon. *"
                elif [[ -n "$iconPolicy" ]]; then
                    echo "Calling Jamf Pro Policy: $iconPolicy"
                    jamf policy -event "$iconPolicy"
                fi
        elif [[ -f "$swiftIcon" ]]; then
            echo "* CHECK PASSED: Icon found. Continuing... *"
        elif [[ -z "$swiftIcon" ]]; then
            echo "* INFO: No Swift Dialog icon set. Bypassing 'iconPolicy' variable. Using default 'Swift Dialog' System Preferences/Settings icon. *"
        fi
}

swiftDialogCheck() {
    echo "* SWIFT DIALOG CHECK *"
        if [[ ! -e "$swiftDialogBin" ]]; then
            echo "Swift Dialog NOT FOUND! Unable to prompt user."
                if [[ -z "$swiftPolicy" ]]; then
                    echo "* WARNING: Swift Dialog Jamf Pro Policy NOT set! *"
                    echo "* Unable to prompt user because of Swift Dialog download failure *"
                    exit 1
                elif [[ -n "$swiftPolicy" ]]; then
                    echo  "Calling Swift Dialog policy"
                    jamf policy -event "$swiftPolicy"
                fi
        else
            echo "CHECK PASSED: Swift Dialog found. Continuing..."
            swiftVersion=$("$swiftDialogBin" --version | cut -c1-5)
            echo "Swift Dialog version: $swiftVersion"
                if [[ "$swiftVersion" < "2.3.2" ]]; then
                    echo "Swift Dialog version too old! 2.3.2 minimum required for proper messaging."
                        if [[ -n "$swiftPolicy" ]]; then
                            echo  "Calling Swift Dialog policy"
                            jamf policy -event "$swiftPolicy"
                        elif [[ -z "$swiftPolicy" ]]; then
                            echo "* WARNING: Swift Dialog Jamf Pro Policy NOT set! *"
                            echo "*** ERROR: Unable to prompt user because of Swift Dialog failure above ***"
                            exit 1
                        fi
                else
                    echo "* Swift Dialog version PASSED *"
                fi
        fi
}

deleteIBMNotifier() {
    echo "1 Time Run: Delete IBM Notifier and reinstall if found..."
    if [[ -e "/Library/Management/super/IBM Notifier.app" ]]; then
        echo "IBM Notifier found. Deleting..."
        rm -rf "/Library/Management/super/IBM Notifier.app" & sleep 2
    else
        echo "IBM Notifier not found, continuing..."
    fi
}

ibmNotifierCheck(){
    echo "* IBM NOTIFIER CHECK *"
    ibmNotifier_Bin="/Library/Management/super/IBM Notifier.app/Contents/MacOS/IBM Notifier"
    ibmNotifier="/Library/Management/super/IBM Notifier.app"
    if [[ -e "$ibmNotifier" ]]; then
        ibmNotifierVersion=$("$ibmNotifier_Bin" --version | awk '{print $4}')
        echo "IBM Notifier version: $ibmNotifierVersion"
            if [[ "$ibmNotifierVersion" < "3.0.2" ]]; then
                echo "** CHECK FAILED: IBM Notifier version too old! **"
                    if [[ -n "$ibmNotifierPolicy" ]]; then
                        echo "Calling Jamf Pro Policy: $ibmNotifierPolicy"
                        jamf policy -event "$ibmNotifierPolicy"
                    elif [[ "$ibmNotifierPolicy" == "X" ]]; then
                        echo "Passing IBM Notifier download to S.U.P.E.R.M.A.N / GitHub"
                    elif [[ -z "$ibmNotifierPolicy" ]]; then
                        echo "ERROR: No IBM Notifier Policy set! Exiting..."
                        exit 1
                    fi
            elif [[ "$ibmNotifierVersion" > "3.0.1" ]]; then
                echo "* CHECK PASSED: IBM Notifier version 3.0.2 or greater! *"
            fi
    elif [[ ! -e "$ibmNotifier" ]] && [[ -n "$ibmNotifierPolicy" ]]; then
        echo "IBM Notifier does not exist! Calling Jamf Pro Policy: $ibmNotifierPolicy"
        ibmNotifierPolicy
    elif [[ ! -e "$ibmNotifier" ]] && [[ -z "$ibmNotifierPolicy" ]]; then
        echo "* CHECK FAILED: IBM Notifier not found! *"
        echo "* ERROR: No IBM Notifier Policy set! Exiting... *"
        exit 1
    fi
}

ibmNotifierPolicy () {
    jamf policy -event "$ibmNotifierPolicy"
    wait
    ibmNotifierCheck
}

ssWindow() {
    "$swiftDialogBin" -o -p --progress --progresstext "Searching for compatible required updates..." \
    --button1text none --centericon -i "$swiftIcon" -iconsize 80 \
    --title "Checking for macOS Updates" --titlefont size="17" \
    --message "macOS version: $osVersion" --messagefont size="11" --messagealignment center \
    --position bottomright --width 400 --height 220 & sleep 0.1
        # Exit button handling when enabled --button2enabled
        # case $? in
        #     2)
        #         echo "User pressed Exit button"
        #         exit 2
        #     ;;
        # esac
}

updatesAvailable_Win() {
    "$swiftDialogBin" -o -p --progress --hideicon --button1text none \
    --title "Available Updates:" --titlefont size="18" \
    --message "" --messagefont size="15" \
    --position bottomright --width 400 --height 220 & sleep 0.1
}

checkUpdates() {
    echo "Current macOS version: $osVersion"
    #echo "Targeting updates on macOS version: $updateVersion"

        if [[ "$osVersionSimple" == "14" ]]; then
            echo "Checking softwareupdate on Sonoma..."
            availableUpdates=$(softwareupdate -l | grep "Title:" | cut -d ',' -f1 | awk -F ':' '{print $2}' | sed 's/ //' | sort -r)
        elif [[ "$osVersionSimple" == "13" ]]; then
            echo "Checking softwareupdate on Ventura..."
            availableUpdates=$(softwareupdate -l | grep "Title:" | cut -d ',' -f1 | awk -F ':' '{print $2}' | sed 's/ //' | grep -v "Monterey" | grep -v "Sonoma" | sort -r)
        elif [[ "$osVersionSimple" == "12" ]] && [[ "$updateVersion" == "X" ]]; then
            echo "Checking softwareupdate on Monterey...(No upgrades allowed)"
            availableUpdates=$(softwareupdate -l | grep "Title:" | cut -d ',' -f1 | awk -F ':' '{print $2}' | sed 's/ //' | grep -v "Ventura" | grep -v "Sonoma" | sort -r)
        elif [[ "$osVersionSimple" == "12" ]] && [[ "$updateVersion" == "13" ]]; then
            echo "Checking softwareupdate on Ventura..."
            availableUpdates=$(softwareupdate -l | grep "Title:" | cut -d ',' -f1 | awk -F ':' '{print $2}' | sed 's/ //' | grep -v "Monterey" | grep -v "Sonoma" | sort -r)
        elif [[ "$osVersionSimple" == "11" ]]; then
            echo "Checking softwareupdate on Ventura..."
            availableUpdates=$(softwareupdate -l | grep "Title:" | cut -d ',' -f1 | awk -F ':' '{print $2}' | sed 's/ //' | grep -v "Monterey" | grep -v "Sonoma" | sort -r)
        elif [[ "$osVersionSimple" == "10" ]]; then
			echo "*** WARNING: macOS version too old [10/Catalina] to update via S.U.P.E.R.M.A.N! Sending to System Preferences... ***"
        	sysPreferences
        fi

            if [[ "$availableUpdates" == *"macOS"* ]]; then
                echo "progresstext: macOS update found! ✅" >> ${commandFile}
                sleep 5
            fi
            if [[ "$availableUpdates" == *"Safari"* ]]; then
                safariUpdate=1
                echo "progresstext: Safari update found! ✅" >> ${commandFile}
                echo "Safari update available, grabbing version.."
                safariUpdateVersion=$(softwareupdate -l | grep "Title" | grep "Safari" | awk '{print $4}' | cut -d ',' -f1)
                safariUpdateComp=$(echo "Safari $safariUpdateVersion")
            fi

            if [[ -n "$availableUpdates" ]]; then
                echo "quit:" >> ${commandFile} && updatesAvailable_Win
                echo "* SOFTWAREUPDATE: Update(s) available! *"
                IFS=$'\n'
                availableUpdates=($availableUpdates)

                    for (( i=0; i<${#availableUpdates[@]}; i++ ))
                        do
                                if [[ "$safariUpdate" -eq 1 ]]; then
                                    for value in "${availableUpdates[@]}"
                                        do
                                        [[ $value != Safari ]] && new_array+=($availableUpdates)
                                        done
                                    availableUpdates=("${new_array[@]}")
                                    availableUpdates+=("$safariUpdateComp")
                                    echo "$i: ${availableUpdates[$i]}"
                                    safariUpdate=0
                                else
                                    echo "$i: ${availableUpdates[$i]}"
                                fi
                        done

                totalUpdates=${#availableUpdates[*]}
                echo "Total updates: $totalUpdates"
                echo "progresstext: Preparing to download updates..." >> ${commandFile}

                    if [[ "$totalUpdates" -eq 1 ]]; then
                        echo "height: 180" >> ${commandFile} &
                        echo "list: ${availableUpdates[0]}" >> ${commandFile}
                        echo "listitem: ${availableUpdates[0]}: wait" >> ${commandFile}
                    elif [[ "$totalUpdates" -eq 2 ]]; then
                        echo "height: 230" >> ${commandFile} &
                        echo "list: ${availableUpdates[0]}, ${availableUpdates[1]}" >> ${commandFile}
                        echo "listitem: ${availableUpdates[0]}: wait" >> ${commandFile} &
                        echo "listitem: ${availableUpdates[1]}: wait" >> ${commandFile}
                    elif [[ "$totalUpdates" -eq 3 ]]; then
                        echo "height: 280" >> ${commandFile} &
                        echo "list: ${availableUpdates[0]}, ${availableUpdates[1]}, ${availableUpdates[2]}" >> ${commandFile}
                        echo "listitem: ${availableUpdates[0]}: wait" >> ${commandFile} &
                        echo "listitem: ${availableUpdates[1]}: wait" >> ${commandFile} &
                        echo "listitem: ${availableUpdates[2]}: wait" >> ${commandFile}
                    fi
                sleep 5
            else
                echo "* SOFTWAREUPDATE: No updates available/found. *"
				echo "Running S.U.P.E.R.M.A.N just in-case..."
				/Library/Management/super/super
                sleep 3
                echo "Notifying user that 0 updates are available."
                echo "quit:" >> ${commandFile}
                noUpdateMessage
            fi
}

noUpdateMessage() {
     $swiftDialogBin -o -p -i "$swiftIcon" --iconsize 65 --centericon \
    --title "macOS Up-to-Date" --titlefont size="18" \
    --message "No available updates found.<br>Please allow a few minutes for any other possible updates that may be preparing." --messagefont size="15" --messageposition center --messagealignment center \
    --button1text: "OK" --helpmessage "If you were expecting updates, please try restarting this Mac and running the policy again." \
    --position bottomright  --width 400 --height 220 & sleep 0.1
        echo "activate:" >> ${commandFile} & exit 0
}

checkSuperPlist() {
    echo "* MANAGED S.U.P.E.R.M.A.N PREFERENCES *"
        if [[ ! -f "$superPlist" ]] && [[ "$fallbackMethod" -eq 0 ]]; then
            echo "*** CRITICAL: S.U.P.E.R.M.A.N plist NOT found AND 'Fallback Method disabled' ! ***"
            echo "*** CHECK FAILED: Machine not scoped for S.U.P.E.R.M.A.N or possibly needs reboot! ***"
            echo "title: Unable To Find Updates" >> ${commandFile} &
            echo "progresstext: Exiting..." >> ${commandFile}
            echo "progress: 1" >> ${commandFile}
            sleep 15
            echo "quit:" >> ${commandFile}
            exit 1
        elif [[ ! -f "$superPlist" ]] && [[ "$fallbackMethod" -eq 1 ]]; then
            echo "* Fallback Method Enabled *"
            echo "*** WARNING: Machine not scoped for S.U.P.E.R.M.A.N or possibly needs reboot! ***"
			sysPreferences
            exit 0
        elif [[ -f "$superPlist" ]]; then
            echo "* CHECK PASSED: Managed S.U.P.E.R.M.A.N Preferences found. Continuing... *"
            updateVersion=$(defaults read "$superPlist" InstallMacOSMajorVersionTarget)
        fi
}

sysPreferences(){
            echo "progresstext: Opening System Preferences to update..." >> ${commandFile}
            echo "Opening System Settings for user and exiting prompt..."
            open -b com.apple.systempreferences "/System/Library/PreferencePanes/SoftwareUpdate.prefPane"
            sleep 5
            echo "quit:" >> ${commandFile}
}

superCheck() {
    echo "* INITIAL CHECK: S.U.P.E.R.M.A.N *"
        if [[ -e "$superBin" ]] && [[ "$superVersion" == "$deployedSuperVersion" ]]; then
            echo "* CHECK PASSED: S.U.P.E.R.M.A.N found! *"
            echo "STATUS: Calling S.U.P.E.R.M.A.N and tailing super.log"
            echo "progresstext: Preparing to download updates..." >> ${commandFile}
            sleep 5
            /Library/Management/super/super | superTail
        elif [[ -e "$superBin" ]] && [[ "$superVersion" != "$deployedSuperVersion" ]]; then
            echo "* WARNING: S.U.P.E.R.M.A.N found BUT version out-of-date! *"
            rm -rf "/Library/Management/super"
            echo "S.U.P.E.R.M.A.N: $superVersion"
            superInstall
        elif [[ ! -e "$superBin" ]]; then
            echo "* CHECK FAILED: S.U.P.E.R.M.A.N NOT found! *"
                if [[ -n "$superPolicy" ]]; then
                    superInstall
                elif [[ -z "$superPolicy" ]]; then
                    echo "superPolicy not set! Unable to download S.U.P.E.R.M.A.N. Exiting..."
                    echo "title: Unable To Complete Updates" >> ${commandFile} &
                    echo "progresstext: Update tool [SUPER] not found! Exiting..." >> ${commandFile} &
                    echo "progress: 1" >> ${commandFile}
                    sleep 12
                    echo "quit:" >> ${commandFile}
                    exit 1
                fi
        fi
}

superTail() {
    while read -r line
        do
            echo "progresstext: Downloading update..." >> ${commandFile}
            if [[ $line == *"Previously downloaded macOS minor update is prepared"* ]]; then
                echo "title: Download Complete" >> ${commandFile} &
                echo "progresstext: Updates downloaded! Preparing..." >> ${commandFile} &
                echo "progress: complete" >> ${commandFile}
                echo "S.U.P.E.R.M.A.N: Previous download found!"
                sleep 1
            elif [[ $line == *"Downloading:"* ]]; then
                echo "title: Downloading Updates" >> ${commandFile} &
                echo "progresstext: $line" >> ${commandFile} &
                echo "progress: 50" >> ${commandFile}
                # Add ability to show progress from download to live progress percent
                #echo "progress: $downloadProgress" >> ${commandFile}
                sleep 1
            elif [[ $line == *"downloading..."* ]]; then
                echo "title: Downloading Updates" >> ${commandFile} &
                echo "progresstext: Downloading update..." >> ${commandFile}
                echo "progress: 50" >> ${commandFile}
            elif [[ $line == *"Downloaded:"* ]] || [[ $line == *"downloaded"* ]]; then
                echo "progresstext: Preparing Updates" >> ${commandFile} &
                echo "progress: 75" >> ${commandFile}
            elif [[ $line =~ "IBM Notifier: Restart or defer dialog with no timeout" ]] || [[ $line =~ "IBM Notifier: User authentication deadline count dialog" ]]; then
                echo "title: Updates Ready To Install" >> ${commandFile}
                    if [[ "$totalUpdates" -eq 1 ]]; then
                        echo "listitem: ${availableUpdates[0]}: success" >> ${commandFile}
                    elif [[ "$totalUpdates" -eq 2 ]]; then
                        echo "listitem: ${availableUpdates[0]}: success" >> ${commandFile} &
                        echo "listitem: ${availableUpdates[1]}: success" >> ${commandFile}
                    elif [[ "$totalUpdates" -eq 3 ]]; then
                        echo "listitem: ${availableUpdates[0]}: success" >> ${commandFile} &
                        echo "listitem: ${availableUpdates[1]}: success" >> ${commandFile} &
                        echo "listitem: ${availableUpdates[2]}: success" >> ${commandFile}
                    fi
                echo "progresstext: Preparing update notification" >> ${commandFile} &
                echo "progress: complete" >> ${commandFile}
                echo "Download complete. User prompted with SUPER."
                sleep 4
                echo "quit:" >> ${commandFile}
                    exit 0
            fi
        done
}

superInstall() {
    echo "progresstext: Downloading update & notification tool..." >> ${commandFile} &
    echo "STATUS: Calling Jamf Pro Policy: super-4"
    jamf policy -event "$superPolicy" &>/dev/null & disown;
        until [[ -e "$superLog" ]]; do
            #echo "S.U.P.E.R.M.A.N does not exist yet..."
            echo "progresstext: Installing update & notification tool..." >> ${commandFile}
            sleep 1
        done
    echo "progresstext: Update & notification tool installed..." >> ${commandFile}
    echo "S.U.P.E.R.M.A.N installed successfully!"
    sleep 5
    echo "progresstext: Preparing to download updates..." >> ${commandFile}
    tail -f "$superLog" | superTail
}

## End Functions

### Begin Main Body ###

iconCheck
swiftDialogCheck
deleteIBMNotifier
ibmNotifierCheck
ssWindow
checkSuperPlist
checkUpdates
superCheck

# End Body

exit 0
