<?php
/**
 * Canary-PHP. Written by Jack Davies ~ Cyber Security @ Aberystwyth University.
 * Version 2.0 (rewrite)
 */

namespace Canary;

use Exception;

class Canary
{
    protected $API_VERSION = 1;

    private   $DOMAIN,
        $SERVER,
        $AUTH_TOKEN,
        $BIRD_INFO,
        $BIRD_INFO_ORIGINAL;

    /**
     * @param string $DOMAIN      Canary domain
     * @param string $AUTH_TOKEN  Authentication  token
     * @param string $BIRD_ID     Bird ID (optional, can be set later using setBird())
     * @param string $BIRD_NAME   Bird name (optional, can be set later using setBird())
     * @param string $SERVER      API server (optional. Default server is "canary.tools")
     * @throws Exception
     */
    public function __construct(
        string $DOMAIN,
        string $AUTH_TOKEN,
        string $BIRD_ID   = "", // "Node ID"
        string $BIRD_NAME = "",
        string $SERVER    = "canary.tools"
    ) {
        $this->DOMAIN     = trim($DOMAIN);
        $this->SERVER     = trim($SERVER);
        $this->AUTH_TOKEN = trim($AUTH_TOKEN);

        // Test that the API is functional.
        if (!$this->pingConsole()) {
            throw new Exception("Failed to ping console! Possibly bad auth token?");
        }

        if (!empty($BIRD_ID)) {
            $this->BIRD_INFO          = $this->getBirdInfo(BIRD_ID: $BIRD_ID);
            $this->BIRD_INFO_ORIGINAL = clone($this->BIRD_INFO);
            $this->BIRD_INFO_ORIGINAL->{'device'} = clone($this->BIRD_INFO->{'device'});
            $this->BIRD_INFO_ORIGINAL->{'device'}->{'settings'} = clone($this->BIRD_INFO->{'device'}->{'settings'});
        }

        if (!empty($BIRD_NAME)) {
            $this->BIRD_INFO          = $this->getBirdInfo(BIRD_NAME: $BIRD_NAME);
            $this->BIRD_INFO_ORIGINAL = clone($this->BIRD_INFO);
            $this->BIRD_INFO_ORIGINAL->{'device'} = clone($this->BIRD_INFO->{'device'});
            $this->BIRD_INFO_ORIGINAL->{'device'}->{'settings'} = clone($this->BIRD_INFO->{'device'}->{'settings'});
        }
    }

    /**
     * Pings the console in order to check that the API is functional.
     * @return bool True if console is functional, false when not functional.
     * @throws Exception
     */
    public function pingConsole(): bool {
        if ($response = $this->sendRequest(request: "ping")) {
            if (
                $response->{'result'} == "success"
            ) {
                return true;
            }
        }

        return false;
    }

    /**
     * Write the new configuration changes to the bird.
     * @return bool
     * @throws Exception
     */
    public function writeBirdConfiguration(): bool {
        if (hash('sha256', $this->configurationToJson()) == hash('sha256', $this->configurationToJson(fetchOriginal: true))) {
            // Configuration hasn't changed. Don't bother updating as there is
            // no point in rebooting a bird for no reason.
            return true;
        }

        $response = $this->sendRequest(
            request: "device/configure",
            data: array(
                'node_id'  => $this->getBirdId(),
                'settings' => $this->configurationToJson()
            ),
            type: "POST"
        );

        if ($response->{'result'} == "success") {
            return true;
        }

        throw new Exception("Failed to update bird! Response: \n".var_dump($response));
    }

    /**
     * Converts the local bird configuration into a JSON array.
     * @return string JSON of configuration array.
     * @throws Exception
     */
    public function configurationToJson(bool $fetchOriginal = false): string {
        if (!$this->BIRD_INFO) {
            throw new Exception("No bird settings changed or obtained!");
        }

        if ($fetchOriginal) {
            return json_encode(
                $this->BIRD_INFO_ORIGINAL->{'device'}->{'settings'},
                JSON_PRETTY_PRINT
            );
        }

        return json_encode(
            $this->BIRD_INFO->{'device'}->{'settings'},
            JSON_PRETTY_PRINT
        );
    }

