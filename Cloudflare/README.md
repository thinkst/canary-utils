# Canary-Cloudflare
## Cloudflare workers to receive Thinkst Canary webhooks and publish real-time IP blocklist
### Requirements
1. Thinkst Canary account with at least one Canary (https://canary.tools/)
   - It looks like it may also be possible with [Opencanary](https://github.com/thinkst/opencanary), but this has not been tested  
3. A Cloudflare account (https://www.cloudflare.com/)  
### Setup
1. Log in to your [Cloudflare dashboard](https://dash.cloudflare.com), choose your account, select "Workers & Pages" and click "KV."  
2. Click "Create a namespace," enter "Canary-Blocks" for the name, and click "Add."  
3. Now click on "Overview" below the "Workers & Pages" menu option.  
4. Click "Create application"  
    - Click the "Create Worker" button  
    - Enter "canary-block" for the name and click "Deploy"  
    - IMPORTANT: Make note of the URL shown on the Congratulations page under, "Preview your worker."  
      - It will look something like https://canary-block.organization.workers.dev  
      - You will need this URL to set up the Canary webhook  
    - Click "Configure Worker"  
      - Click "Settings" above the summary section of the page  
      - Click the "Variables" menu option  
      - Under "KV Namespace Bindings" click "Add binding"  
      - Enter "canaryblocks" for the variable name and select "Canary-Blocks" for the KV namespace  
      - Click "Save and deploy"  
    - Click on the "Quick Edit" button at the top right area of the page  
      - Copy and paste the full contents of the canary-block.js file into the editor window  
      - Edit the "Perimeter" value on line 6 to match the Canary device name whose events you want to add to the IP block list.  
        - Events from any other Canary will be ignored.  Generally, you will only want to register events for a public-facing Canary.  
      - Click "Save and deploy."  
5. Click "Create application"  
    - Click the "Create Worker" button  
    - Enter "canary-request" for the name and click "Deploy"
    - IMPORTANT: Make note of the URL shown on the Congratulations page under, "Preview your worker."  
      - It will look something like https://canary-request.organization.workers.dev  
      - You will need this URL for any device (eg. firewall) or program that will be consuming this IP list  
    - Click "Configure Worker"  
      - Click "Settings" above the summary section of the page  
      - Click the "Variables" menu option  
      - Under "KV Namespace Bindings" click "Add binding"  
      - Enter "canaryblocks" for the variable name and select "Canary-Blocks" for the KV namespace  
      - Click "Save and deploy"  
   - Click on the "Quick Edit" button at the top right area of the page  
     - Copy and paste the full contents of the canary-request.js file into the editor window and click "Save and deploy."  
6. Log in to your [Canary account](https://canary.tools)  
    - Click on the "Gear" and then "Global Settings" to go to the Global Settings page.  
    - Click on Webhooks and paste the canary-block URL from step 4 into the "Generic" option.  
    - Select custom headers and add a header called, "auth" with a value of "canhasauthenticated" [screenshot](https://github.com/Xorlent/Canary-Cloudflare/blob/main/CanaryWebhookConfig.png) and click "Add."  
      - You can easily change this default authentication value by editing the JavaScript within the canary-block Worker.  
### Using/Testing
- You can now trigger a Canary event  
  - Alternately, you can re-open the code editor for the canary-block Worker (Setup step 4) and perform a POST request using the supplied ExampleRequest.json.  
    - Be sure to include the "auth" header value as you set in Setup step 6 (default: canhasauthenticated).  
  - Open a file browser to the https://canary-request.organization.workers.dev URL to view the live IP list.  
- If you need to delete or clean up any IP list database entries:  
  - Log in to your Cloudflare dashboard  
  - Choose your account  
  - Select "Workers & Pages" and click "KV."  
  - Click the "View" link for "Canary-Blocks"  
