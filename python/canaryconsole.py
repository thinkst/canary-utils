# CanaryCLI 0.2

# Prereqs include:
# pip3 install canarytools console-menu PTable
import canarytools
import json
import requests
import os
import os.path
import time
from os import path
from consolemenu import *
from consolemenu.items import *
from prettytable import PrettyTable

# Prep for canarytools calls and raw API calls
if not "TARCC_CONSOLE" in os.environ:
    consolehex = input("\nYou don't appear to have a Canary Console configured. \nPlease enter just your eight-digit CNAME - the part that comes before 'canary.tools'.\nIt should look something like 'ab123456': ")
    os.environ["TARCC_CONSOLE"] = consolehex
    consoleperm = input("Would you like to set this console permanently, so that you don't have to reset this value on future sessions? \n[Y/N]: ")
    if consoleperm.upper() == "Y":
        #print("Chose yes...")
        home = os.path.expanduser("~")
        #print("Home is " + home)
        #time.sleep(2)
        if path.exists(home + "/.bashrc"):
            print("\nFound a .bashrc, going to write to it")
            profile = open(home + "/.bashrc", "a")
            profile.write("\nexport TARCC_CONSOLE=" + consolehex)
            profile.close()
            print("Writing done, closing .bashrc")
            time.sleep(2)
        if path.exists(home + "/.zshrc"):
            print("\nFound a .zshrc, going to write to it")
            profile = open(home + "/.zshrc", "a")
            profile.write("\nexport TARCC_CONSOLE=" + consolehex)
            profile.close()
            print("Writing done, closing .zshrc")
            time.sleep(2)
else:
    consolehex = os.getenv("TARCC_CONSOLE")

if not "TARCC_APIKEY" in os.environ:
    auth = input("\nYou don't appear to have an API KEY set for your Canary Console. \nEnsure API is enabled in your Canary Console settings. \nThen copy the key and paste here: ")
    os.environ["TARCC_APIKEY"] = auth
    consoleperm = input("Would you like to set this API KEY permanently, so that you don't have to reset this value on future sessions? \n[Y/N]: ")
    if consoleperm.upper() == "Y":
        home = os.path.expanduser("~")
        if path.exists(home + "/.bashrc"):
            print("\nFound a .zshrc, going to write to it")
            profile = open(home + "/.bashrc", "a")
            profile.write("\nexport TARCC_APIKEY=" + auth)
            profile.close()
            print("Writing done, closing .bashrc")
            time.sleep(2)
        if path.exists(home + "/.zshrc"):
            print("\nFound a .zshrc, going to write to it")
            profile = open(home + "/.zshrc", "a")
            profile.write("\nexport TARCC_APIKEY=" + auth)
            profile.close()
            print("Writing done, closing .zshrc")
            time.sleep(2)
else:
    auth = os.getenv("TARCC_APIKEY")

consoleurl = consolehex + ".canary.tools"
console = canarytools.Console(consolehex, auth)

# Ping the console to make sure our console URL and API keys are legit
def check_api():
    ping_apiurl = "https://{base}/api/v1/ping?auth_token={auth}".format(base=consoleurl, auth=auth)
    ping_console = requests.get(ping_apiurl)
    ping_results = ping_console.json()
    if ping_results["result"] != "success":
        print("\nERROR - Please check your:\nCanary Console URL ({}) \nAPI key ({}).\n\nThey didn't work for us.".format(consoleurl, auth))
        Screen().input('\nPress [Enter] to continue')
        exit(0)

# Pull the console name to display
def consolename():
    settings_apiurl = "https://{base}/api/v1/settings?auth_token={auth}".format(base=consoleurl, auth=auth)
    pull_settings = requests.get(settings_apiurl)
    settings = pull_settings.json()
    console_name = settings["console_domain"]
    return console_name

# Pull licensing details
def license_usage():
    license_apiurl = "https://{base}/api/v1/license?auth_token={auth}".format(base=consoleurl, auth=auth)
    pull_licenses = requests.get(license_apiurl)
    licenses = pull_licenses.json()

    # Build a table. No inserting tabs or spaces to get columns to line up anymore!
    license_table = PrettyTable()
    license_table.field_names = ["Type", "Total", "Used"]
    license_table.add_row(["Physical", licenses["devices"]["total"], licenses["devices"]["used"]])
    license_table.add_row(["Virtual", licenses["vm"]["total"], licenses["vm"]["used"]])
    license_table.add_row(["Cloud", licenses["cloud"]["total"], licenses["cloud"]["used"]])
    print(license_table)

    Screen().input('\nPress [Enter] to continue')

# Device list functions
def livebirds_details():

    livebirds_table = PrettyTable()
    livebirds_table.field_names = ["Name", "Location", "IP", "Uptime"]
    for device in console.devices.live():
        livebirds_table.add_row([device.name, device.location, device.ip_address, device.uptime_age])
    livebirds_table.sortby = "Name"
    print(livebirds_table)

    Screen().input('\nPress [Enter] to continue')

def deadbirds_details():

    deadbirds_table = PrettyTable()
    deadbirds_table.field_names = ["Name", "Location", "Personality", "Downtime"]
    for device in console.devices.dead():
        deadbirds_table.add_row([device.name, device.location, device.ippers, device.uptime_age])
    deadbirds_table.sortby = "Name"
    print(deadbirds_table)

    Screen().input('\nPress [Enter] to continue')