    /**
     * Reboots the currently selected bird.
     * @return bool True on successful reboot.
     * @throws Exception
     */
    public function rebootBird(): bool {
        $response = $this->sendRequest(
            request: "device/reboot",
            data: array(
                'node_id' => $this->getBirdId()
            ),
            type: "POST"
        );

        if ($response->{'result'} == "success") {
            return true;
        }

        return false;
    }

    /**
     * Fetch a configuration parameter or info from the currently selected bird.
     * @param string $parameter The name of the parameter. E.g. name, https.cert
     * @param bool $settings True = Fetch the parameter from the settings array.
     * @return string Value of the configuration parameter.
     * @throws Exception
     */
    public function getBirdParameter(
        string $parameter,
        bool   $settings = false
    ) {
        if (!$this->BIRD_INFO) {
            throw new Exception("No bird selected!");
        }

        if ($settings) {
            if (!isset($this->BIRD_INFO->{'device'}->{'settings'}->{$parameter})) {
                return '';
            }

            return $this->BIRD_INFO->{'device'}->{'settings'}->{$parameter};
        }

        if (!isset($this->BIRD_INFO->{'device'}->{$parameter})) {
            return '';
        }

        return $this->BIRD_INFO->{'device'}->{$parameter};
    }

    /**
     * Sets a new value for a configuration parameter.
     * @param string $newValue   New value of the configuration parameter.
     * @param string $parameter  Name of parameter to change the value of.
     * @return void
     */
    public function setBirdParameter(
        string $newValue,
        string $parameter
    ): void {
        $this->BIRD_INFO->{'device'}->{'settings'}->{$parameter} = $newValue;
    }

    /**
     * Fetches information and configuration relating to a specific bird.
     * @param string $BIRD_ID (optional) Retrieve bird info via unique random ID.
     * @param string $BIRD_NAME (optional) Retrieve bird info via admin-assigned name.
     * @return object
     * @throws Exception
     */
    private function getBirdInfo (
        string $BIRD_ID   = "",
        string $BIRD_NAME = ""
    ): object {
        // Search based on ID.
        if (!empty($BIRD_ID = trim($BIRD_ID))) {
            // Save us looping through birds.

            $response = $this->sendRequest(
                request: "device/info",
                data: [
                    "node_id"                => $BIRD_ID,
                    "settings"               => "true",
                    "exclude_fixed_settings" => "true"
                ]
            );

            if ($response->{'result'} == "success") {
                return $response;
            }

            throw new Exception("Failed to fetch bird info. Invalid ID?");
        }

        // Search based on name.
        if (!empty($BIRD_NAME = trim($BIRD_NAME))) {
            foreach ($this->getAllBirds() as $bird) {
                if ($bird->getBirdName() == $BIRD_NAME) {
                    // Name found. Fetching based on ID
                    return $this->getBirdInfo(BIRD_ID: $bird->getBirdId());
                }
            }
        }

        throw new Exception("Bird ID or name not specified or invalid!");
    }

    /**
     * Fetch a list of all birds connected to the account.
     * @return array Array of Canary constructs for each bird.
     * @throws Exception
     */
    public function getAllBirds(): array {
        $birds = [];

        foreach ($this->sendRequest(request: "devices/all")->{'devices'} as $bird) {
            $birds[] = new Canary(
                DOMAIN: $this->DOMAIN,
                AUTH_TOKEN: $this->AUTH_TOKEN,
                BIRD_ID: $bird->{'id'}
            );
        }

        return $birds;
    }

    /**
     * Return the currently defined API server.
     * @return string
     * @throws Exception
     */
    private function getApiServer(): string {
        if (
            empty($this->DOMAIN) ||
            empty($this->SERVER)
        ) {
            throw new Exception("Empty domain or server!");
        }

        return "https://".$this->DOMAIN.".".$this->SERVER;
    }

