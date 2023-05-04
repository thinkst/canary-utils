# Thinkst Canary Scripts and Resources
A hodgepodge of humble but helpful scripts created for Thinkst Canary customers.

While it's great that most products and services these days have APIs, they're often oversold. The answer to any question about a missing feature can be, "you can do anything with our product, it has an API!"

Logically, your next thought might be, "sure, but that API would be a lot more useful if I had a few spare Python developers to throw at a few projects..."

In this spirit, we often build scripts and bits of code to help customers automate and integrate things with our API. In some cases, our fantastic customers even write the code and donate it back to us.

Happy birding!

## Script Descriptions and Usage
In general, most of these scripts will need to be edited to add your Canary Console URL (in the form of ab1234ef.canary.tools) and your API key, which can be found in the Canary Console settings.

## Ansible

### token_multi_dropper.yaml
**Author:** Thinkst (Gareth)
**Purpose** This is an Ansible playbook containing a "deploy Canary Tokens" module to create Tokens on your hosts using the URI module.  
**Usage:** Edit line 2 with your desired host group, then edit lines 4,5 and 6 with your Console API details as well as desired flock.
By default the Tokens will be created with generic names however these can be tweaked by setting the "target_directory" and "token_filename" variables.
Run with "ansible-playbook token_multi_dropper.yaml"

## Bash

### alert_management.sh
**Author:** Thinkst (Matt)  
**Purpose** This script is a quick and easy way to export alert data out of the console and clean up the alerts all at once.  
**Usage:** Run this script with the -h flag to read the usage. API details can be entered at runtime, or edited into the script directly. Additional options exist to save and acknowledge (don't delete) or to acknowledge and delete (don't save).

### canary_alert_extract.sh
**Author:** Thinkst (Adrian)  
**Purpose:** This shell script came from a customer request to dump alerts in a spreadsheet-friendly format  
**Usage:** As with the Powershell scripts, using this script requires a bit of manual editing. Customize the API token and Canary Console variables and the shell script can be run with no arguments to produce a CSV containing the last week's alerts.  

### canary_api2csv.sh
**Author:** Thinkst (Adrian)  
**Purpose:** Intended for SIEM use - only pulls unique new alerts that haven't been pulled previously and exports them to a CSV file. Suitable for a cron job that runs this command and places files in a location where the SIEM knows to pick them up and ingest them.  
**Usage:** Edit the file to copy in your unique console URL and API key. Then, just run the script with no arguments.

### Canary-AWS-Bird-Automated-Deployment.sh
**Author:** This bash script was kindly donated by a Thinkst customer.

**Purpose:** This bash script is intended to automate the process of configuring the device personality of a bird and commissioning it for use after deploying a Canary AWS EC2 instance.

