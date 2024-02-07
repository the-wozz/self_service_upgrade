Author: Zachary 'Woz'nicki

What this tool solves:
S.U.P.E.R.M.A.N is an amazing tool for keeping users informed of updates! This tool adds-on to S.U.P.E.R.M.A.N ability by allowing upgrades via 'Self Service' and 
presents the user with a progress window [Swift Dialog] until the upgrade is ready to be installed via S.U.P.E.R.M.A.N.

What this tool does behind the scenes:
Adds a Mac to a Computer Static group via Jamf Pro Rest API which should be in-scope of a S.U.P.E.R.M.A.N 4 'Configuration Profile' that ALLOWS UPGRADES to 14 [Sonoma]. 
This will then check if S.U.P.E.R.M.A.N exists on the machine and runs it and presents the user with a progress window [Swift Dialog] along the upgrade to when S.U.P.E.R.M.A.N finally prompts.

_With the proper scoping of the Jamf Pro Configuration Profile you can essentially have 1 'running' S.U.P.E.R.M.A.N Configuration Profile in the environment after upgrade to macOS Sonoma.
_
How to use this script:
+ Create a Jamf Pro 'API Roles and Clients' Role, name it whichever you please, and add that following Privileges:
  - Read Static Computer Groups
  - Update Static Computer Groups
+ Create a Jamf Pro 'API Roles and Clients' Client that has the previous 'Role' in that 'Client', copy the 'client ID' and 'passcode' into the Jamf Pro Policy Scripts 'Parameters', 4 and 5
+ Create a Jamf Pro Computer Static Group, name it whatever you would like.
+ Create a seperate S.U.P.E.R.M.A.N 4.x 'Configuration Profile' that ALLOWS UPGRADES to 14

Requirements:
+ macOS Monterey [12] - Ventura [13], this does appear to work on Big Sur with some output errors but overall seems to work
+ Jamf Pro 10.48+ [https://www.jamf.com/products/jamf-pro/]
+ Swift Dialog 2.4+ [https://github.com/swiftDialog/swiftDialog]
+ S.U.P.E.R.M.A.N 4.x [https://github.com/Macjutsu/super]
