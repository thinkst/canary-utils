#!/usr/bin/env php
<?php
    /**
    This is to be ran from command line. A WIP script for managing Thinkst Canaries.
    **/

    include_once("Canary.php");
    use Canary\Canary;

    // Load configuration file.
    require_once("config.php");

    // Example of creating a Canary construct without a Bird ID, to fetch a list of all Birds.
    function exampleOne() {
        global $DOMAIN, $AUTH_TOKEN;

        $canary = new Canary(
            DOMAIN: $DOMAIN,
            AUTH_TOKEN: $AUTH_TOKEN
        );

        foreach ($canary->getAllBirds() as $bird) {
            echo("===================================================\n");
            echo("Bird ID: ".$bird->getBirdId()."\n");
            echo("Bird name: ".$bird->getBirdName()."\n");
            echo("Bird description: ".$bird->getBirdDescription()."\n");
            echo("Bird MAC address: ".$bird->getBirdMacAddress()."\n");
            echo("Bird IP address: ".$bird->getBirdIpAddress()."\n");
            echo("Bird HTTPS key: ".$bird->getBirdHttpsKey()."\n");
            echo("Bird HTTPS certificate: ".$bird->getBirdHttpsCertificate()."\n");
        }
    }

    // Example of selecting a specific Bird and changing its configuration.
    function exampleTwo() {
        global $DOMAIN, $AUTH_TOKEN;

        $paloaltoCanary = new Canary(
            DOMAIN:     $DOMAIN,
            AUTH_TOKEN: $AUTH_TOKEN,
            BIRD_ID:    "00000000ffffffff"
        );

        echo($paloaltoCanary->getBirdConfigurationsToString());

        // Change device name and write it.
        $paloaltoCanary->setBirdName("BIRD-TEST");
        if ($paloaltoCanary->writeBirdConfiguration()) {
           echo("Updated successfully!\n");
        } else {
           echo("Failed to update!\n");
        }
    }

    function birdsWithCerts() {
        global $DOMAIN, $AUTH_TOKEN;

        $canary = new Canary(
            DOMAIN: $DOMAIN,
            AUTH_TOKEN: $AUTH_TOKEN
        );

        foreach ($canary->getAllBirds() as $bird) {
            // We only want to show birds with certificates.
            if (!empty($bird->getBirdHttpsCertificate())) {
                echo("===================================================\n");
                echo("Bird ID: " . $bird->getBirdId() . "\n");
                echo("Bird name: " . $bird->getBirdName() . "\n");
                echo("Bird description: " . $bird->getBirdDescription() . "\n");
                echo("Bird MAC address: " . $bird->getBirdMacAddress() . "\n");
                echo("Bird IP address: " . $bird->getBirdIpAddress() . "\n");
                echo("Bird has certificate: Yes\n");
            }
        }
    }

    //exampleOne();
    //exampleTwo();
    birdsWithCerts();
?>
