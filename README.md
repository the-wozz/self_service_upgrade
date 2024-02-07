Author: Zachary 'Woz'nicki

# What this tool solves:
S.U.P.E.R.M.A.N is an amazing tool for keeping users informed of updates! This tool adds-on to S.U.P.E.R.M.A.N ability by allowing upgrades via 'Self Service' and 
presents the user with a progress window [Swift Dialog] until the upgrade is ready to be installed via S.U.P.E.R.M.A.N.

# What this tool does behind the scenes:
Adds a Mac to a Computer Static group via Jamf Pro Rest API which should be in-scope of a S.U.P.E.R.M.A.N 4 'Configuration Profile' that ALLOWS UPGRADES to 14 [Sonoma]. 
This will then check if S.U.P.E.R.M.A.N exists on the machine and runs it and presents the user with a progress window [Swift Dialog] along the upgrade to when S.U.P.E.R.M.A.N finally prompts.

_With the proper scoping of the Jamf Pro Configuration Profile you can essentially have 1 'running' S.U.P.E.R.M.A.N Configuration Profile in the environment after upgrade to macOS Sonoma._

## Requirements:
+ macOS Monterey [12] - Ventura [13], this does appear to work on Big Sur [11] with some output errors
+ Jamf Pro 10.48+ [https://www.jamf.com/products/jamf-pro/]
+ Swift Dialog 2.4+ [https://github.com/swiftDialog/swiftDialog]
+ S.U.P.E.R.M.A.N 4.x [https://github.com/Macjutsu/super]

## Customizable options [in the script itself]
### Swift Dialog icon for notifications, follow Swift Dialog wiki for accepted icon types, [not required]
> swiftIcon=""
### macOS Sonoma icon to use for Swift Dialog, [not required]
> sonomaIcon=""
### Swift Dialog Jamf Pro policy event trigger for machines that do not have Swift Dialog installed. Swift can be installed prior and this will be ignored
> swiftPolicy="swift_dialog"
### S.U.P.E.R.M.A.N Jamf Pro Policy to call if S.U.P.E.R.M.A.N does not exist on the machine
> superPolicy="super-4"
### Seconds to look for new Profile before exiting, remember this variable is x 5!
> seconds=180
### Shows additional echoes for troubleshooting
> verboseMode=0

## How to use this script [IN ORDER!]:
Create a Jamf Pro...
1. Script with 'self_service_upgrade.sh'
2. API Roles and Clients' Role, name it whichever you please, and add that following Privileges:
  - Read Static Computer Groups
  - Update Static Computer Groups
3. 'API Roles and Clients' Client that has the previous 'Role' in that 'Client', copy the 'client ID' and 'passcode' into the Jamf Pro Policy Scripts 'Parameters', 4 and 5
4. Computer Static Group, name it whatever you would like.
5. NEW S.U.P.E.R.M.A.N 4.x 'Configuration Profile' that allows the following options within the Schema:
  - Upgrades Allowed: true
  - Target version: 14
  - Scope: The 'Computer Static Group' you created in the previous step [Step 4]
6. Policy with the 'self_service_upgrade.sh' Script as a Payload and the following options:
  - Frequency: Ongoing
  - Set Parameter 4 to your 'Computer Static Group' created in Step 4
  - Set Parameter 5 to your S.U.P.E.R.M.A.N 4 Configuration Profile NAME, created in Step 5
  - Make available in Self Service
  - Suggestions:
    - Scope: Exclude - Sonoma
