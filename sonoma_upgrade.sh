#!/bin/bash

# Original Author: Brian Oanes
# Re-vised Author: Zachary 'Woz'nicki
# What it do: allow Sonoma upgrades via S.U.P.E.R.M.A.N from Self Service. adds machine to Static Group which allows for addition of .U.P.E.R.M.A.N CP to allow upgrades to macOS Sonoma.
# Requirements: Jamf Pro, Swift Dialog, S.U.P.E.R.M.A.N 4.x, macOS [12] Monterey - [13] Ventura

version="0.9"
versionDate="1/29/24"

# API Variables #

# *** Jamf Pro URL ***
jamfProURL=""
apiClientID=""
apiClientSecret=""
# End API Variables #

# Customizable variables #

# Static Group to ADD machine to, Parameter 4 in 'Script Parameters'
staticGroup=$4
# S.U.P.E.R.M.A.N Configuration Profile NAME with NEW macOS ugprade version to look for:
Profile1=$5
# Swift Dialog icon for notifications, follow Swift Dialog wiki for accepted icon types
swiftIcon=""
# macOS Sonoma icon to use for Swift Dialog
sonomaIcon=""
# Swift Dialog Jamf Pro policy event trigger for machines that do not have Swift Dialog installed. Swift can be installed prior and this will be ignored
swiftPolicy="swift_dialog"
# S.U.P.E.R.M.A.N Jamf Pro Policy
superPolicy="super-4"
# Seconds to look for Profile before exiting, remember this variable is x 5!
seconds=180
# Shows additional echoes for troubleshooting
verboseMode=0

# End customizable variables

# S.U.P.E.R.M.A.N log file
superLog="/Library/Management/super/logs/super.log"
# Swift Dialog binary FULL location, not advisable to use symlink!
swiftDialog="/usr/local/bin/dialog"
# Swift Dialog command file
commandFile="/var/tmp/dialog.log"
#staticGroup="Sonoma Upgrades"
staticGroup_Convert="${staticGroup// /%20}"
# Pre-Stage IDs to show to user, comma seperated, NO spaces!
serialNumber=$(system_profiler SPHardwareDataType | /usr/bin/awk '/Serial Number/{print $4}')
# Shows All Profiles installed on device
profiles=$(/usr/bin/profiles -C -v | awk -F: '/attribute: name/{print $NF}' | /usr/bin/grep "$Profile1" | /usr/bin/sed 's/^ *//')
# End Variables #

verboseCheck(){
if [[ "$verboseMode" -gt 0 ]]; then
    /bin/echo "!* VERBOSE MODE ENABLED *!"
    /bin/echo "Extra logging will be shown."
    #/bin/echo "Converted Static Group (No spaces): $staticGroup_Convert"
fi
}

## Functions ##

# Jamf Pro Access Token
get_Access_Token() {
    /bin/echo "STATUS: Getting Access Token..."
    response=$(/usr/bin/curl -s -L -X POST "$jamfProURL"/api/oauth/token \
                    -H 'Content-Type: application/x-www-form-urlencoded' \
                    --data-urlencode "client_id=$apiClientID" \
                    --data-urlencode 'grant_type=client_credentials' \
                    --data-urlencode "client_secret=$apiClientSecret")
    accessToken=$(/bin/echo "$response" | /usr/bin/plutil -extract access_token raw -)
    if [[ -n "$accessToken" ]]; then
        /bin/echo "STATUS: Access Token aquired!"
    else
        /bin/echo "ERROR: Unable to get Access Token! Exiting..."
        exit 1
    fi
    if [[ "$verboseMode" -gt 0 ]]; then
        /bin/echo "Access Token: $accessToken"
    fi
}

# Check for Swift Dialog
dialog_Check() {
    /bin/echo "* START-UP: Swift Dialog Check *"
    if [[ -e "$swiftDialog" ]]; then
        /bin/echo "STATUS: Swift Dialog found. Able to prompt."
    else
        /bin/echo "** CAUTION: Swift Dialog NOT found! **"
        /bin/echo "STATUS: Calling Jamf Pro Policy: $swiftPolicy"
        /usr/local/jamf/bin/jamf policy -event "$swiftPolicy"
            /usr/bin/wait
    fi
}

dialogBox(){
    /bin/echo "SWIFT DIALOG: Prompting user..."
        "$swiftDialog" -d -o -p --button1text none \
        --width 400 --height 240 --position bottomright --progress \
        -i "$swiftIcon" --iconsize 96 --centericon -y "$sonomaIcon" \
        --progresstext "Adding machine to upgrade group..." \
        -t "macOS Sonoma Upgrade" --titlefont size="17" \
        --messagefont size="10" --messageposition center --messagealignment center -m ""
}