    /**
     * Sends requests to the Canary API.
     * @param string $request API endpoint/request
     * @param array $data     Parameters to provide the endpoint
     * @param string $type    Request type: GET, POST, PUT, DELETE, PATCH
     * @return mixed
     * @throws Exception
     */
    private function sendRequest(
        string $request,
        array  $data = [],
        string $type = "GET"
    ) {
        $curl = curl_init($this->getApiServer()."/api/v".$this->API_VERSION."/$request");

        curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($curl, CURLOPT_USERAGENT, "Aberystwyth University Canary-PHP Application");

        // Append our API token to the payload.
        $data['auth_token'] = $this->AUTH_TOKEN;

        switch($type){
            case "POST":
                curl_setopt($curl, CURLOPT_POST, 1);
                break;
            case "PUT":
            case "PATCH":
            case "DELETE":
            case "GET":
                curl_setopt($curl, CURLOPT_CUSTOMREQUEST, $type);
                break;
            default:
                throw new Exception("Invalid request type!");
        }

        curl_setopt($curl, CURLOPT_POSTFIELDS, http_build_query($data));

        return json_decode(curl_exec($curl));
    }

    /* ===== GETTERS ===== */

    /**
     * Fetch all configurable bird options and present them in a human-readable-ish format.
     * @return string
     */
    public function getBirdConfigurationsToString(): string {
        $lines = [];

        foreach ($this->BIRD_INFO->{'device'}->{'settings'} as $configuration => $value) {
            $lines[] = "$configuration: ".json_encode($value)."\n";
        }

        return implode("", $lines);
    }

    /**
     * Get the unique ID of the selected bird.
     * @return string
     */
    public function getBirdId(): string {
        return $this->getBirdParameter(parameter: "id");
    }

    /**
     * Get the user provided name of the selected bird.
     * @return string
     */
    public function getBirdName(): string {
        return $this->getBirdParameter(parameter: "name");
    }

    /**
     * Returns the description of the selected bird.
     * @return string
     * @throws Exception
     */
    public function getBirdDescription(): string {
        return $this->getBirdParameter(parameter: "description");
    }

    /**
     * Returns the MAC address of the selected bird.
     * @return string
     * @throws Exception
     */
    public function getBirdMacAddress(): string {
        return $this->getBirdParameter(parameter: "mac_address");
    }

    /**
     * Returns the IP address of the selected bird.
     * @return string
     * @throws Exception
     */
    public function getBirdIpAddress(): string {
        return $this->getBirdParameter(parameter: "ip_address");
    }

    /**
     * Returns the uptime of the selected bird, in human-readable format.
     * @return string
     * @throws Exception
     */
    public function getBirdUptimeHr(): string {
        return $this->getBirdParameter(parameter: "uptime_age");
    }

    /**
     * Returns the uptime of the selected bird, in seconds.
     * @return string
     * @throws Exception
     */
    public function getBirdUptime(): string {
        return $this->getBirdParameter(parameter: "uptime");
    }

    /**
     * Fetch the SSL key currently deployed on the bird.
     * @return string
     * @throws Exception
     */
    public function getBirdHttpsKey(): string {
        return $this->getBirdParameter(parameter: "https.key", settings: true);
    }

    /**
     * Fetch the SSL certificate currently deployed on the bird.
     * @return string
     * @throws Exception
     */
    public function getBirdHttpsCertificate(): string {
        return $this->getBirdParameter(parameter: "https.certificate", settings: true);
    }

    /* ===== SETTERS ===== */
    /**
     * Set a new SSL certificate on the selected bird.
     * @param string $newCertificate
     * @return void
     */
    public function setBirdHttpsCertificate(string $newCertificate): void {
        $this->setBirdParameter(newValue: $newCertificate, parameter: 'https.certificate');
    }

    /**
     * Set a new SSL key on the selected bird.
     * @param string $newKey
     * @return void
     */
    public function setBirdHttpsKey(string $newKey): void {
        $this->setBirdParameter(newValue: $newKey, parameter: 'https.key');
    }

    /**
     * Sets a new name for the selected bird.
     * @param string $newName
     * @return void
     */
    public function setBirdName(string $newName): void {
        $this->setBirdParameter(newValue: $newName, parameter: 'device.name');
    }
}