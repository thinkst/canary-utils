# Canary-Cloudflare
### Cloudflare workers to:
    1. Receive Thinkst Canary webhooks
    2. Parse, create, and buffer syslog messages
    3. Publish a real-time IP blocklist
### ...and a Powershell script to:
    1. Fetch syslog events from the buffer
    2. Push these events to a syslog UDP collector
    
### Requirements
1. Thinkst Canary account with at least one Canary (https://canary.tools/)
   - It may also be possible with [Opencanary](https://github.com/thinkst/opencanary), but this has not been tested.  
2. A Cloudflare account (https://www.cloudflare.com/)
   - Don't have one?  This solution can be deployed to even a free account!  
### Cloudflare Setup
1. Log in to your [Cloudflare dashboard](https://dash.cloudflare.com), choose your account, select "Workers & Pages" and click "KV."  
2. Click "Create a namespace," enter "Canary-Blocks" for the name, and click "Add."  
3. Click "Create a namespace," enter "Canary-Events" for the name, and click "Add."  
4. Now click on "Overview" below the "Workers & Pages" menu option.  
5. Click "Create application"  
    - Click the "Create Worker" button  
    - Enter "canary-receiver" for the name and click "Deploy"  
    - IMPORTANT: Make note of the URL shown on the Congratulations page under, "Preview your worker."  
      - It will look something like https://canary-receiver.organization.workers.dev  
      - You will need this URL to set up the Canary webhook  
    - Click "Configure Worker"  
      - Click "Settings" above the summary section of the page  
      - Click the "Variables" menu option  
      - Under "KV Namespace Bindings" click "Add binding"  
      - Enter "canaryblocks" for the variable name and select "Canary-Blocks" for the KV namespace  
      - Click "Save and deploy"  
      - Again, click "Add binding"  
      - Enter "canaryevents" for the variable name and select "Canary-Events" for the KV namespace  
      - Click "Save and deploy"  
    - Click on the "Quick Edit" button at the top right area of the page  
      - Copy and paste the full contents of the canary-receiver.js file into the editor window  
      - Review the declared variables at the top of the script and adjust as desired/necessary for your environment.  
        - MyCanary should be set to the name of a public-facing Canary you would like to use to create your IP blocklist.
        - Make note of the value you set for _authString_ -- this is the auth value you configure for the Canary webhook custom header.
      - Click "Save and deploy."  
6. Click "Create application"  
    - Click the "Create Worker" button  
    - Enter "canary-request-blocklist" for the name and click "Deploy"
    - IMPORTANT: Make note of the URL shown on the Congratulations page under, "Preview your worker."  
      - It will look something like https://canary-request-blocklist.organization.workers.dev  
      - You will need this URL for any device (eg. firewall) or program that will be consuming this IP list  
    - Click "Configure Worker"  
      - Click "Settings" above the summary section of the page  
      - Click the "Variables" menu option  
      - Under "KV Namespace Bindings" click "Add binding"  
      - Enter "canaryblocks" for the variable name and select "Canary-Blocks" for the KV namespace  
      - Click "Save and deploy"  
   - Click on the "Quick Edit" button at the top right area of the page  
     - Copy and paste the full contents of the canary-request-blocklist.js file into the editor window
     - Edit the AllowedIPs string variable to include any IP addresses that should be permitted to retrieve the IP blocklist and click "Save and deploy."
7. Click "Create application"  
    - Click the "Create Worker" button  
    - Enter "canary-request-syslog" for the name and click "Deploy"
    - IMPORTANT: Make note of the URL shown on the Congratulations page under, "Preview your worker."  
      - It will look something like https://canary-request-syslog.organization.workers.dev  
      - You will need this URL for any device (eg. firewall) or program that will be consuming this IP list  
    - Click "Configure Worker"  
      - Click "Settings" above the summary section of the page  
      - Click the "Variables" menu option  
      - Under "KV Namespace Bindings" click "Add binding"  
      - Enter "canaryevents" for the variable name and select "Canary-Events" for the KV namespace  
      - Click "Save and deploy"  
   - Click on the "Quick Edit" button at the top right area of the page  
     - Copy and paste the full contents of the canary-request-syslog.js file into the editor window
     - Edit _authString_ to be a unique string value.  This will be used with the Fetch-Canary-Syslog.ps1 script
### Canary Setup
1. Log in to your [Canary account](https://canary.tools)  
    - Click on the "Gear" and then "Global Settings" to go to the Global Settings page.  
    - Click on Webhooks and paste the canary-block URL from Cloudflare Setup step 5 into the "Generic" option.  
    - Select custom headers and add a header called, "auth" with a value of "canhasauthenticated" [screenshot](https://github.com/Xorlent/Canary-Cloudflare/blob/main/CanaryWebhookConfig.png) and click "Add."  
      - You can easily change this default authentication value by editing the JavaScript within the canary-receiver Worker.
### Powershell Syslog Fetcher Setup
1. Download Canary-Fetch-Syslog.ps1 and Canary-Fetch-Syslog-Config.xml  
2. Right-click each file, select Properties, check "Unblock" and click "Ok"  
3. Edit the xml file in Notepad according to your environment  
4. Save the files to an appropriate location for execution  
5. Create a scheduled task to execute Canary-Fetch-Syslog.ps1 as often as you would like, and ensure the "Run In" location is set  

### Using/Testing
- You can now trigger a Canary event  
  - Alternately, you can re-open the code editor for the canary-receiver Worker (Setup step 5) and perform a POST request using the supplied ExampleRequest.json.  
    - Be sure to include the "auth" header value as you set in Setup step 6 (default: canhasauthenticated).  
  - Open a file browser to the https://canary-request-blocklist.organization.workers.dev URL to view the live IP list.  
- If you need to delete or clean up any IP list database entries:  
  - Log in to your Cloudflare dashboard  
  - Choose your account  
  - Select "Workers & Pages" and click "KV."  
  - Click the "View" link for "Canary-Blocks" and/or "Canary-Events"  
