# Thinkst Canary Scripts and Resources
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

### canary_api2csv.sh
**Author:** Thinkst (Adrian)  
**Purpose:** Intended for SIEM use - only pulls unique new alerts that haven't been pulled previously and exports them to a CSV file. Suitable for a cron job that runs this command and places files in a location where the SIEM knows to pick them up and ingest them.  
**Usage:** Edit the file to copy in your unique console URL and API key. Then, just run the script with no arguments.  

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

### canarygen_awscreds_auto.sh
**Author:** Thinkst (Adrian)  
**Purpose:** This shell script generates unique AWS credential tokens each time it is run. It was specifically designed to run with zero dependencies (as opposed to the python version of this script, which has a few). It is designed to run once per host, as the description for each token is customized using local environment variables (username and hostname).  
**Usage:** This is the 'auto' version of this script (the 'arguments' version isn't finished yet), meaning that you'll have to manually edit the script to set your Console and API key variables.  
**Compatibility:** This script has been tested and confirmed to run correctly on macOS (Catalina and High Sierra) and Ubuntu 18.04.  

### delete_tokens.py
**Author:** Thinkst (Jay)  
**Purpose:** This script came from a customer that was testing creating large amounts of tokens. They needed a quick way to 'clean up' their console while testing, so we built this script (with many disclaimers!) to wipe a console clean of Canarytokens.  
**Usage:** `python3 delete_tokens.py <console_url> <api_key>`

### deploy_tokens.ps1
**Author:** Thinkst (Bradley)  
**Purpose:** A sample for mass deploying tokens in parallel across Active Directory.  
**Usage:** `deploy_tokens.ps1`

### yellow - just add blue
**Author:** Dominic White (singe)  
**Purpose:** A simple binary wrapper that will trigger a Canarytoken when a binary is executed.  
**Link to Repo:** [singe/yellow](https://github.com/singe/yellow)

### CanaryDeleter
**Author:** Thinkst (Sherif)
**Purpose:** Delete all incidents from a specific flock (using flock's name), or from a specific Canary device (using its NodeID); tool will optionally dump all incidents to a json file.
**Usage:**
#### _Deleting all incidents from the default flock._
`./CanaryDeleter -apikey $API_KEY -console $CONSOLE_HASH -flock "Default Flock"`
#### _Deleting all incidents from a specific node, without dumping incidents to a json file_
`./CanaryDeleter -apikey $API_KEY -console $CONSOLE_HASH -node 00034d476ff8e02d -dump=false`

### GreyNoise-Community-Canary-Threat-Intel-Report.sh
**Author:** Sage AI Labs (justin-varner)

**Purpose:** This shell script is intended to run your alerts through the GreyNoise Community API.

**Usage:** Set the `CANARY_HASH` & `CANARY_TOKEN` variables, as well as the `BIRD_ID` you'd like to retrieve the events from. Run the script and the results will be populated in a new json file.
Doppler is a handy tool for securely syncing and managing environment variables. You can sign up for a free account [here](https://dashboard.doppler.com/register)

**Prerequisites:** The Canary API functionality will need to be enabled on your Console, a guide available [here](https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-).
You will then need the {jq}(https://stedolan.github.io/jq/) package installed on your local machine.
The script currently only supports outside Birds, a guide on how to enable this [here](https://help.canary.tools/hc/en-gb/articles/360017954338-Configuring-your-device-as-an-Outside-Bird).

### GreyNoise-Enterprise-Canary-Threat-Intel-Report.sh
**Author:** Sage AI Labs (justin-varner)

**Purpose:** This shell script is intended to run your alerts through the GreyNoise Enterprise API.

**Usage:** Set the `CANARY_HASH`, `CANARY_TOKEN`, and `GREYNOISE_API_KEY` variables, as well as the `BIRD_ID` you'd like to retrieve the events from. Run the script and the results will be populated in a new json file.
Doppler is a handy tool for securely syncing and managing environment variables. You can sign up for a free account [here](https://dashboard.doppler.com/register)

**Prerequisites:** The Canary API functionality will need to be enabled on your Console, a guide available [here](https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-).
You will also need a GreyNoise Enterprise API key, a trial key can be obtained [here](https://www.greynoise.io/viz/signup).
You will then need the {jq}(https://stedolan.github.io/jq/) package installed on your local machine.
The script currently only supports outside Birds, a guide on how to enable this [here](https://help.canary.tools/hc/en-gb/articles/360017954338-Configuring-your-device-as-an-Outside-Bird).
