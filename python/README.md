## Python

### ad_joiner.py
**Author:** Thinkst (Support)  
**Purpose** Automates AD joining Canaries. One or more Canaries to the same domain can be done using the `cli_args` flag. If you want to join a variety of Canaries (`node_ids`) each to `domains` use the `to_file/from_file` flag. Run `python3 ad_joiner.py to_file --generate-file <file_name>.csv` to generate a `.csv` with the headers needed. Then populate that `.csv` and run `python3 ad_joiner.py --console <console_hash> --auth-token <api-key> from_file --file-path`.  
**Usage:** 
`python3 ad_joiner.py -h`

`python3 ad_joiner.py from_file -h` and `python3 ad_joiner.py cli_args -h`

### alert_management.py
**Author:** Javier Domínguez Gómez  
**Purpose:** Manage all incidents by combining multiple filters and being able to paginate automatically if necessary, all in one tool.  
**Usage:**
```commandline
usage: alert_management.py [-h] -d DOMAIN [-f FLOCKID] [-s SINCE] [-a {true,false}] [-l LIMIT] [-o OUTPUTFILE]

Tool to query the Canary All Incidents API Endpoint and manage the response.

options:
  -h, --help            show this help message and exit
  -d DOMAIN, --domain DOMAIN
                        Client domain to append as <your_domain>.canary.tools URL.
  -f FLOCKID, --flockid FLOCKID
                        (Optional) Get all incidents for a specific flock_id.
  -s SINCE, --since SINCE
                        (Optional) Only return incidents whose updated_id is greater than this integer. The returned 
                        feed includes a max_updated_id field if the incident list has entries.
  -a {true,false}, --acknowledged {true,false}
                        (Optional) To filter acknowledged or unacknowledged incidents. Valid values are 'true', 
                        'false'. If you do not specify this flag you will receive all incidents.
  -l LIMIT, --limit LIMIT
                        (Optional) Parameter used to initiate cursor pagination. The limit is used to specify the page 
                        sizes returned when iterating through the pages representing all incidents.
  -o OUTPUTFILE, --outputfile OUTPUTFILE
                        (Optional) JSON file to dump the API query response.
```

### Binary Chirp
**Author:** Thinkst (Gareth)  
**Purpose:**
Proof of concept project which uses pyinstaller to embed Tokens into python scripts then creates small Tokened executables of them.

chirp_template.py - This is a simple example binary, out of the box it simply grabs some fingerprinting detail about the host and fires of a Token adding the grabbed data as additional information. This serves as a great framework that can be fully edited to pretend to be anything else.
 
token_builder.py - This script is responsible for generating a Token and embedding it within the above file, then creating an executable from it. By default it will create an executable in the users home directory.
 
You can quickly start by editing the token_builder.py script with your Console's domain hash and create a Factory Auth String on lines 19 - 24.
 
The host building your binaries will need python3 installed and the following dependencies, which can be installed using the below command.
 
pip install requests pyinstaller dnspython
 
Once built, the Tokened binaries can be placed on hosts without the need for python to be installed.

**Usage:** `# python3 token__builder.py`

### canaryconsole.py
**Author:** Thinkst (Adrian)  
**Purpose:** This is a command-line version of the Canary console. Functionality is limited to read-only functions at this stage, but it may be further developed into a tool that makes it easier to deploy large numbers of Canarytokens or make mass changes to the Canaries.  
**Usage:** Type ```python3 canaryconsole.py``` and it will do the rest, including prompting for the console name and API key.

### canarygen_awscreds_auto.py
**Author:** Thinkst (Adrian)  
**Purpose:** This Python script generates unique AWS credential tokens each time it is run. This script is designed to run once per host, as the description for each token is customized using local environment variables (username and hostname).  
**Usage:** This is the 'auto' version of this script (the 'arguments' version isn't finished yet), meaning you'll have to manually edit the script to set your Console and API key variables.

### crowdstrike_rtr_api_wrapper.py
**Author:** Thinkst (Gareth)  
**Purpose:**
Crowdstrike RTR wrapper using [falconpy](https://www.falconpy.io/).

Used to easily upload and execute a deployment script across multiple endpoints, either online or offline. 

Paired well with out deployment article [here](https://help.canary.tools/hc/en-gb/articles/5779584032541-Deploying-Canarytokens-using-Crowdstrike-Falcon).

Thank you to [TaigaWalker](https://github.com/TaigaWalk/Cyber-Deception) for inspiring this script with his previous work to make Token deployment via RTR easier.

**Usage:** `# python3 crowdstrike_rtr_api_wrapper.py -h`

### delete_tokens.py
**Author:** Thinkst (Jay)  
**Purpose:** This script came from a customer who was testing creating large amounts of tokens. They needed a quick way to 'clean up' their console while testing, so we built this script (with many disclaimers!) to wipe a console clean of Canarytokens.  
**Usage:** `python3 delete_tokens.py <console_url> <api_key>`

### edit_bird_mac.py
**Author:** Thinkst (Gareth)  
**Purpose** Simply tweak the MAC prefix on your Canary to a custom one not found in the list.  
**Usage:** `python3 edit_bird_mac.py [-h] -domain DOMAIN -apikey APIKEY -nodeid NODEID -macprefix MACPREFIX`

### list_and_delete_factory_auth.py
**Author:** Customer (Taiga Walker)  
**Purpose** Simply edit the Domain and ApiKey variables to match your Console. Running the script will delete all factory auth strings from your Console.
**Usage:** `python3 list_and_delete_factory_auth.py`