add_To_Static_Group(){
    if [[ "$profiles" != "$Profile1" ]]; then
    skip=0
    get_Access_Token
        /bin/echo "STATUS: Adding $serialNumber to 'Computer Static Group': [$staticGroup]"
        /bin/echo "progresstext: ADDING: $serialNumber to $staticGroup" >> ${commandFile} & /bin/sleep 2 #allows time for user to see status message of progress

            apiData="<computer_group><computer_additions><computer><serial_number>$serialNumber</serial_number></computer></computer_additions></computer_group>"

            staticAdd=$(curl -s -L -X PUT "$jamfProURL"/JSSResource/computergroups/name/"$staticGroup_Convert" -o /dev/null \
            -H "Authorization: Bearer ${accessToken}" \
            -H "Content-Type: text/xml" \
            --data "${apiData}")

        # echo variable to empty console
        /bin/echo "$staticAdd" >> /dev/null
        /bin/echo "SUCCESS: $serialNumber added to $staticGroup"
        /bin/echo "progresstext: ADDED: $serialNumber to $staticGroup" >> ${commandFile} & /bin/sleep 3 #allows time for user to see status message of progress
    else
        /bin/echo "PROFILE: $profiles exists on machine already!"
        /bin/echo "STATUS: Skipping add to Static Group: $staticGroup"
        /bin/echo "progresstext: ✅ Profile found! Checking for update..." >> ${commandFile} & /bin/sleep 3
        /bin/echo "STATUS: Calling S.U.P.E.R.M.A.N..."
        super_Call
    fi
}

check_For_Profile(){
    if [[ "$skip" == 0 ]]; then
        /bin/echo "Checking for $Profile1 on machine."
        /bin/echo "progresstext: Waiting for Configuration Profile to appear on machine..." >> ${commandFile} & /bin/sleep 5
        ProfileWaitCounter=0

	while [[ "$profiles" != *"$Profile1" ]]
		do
        	/bin/echo "Waiting for profile $Profile1..."
            ProfileWaitCounter=`expr $ProfileWaitCounter + 1`
            /bin/sleep 5
            #echo "Counter: $ProfileWaitCounter"
			profiles=$(/usr/bin/profiles -C -v | /usr/bin/awk -F: '/attribute: name/{print $NF}' | /usr/bin/grep "$Profile1")

            	if [[ -z "$profiles" ]]; then
					profiles=0
				fi

			if [[ "$ProfileWaitCounter" -gt "$seconds" ]]; then
            	/bin/echo "ERROR: Never detected $Profile1 after $seconds seconds. Exiting..."
                /bin/echo "progresstext: ERROR: ❌ Could not detect profile. Exiting..." >> ${commandFile} & /bin/sleep 5
                /bin/echo quit: >> ${commandFile} && exit 1
			fi
		done

        /bin/echo "PROFILE: $profiles FOUND!"
        /bin/echo "progresstext: ✅ Profile found! Checking for update..." >> ${commandFile} & /bin/sleep 3
        /bin/echo "STATUS: Calling S.U.P.E.R.M.A.N..."
        super_Call
    fi
}

super_Call(){
        /bin/echo "* START-UP: S.U.P.E.R.M.A.N Check *"
    if [[ -e "/Library/Management/super/super" ]]; then
        /bin/echo "STATUS: S.U.P.E.R.M.A.N found. Able to prompt."
		/bin/echo "progresstext: ✅ Profile found! Checking for update..." >> ${commandFile} & /bin/sleep 3
        /bin/echo "STATUS: Calling S.U.P.E.R.M.A.N..."
        /Library/Management/super/super --reset-super & /usr/bin/tail -f "$superLog" | superTail
    else
        /bin/echo "** CAUTION: S.U.P.E.R.M.A.N NOT found! **"
        /bin/echo "Calling Jamf Pro Policy: $superPolicy"
        /usr/local/jamf/bin/jamf policy -event "$superPolicy" --reset-super
        /bin/sleep 25
        /usr/bin/tail -f "$superLog" | superTail
        if [[ $? =~ "No such file or directory" ]]; then
            /bin/echo "*** ERROR: SUPER tail never happen! Exiting... ***"
            /bin/echo "progresstext: Possible issue ⛔️ Exiting..." >> ${commandFile} & /bin/sleep  5
            /bin/echo quit: >> ${commandFile} && exit 1
        fi
    fi
}

superTail() {
        /bin/echo "STATUS: Starting SUPER tail..."
        /bin/echo "progresstext: Starting upgrade download..." >> ${commandFile}
        /bin/echo "message: This process generally ranges from 30 minutes to 1 hour." >> ${commandFile} & /bin/sleep 3
    while read -r line
        do
            if [[ $line == *"downloading..."* ]]; then
                /bin/echo "progresstext: Downloading upgrade..." >> ${commandFile}
                #echo "progress: $sonomaDownloadPercentVar" >> ${commandFile}
            elif [[ $line == *"download complete"* ]] || [[ $line == *"downloaded"* ]]; then
                /bin/echo "SUPER: Download complete! Notifying user and exiting..."
                /bin/echo "progress: 100" >> ${commandFile}
                /bin/echo "progresstext: Upgrade downloaded! ✅ Preparing update..." >> ${commandFile} & sleep 10
            elif [[ $line == *"Restart or defer dialog with no timeout"* ]]; then
                /bin/echo "progresstext: macOS Sonoma ready for Install ✅ Preparing notification.." >> ${commandFile} & sleep 25
                /bin/echo quit: >> ${commandFile} & exit 0
            elif [[ $line == *"User chose to defer update"* ]]; then
                /bin/echo quit: >> ${commandFile} & exit 0
            fi
        done
}

## End Functions ##

### Main ###
/bin/echo "Version: $version"
/bin/echo "Version date: $versionDate"

verboseCheck
dialog_Check
dialogBox & sleep 3
add_To_Static_Group
check_For_Profile
