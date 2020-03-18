# Thinkst Canary Scripts
A hodgepodge of humble but helpful scripts created for Thinkst Canary customers.

While it's great that most products and services these days have APIs, they're often oversold. The answer to any question about a missing feature can be, "you can do anything with our product, it has an API!"

Logically, your next thought might be, "sure, but that API would be a lot more useful if I had a few spare Python developers to throw at a few projects..."

In this spirit, we often build scripts and bits of code to help customers automate and integrate things withour API. In some cases, our fantastic customers even write the code and donate it back to us.

Happy birding!

## Script Descriptions and Usage
In general, most of these scripts will need to be edited to add your Canary Console URL (in the form of ab1234ef.canary.tools) and your API key, which can be found in the Canary Console settings.

### CreateTokens.ps1
**Author:** This Powershell script was kindly donated by a Thinkst customer  
**Purpose:** Create Microsoft Word document tokens for a list of target systems. (one DOCX token per host)  
**Usage:** This script doesn't require any arguments. However, you'll need to manually edit the script to add a list of hosts (starting on line 26). You'll also need to edit it if you want to use a different token type.  

In the future, we'll likely update this script to take a list of hosts from an external command (e.g. net view /domain) or from an external text file. Perhaps we can also extend it in the future to output different types of tokens as well.

### DeployTokens.ps1
**Author:** This Powershell script was kindly donated by a Thinkst customer  
**Purpose:** This script is intended to deploy the tokens created by CreateTokens.ps1  
**Usage:** As with CreateTokens.ps1, no arguments are taken with this script, you'll need to manually edit it to point it at the tokens you've created and to change the destination for the token. By default, it gets placed in c:\Users\Administrator\Desktop

### alert_management.sh
**Author:** Thinkst (Matt)  
**Purpose** This script is a quick and easy way to export alert data out of the console and clean up the alerts all at once.  
**Usage:** Run this script with the -h flag to read the usage. API details can be entered at runtime, or edited into the script directly. Additional options exist to save and acknowledge (don't delete) or to acknowledge and delete (don't save).

### canary_alert_extract.sh
**Author:** Thinkst (Adrian)  
**Purpose:** This shell script came from a customer request to dump alerts to a spreadsheet-friendly format  
**Usage:** As with the Powershell scripts, using this script requires a bit of manual editing. Customize the API token and Canary Console variables and the shell script can be run with no arguments to produce a CSV containing the last week's alerts.  

### canaryconsole.py
**Author:** Thinkst (Adrian)  
**Purpose:** This is a commandline version of the Canary console. Functionality is limited to read-only functions at this stage, but it may be further developed into a tool that makes it easier to deploy large numbers of Canarytokens or make mass changes to Canaries.  
**Usage:** Type ```python3 canaryconsole.py``` and it will do the rest, including prompting for console name and API key.

### canarygen_awscreds.cmd
**Author:** Thinkst (Adrian)  
**Purpose:** This is a Windows version of the following python script. It's designed to generate one unique AWS credentials token per host.  
**Usage:** The script needs to be edited to set the Console and API key variables. Requires [JQ](https://stedolan.github.io/jq/) and Curl to either be in the path, or for the path to be customized in the script.

### canarygen_awscreds_auto.py
**Author:** Thinkst (Adrian)  
**Purpose:** This python script generates unique AWS credential tokens each time it is run. This script is designed to run once per host, as the description for each token is customized using local environment variables (username and hostname).  
**Usage:** This is the 'auto' version of this script (the 'arguments' version isn't finished yet), meaning that you'll have to manually edit the script to set your Console and API key variables.

### delete_tokens.py
**Author:** Thinkst (Jay)  
**Purpose:** This script came from a customer that was testing creating large amounts of tokens. They needed a quick way to 'clean up' their console while testing, so we built this script (with many disclaimers!) to wipe a console clean of Canarytokens.  
**Usage:** `python3 delete_tokens.py <console_url> <api_key>`