**Usage:** Set the `CANARY_HASH`, `CANARY_API_KEY`, and `FLOCK_ID` values found in your Canary console.
Set your desired values for the bird's device personality in the sample config.json file. All bird services are disabled by default.
Run the script after deploying an AWS EC2 Canary instance to automatically configure the device personality and commission the bird for use.
Doppler is a handy tool for securely syncing and managing environment variables. You can sign up for a free account [here](https://dashboard.doppler.com/register)

**Prerequisites:** You will need to deploy a Canary AWS EC2 instance before running this script. Sample code for automating the infrastructure provisioning can be found in the terraform folder of this repository. Terraform binaries can be found [here](https://www.terraform.io/downloads.html)
The Canary API functionality will need to be enabled on your Console, a guide is available [here](https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-).
You will also need the [jq](https://stedolan.github.io/jq/) package installed on your local machine.

### canarygen_awscreds_auto.sh
**Author:** Thinkst (Adrian)  
**Purpose:** This shell script generates unique AWS credential tokens each time it is run. It was specifically designed to run with zero dependencies (as opposed to the python version of this script, which has a few). It is designed to run once per host, as the description for each token is customized using local environment variables (username and hostname).  
**Usage:** This is the 'auto' version of this script (the 'arguments' version isn't finished yet), meaning that you'll have to manually edit the script to set your Console and API key variables.  
**Compatibility:** This script has been tested and confirmed to run correctly on macOS (Catalina and High Sierra) and Ubuntu 18.04.  

### canarygen_awscreds.cmd
**Author:** Thinkst (Adrian)  
**Purpose:** This is a Windows version of the following python script. It's designed to generate one unique AWS credentials token per host.  
**Usage:** The script needs to be edited to set the Console and API key variables. Requires [JQ](https://stedolan.github.io/jq/) and Curl to either be in the path, or for the path to be customized in the script.

### Canary-GreyNoise-Community-Threat-Intel-Report.sh
**Author:** This bash script was kindly donated by a Thinkst customer.

**Purpose:** This bash script is intended to run your alerts through the GreyNoise Community API.

**Usage:** Set the `CANARY_HASH` & `CANARY_API_KEY` variables, as well as the `BIRD_ID` you'd like to retrieve the events from. Run the script and the results will be populated in a new JSON file.
Doppler is a handy tool for securely syncing and managing environment variables. You can sign up for a free account [here](https://dashboard.doppler.com/register)

**Prerequisites:** The Canary API functionality will need to be enabled on your Console, a guide is available [here](https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-).
You will then need the [jq](https://stedolan.github.io/jq/) package installed on your local machine.
If you're running this script on a Linux machine, you will need to install the zip utility to extract the alerts archive. On Debian/Ubuntu/Mint, you can install zip by running ```sudo apt install zip```.
On RedHat/Centos/Fedora, you can install zip by running ```sudo dnf install zip```.
The script currently only supports outside Birds, a guide on how to enable this [here](https://help.canary.tools/hc/en-gb/articles/360017954338-Configuring-your-device-as-an-Outside-Bird).

### Canary-GreyNoise-Enterprise-Threat-Intel-Report.sh
**Author:** This bash script was kindly donated by a Thinkst customer.

**Purpose:** This bash script is intended to run your alerts through the GreyNoise Enterprise API.

**Usage:** Set the `CANARY_HASH`, `CANARY_API_KEY`, and `GREYNOISE_API_KEY` variables, as well as the `BIRD_ID` you'd like to retrieve the events from. Run the script and the results will be populated in a new JSON file.
Doppler is a handy tool for securely syncing and managing environment variables. You can sign up for a free account [here](https://dashboard.doppler.com/register)

**Prerequisites:** The Canary API functionality will need to be enabled on your Console, a guide is available [here](https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-).
You will also need a GreyNoise Enterprise API key, a trial key can be obtained [here](https://www.greynoise.io/viz/signup).
You will then need the [jq](https://stedolan.github.io/jq/) package installed on your local machine.
If you're running this script on a Linux machine, you will need to install the zip utility to extract the alerts archive. On Debian/Ubuntu/Mint, you can install zip by running ```sudo apt install zip```.
On RedHat/Centos/Fedora, you can install zip by running ```sudo dnf install zip```.
The script currently only supports outside Birds, a guide on how to enable this [here](https://help.canary.tools/hc/en-gb/articles/360017954338-Configuring-your-device-as-an-Outside-Bird).

### Recent-Canary-GreyNoise-Enterprise-Threat-Intel-Report.sh
**Author:** This bash script was kindly donated by a Thinkst customer.

**Purpose:** This bash script is intended to run your recent (last 100) alerts through the GreyNoise Enterprise API rather than every alert from antiquity.

**Usage:** Set the `CANARY_HASH`, `CANARY_API_KEY`, and `GREYNOISE_API_KEY` variables, as well as the `BIRD_ID` you'd like to retrieve the events from. Run the script and the results will be populated in a new JSON file.
Doppler is a handy tool for securely syncing and managing environment variables. You can sign up for a free account [here](https://dashboard.doppler.com/register)

**Prerequisites:** The Canary API functionality will need to be enabled on your Console, a guide is available [here](https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-).
You will also need a GreyNoise Enterprise API key, a trial key can be obtained [here](https://www.greynoise.io/viz/signup).
You will then need the [jq](https://stedolan.github.io/jq/) package installed on your local machine.
If you're running this script on a Linux machine, you will need to install the zip utility to extract the alerts archive. On Debian/Ubuntu/Mint, you can install zip by running ```sudo apt install zip```.
On RedHat/Centos/Fedora, you can install zip by running ```sudo dnf install zip```.
The script currently only supports outside Birds, a guide on how to enable this [here](https://help.canary.tools/hc/en-gb/articles/360017954338-Configuring-your-device-as-an-Outside-Bird).

### Canary-Shodan-Threat-Intel-Report.sh
**Author:** This bash script was kindly donated by a Thinkst customer.

**Purpose:** This bash script is intended to run your alerts through the Shodan API.

**Usage:** Set the `CANARY_HASH`, `CANARY_API_KEY`, and `SHODAN_API_KEY` variables, as well as the `BIRD_ID` you'd like to retrieve the events from. Run the script and the results will be populated in a new JSON file.
Doppler is a handy tool for securely syncing and managing environment variables. You can sign up for a free account [here](https://dashboard.doppler.com/register)

**Prerequisites:** The Canary API functionality will need to be enabled on your Console, a guide is available [here](https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-).
You will also need a paid Shodan plan to obtain an API key. You can find Shodan plan information [here](https://account.shodan.io/billing).
You will then need the [jq](https://stedolan.github.io/jq/) package installed on your local machine.
If you're running this script on a Linux machine, you will need to install the zip utility to extract the alerts archive. On Debian/Ubuntu/Mint, you can install zip by running ```sudo apt install zip```.
On RedHat/Centos/Fedora, you can install zip by running ```sudo dnf install zip```.
The script currently only supports outside Birds, a guide on how to enable this [here](https://help.canary.tools/hc/en-gb/articles/360017954338-Configuring-your-device-as-an-Outside-Bird).

## Powershell

### CreateTokens.ps1
**Author:** This Powershell script was kindly donated by a Thinkst customer  
**Purpose:** Create Microsoft Word document tokens for a list of target systems. (one DOCX token per host)  
**Usage:** This script doesn't require any arguments. However, you'll need to manually edit the script to add a list of hosts (starting on line 26). You'll also need to edit it if you want to use a different token type.  

In the future, we'll likely update this script to take a list of hosts from an external command (e.g. net view /domain) or from an external text file. Perhaps we can also extend it in the future to output different types of tokens as well.

### DeployTokens.ps1
**Author:** This Powershell script was kindly donated by a Thinkst customer  
**Purpose:** This script is intended to deploy the tokens created by CreateTokens.ps1  
**Usage:** As with CreateTokens.ps1, no arguments are taken with this script, you'll need to manually edit it to point it at the tokens you've created and to change the destination for the token. By default, it gets placed in c:\Users\Administrator\Desktop  

### deploy_tokens.ps1
**Author:** Thinkst (Bradley)  
**Purpose:** A sample for mass deploying tokens in parallel across Active Directory.  
**Usage:** `deploy_tokens.ps1`

### find_and_delete_tokens.ps1
**Author:** Thinkst (Gareth)  
**Purpose:** Quick and easy search for Tokens, then delete them.  
**Usage:** ./find_and_delete_tokens.ps1 -domain ABC123 -auth_token DEF456 -flock flock:default -clear_incidents $True -kind http -search_string host1

## Python

### canaryconsole.py
**Author:** Thinkst (Adrian)  
**Purpose:** This is a command-line version of the Canary console. Functionality is limited to read-only functions at this stage, but it may be further developed into a tool that makes it easier to deploy large numbers of Canarytokens or make mass changes to the Canaries.  
**Usage:** Type ```python3 canaryconsole.py``` and it will do the rest, including prompting for the console name and API key.

### canarygen_awscreds_auto.py
**Author:** Thinkst (Adrian)  
**Purpose:** This python script generates unique AWS credential tokens each time it is run. This script is designed to run once per host, as the description for each token is customized using local environment variables (username and hostname).  
**Usage:** This is the 'auto' version of this script (the 'arguments' version isn't finished yet), meaning that you'll have to manually edit the script to set your Console and API key variables.

### delete_tokens.py
**Author:** Thinkst (Jay)  
**Purpose:** This script came from a customer that was testing creating large amounts of tokens. They needed a quick way to 'clean up' their console while testing, so we built this script (with many disclaimers!) to wipe a console clean of Canarytokens.  
**Usage:** `python3 delete_tokens.py <console_url> <api_key>`

### delete_tokens.py
**Author:** Thinkst (Jay)  
**Purpose:** This script came from a customer that was testing creating large amounts of tokens. They needed a quick way to 'clean up' their console while testing, so we built this script (with many disclaimers!) to wipe a console clean of Canarytokens.  
**Usage:** `python3 delete_tokens.py <console_url> <api_key>`

### list_and_delete_factory_auth.py
**Author:** Customer (Taiga Walker)  
**Purpose** Simply edit the Domain and ApiKey variables to match your Console. Running the script will delete all factory auth strings from your Console.
**Usage:** `python3 list_and_delete_factory_auth.py`

## Binaries

### CanaryDeleter
**Author:** Thinkst (Sherif)
**Purpose:** Delete all incidents from a specific flock (using flock's name), or from a specific Canary device (using its NodeID); tool will optionally dump all incidents to a json file.
**Usage:**
#### _Deleting all incidents from the default flock._
`./CanaryDeleter -apikey $API_KEY -console $CONSOLE_HASH -flock "Default Flock"`
#### _Deleting all incidents from a specific node, without dumping incidents to a json file_
`./CanaryDeleter -apikey $API_KEY -console $CONSOLE_HASH -node 00034d476ff8e02d -dump=false`

### yellow - just add blue
**Author:** Dominic White (singe)  
**Purpose:** A simple binary wrapper that will trigger a Canarytoken when a binary is executed.  
**Link to Repo:** [singe/yellow](https://github.com/singe/yellow)