# Alert handling functions
def unackalerts():
    unackalertnum = len(console.incidents.unacknowledged())
    unackalerts_table = PrettyTable()
    unackalerts_table.field_names = ["Type", "Attacker"]
    for alert in console.incidents.unacknowledged():
        alertcount = 0
        unackalerts_table.add_row([alert.summary, alert.src_host])
        if alertcount == unackalertnum:
            exit(0) 
    print(unackalerts_table)

    Screen().input('\nPress [Enter] to continue')

def ackalerts():
    ackalertnum = len(console.incidents.acknowledged())
    ackalerts_table = PrettyTable()
    ackalerts_table.field_names = ["Type", "Attacker"]
    for alert in console.incidents.acknowledged():
        alertcount = 0
        ackalerts_table.add_row([alert.summary, alert.src_host])
        if alertcount == ackalertnum:
            exit(0) 
    print(ackalerts_table)

    Screen().input('\nPress [Enter] to continue')

# Token list function
def canarytoken_listing():
    tokennum = len(console.tokens.all())
    tokencount = 0
    screennum = 0
    token_table = PrettyTable()
    token_table.field_names = ["Kind", "Memo"]
    for token in console.tokens.all():
        token_table.add_row([token.kind, token.memo])
        tokencount = tokencount + 1
        if tokencount == 10:
            print(token_table)
            currtotalmax = screennum * 10 + tokencount
            currtotalmin = currtotalmax - 9
            input("Showing tokens {} through {} of {} \n\nPress [Enter] to continue".format(currtotalmin, currtotalmax, tokennum))
            token_table.clear_rows()
            tokencount = 0
            screennum = screennum + 1
            Screen().clear()
        elif screennum * 10 + tokencount == tokennum:
            print(token_table)
            currtotalmax = screennum * 10 + tokencount
            currtotalmin = screennum * 10
            input("Showing tokens {} through {} of {} \n\nPress [Enter] to return to the menu".format(currtotalmin, currtotalmax, tokennum))

# Build the stats screen
def statscreen():
    # Unacknowledged alert count
    unackalerts = len(console.incidents.unacknowledged())
    # Acknowledged alert count
    ackalerts = len(console.incidents.acknowledged())
    # Online Canary Count
    livebirds = len(console.devices.live())
    # Offline Canary Count
    deadbirds = len(console.devices.dead())
    # Tokens count
    tokencount = len(console.tokens.all())

    print("Canary Status - Live: {} Dead: {}".format(livebirds, deadbirds))
    print("Token Count - {}".format(tokencount))
    print("Incident Status - Acked: {} Unacked: {}".format(ackalerts, unackalerts))
    Screen().input('\nPress [Enter] to continue')

def inyoni():
    # Print Inyoni on exit
    print("     _\n        _| '>\n       /    )\n      / /  /\n     /_/  /\n    /- \\ \\\n        + +\n")

# Build the menu
def main():
    check_api()
    console_name = consolename()
    # Splash Screen with basic stats, followed by menu
    menu = ConsoleMenu("Lo-fi Canary Console Main Menu", "CLI Edition, version 0.1", epilogue_text="Current console: " + console_name + " (" + consoleurl + ")")
    switch_consoles = MenuItem("Switch Consoles", menu)

    # Build the Devicelist Submenu
    device_submenu = ConsoleMenu("Canary Details", "Choose an item below")
    device_submenu_livebirds = FunctionItem("Live Bird Details", livebirds_details)
    device_submenu_deadbirds = FunctionItem("Dead Bird Details", deadbirds_details)
    device_submenu.append_item(device_submenu_livebirds)
    device_submenu.append_item(device_submenu_deadbirds)

    # Attach the Devicelist Submenu to the Main menu
    devices_item = SubmenuItem("Canary Details", submenu=device_submenu)
    devices_item.set_menu(menu)

    # Build the Canarytokens Submenu
    canarytokens_submenu = ConsoleMenu("Canarytokens", "Choose an item below", epilogue_text="eb603878.canary.tools")
    canarytokens_submenu_tokenlist = FunctionItem("Token Details", canarytoken_listing)
    canarytokens_submenu_createtokens = MenuItem("Create Canarytokens (not yet implemented)")
    canarytokens_submenu.append_item(canarytokens_submenu_tokenlist)
    canarytokens_submenu.append_item(canarytokens_submenu_createtokens)

    # Attach the Canarytokens Submenu to the Main menu
    canarytokens_item = SubmenuItem("Canarytokens", submenu=canarytokens_submenu)
    canarytokens_item.set_menu(menu)

    # Build the Incidents Submenu
    incidents_submenu = ConsoleMenu("Alerts", "Choose an item below", epilogue_text="eb603878.canary.tools")
    incidents_submenu_unackalerts = FunctionItem("Unacknowledged Alerts", unackalerts)
    incidents_submenu_ackalerts = FunctionItem("Acknowledged Alerts", ackalerts)
    incidents_submenu.append_item(incidents_submenu_unackalerts)
    incidents_submenu.append_item(incidents_submenu_ackalerts)

    # Attach the incidents Submenu to the Main menu
    incidents_item = SubmenuItem("Alerts", submenu=incidents_submenu)
    incidents_item.set_menu(menu)

    # Add all items to the root menu
    menu.append_item(FunctionItem("Current Stats", statscreen))
    menu.append_item(devices_item)
    menu.append_item(canarytokens_item)
    menu.append_item(incidents_item)
    menu.append_item(FunctionItem("License Usage", license_usage))
    menu.append_item(switch_consoles)

    # Show the menu
    menu.start()
    menu.join()

if __name__ == "__main__":
        main()