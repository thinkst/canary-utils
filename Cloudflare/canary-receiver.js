addEventListener('fetch', event => {
    event.respondWith(handleRequest(event.request))
  })
  
  // Change this to a unique value -- this will become the authentication header field "auth" string for the Canary generic webhook to use.
  // Note: Be careful not to use the " or $ character in this authentication string
  const authString = "canhasauthenticated"
  
  // Syslog messages formatted to RFC 3164 (BSD)
  // Change true to false to disable the Syslog parse/store routine.
  const EnableSyslog = true
  // Ensures the KV records purge after 7 days if they have not been picked up for syslog processing.
  const SyslogBufferTTL = 604800
  
  // Change "BlockListCanary" to the name of a Canary you would like contributing to a IP blocklist.  Leave value as-is to disable.
  const MyCanary = "BlockListCanary"
  // Auto-purge blocked IP addresses after 6 months.
  const IPBlocklistTTL = 15552000
  
  const Months = ["zero", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  
  async function handleRequest(request) {
    // check we have a POST request
    if (request.method !== "POST") {    
      return new Response(``, {status: 200}) 
    }
    try {
      let Auth = request.headers.get("auth")
      
      // check to make sure the request is authenticated with a secret
      if (Auth !== authString){
        return new Response(``, {status: 200})
      }
      else {
        // authentication received, process event
        const data = await request.json()
        let Timestamp = data.Timestamp
        let Payload = "n/a"
        let MaliciousEvent = 1
        let SyslogPriority = "<113>"
        switch (true){
            case /Scan/.test(data.Description):
              SyslogPriority = "<116>";
              break;
            case /Custom/.test(data.Description):
              SyslogPriority = "<116>";
              break;
            case /Load/.test(data.Description):
              SyslogPriority = "<116>";
              break;
            case /Settings Changed/.test(data.Description):
              SyslogPriority = "<117>";
              MaliciousEvent = 0;
              break;
            case /Disconnected/.test(data.Description):
              SyslogPriority = "<114>";
              MaliciousEvent = 0;
              break;
            case /Reconnected/.test(data.Description):
              SyslogPriority = "<118>";
              MaliciousEvent = 0;
              break;
            case /Dummy/.test(data.Description):
              SyslogPriority = "<119>";
              MaliciousEvent = 0;
              break;
        }
        if (EnableSyslog) {
          let SyslogSplitDate = Timestamp.split("-")
          let SyslogSplitTime = SyslogSplitDate[2].split(" ")
          let MonthIndex = Number(SyslogSplitDate[1])
          let SyslogMonth = Months[MonthIndex]
          SyslogSplitTime[0] = SyslogSplitTime[0].replace("0"," ")
          Payload = `${SyslogPriority} ${SyslogMonth} ${SyslogSplitTime[0]} ${SyslogSplitDate[0]} ${SyslogSplitTime[1]} ${data.CanaryName}(${data.CanaryLocation}) CanaryEvent: ${data.Intro} | Desc: ${data.Description} | Port: ${data.CanaryPort} | RemoteIP: ${data.SourceIP} | PTR: ${data.ReverseDNS}`
          // Store in KV store (Key-Value store)
          await canaryevents.put(Payload, Timestamp, {expirationTtl: SyslogBufferTTL})
        }
  
        if (data.CanaryName == MyCanary && MaliciousEvent == 1) {
          const MaliciousIP = data.SourceIP
          // Store in KV store (Key-Value store)
          await canaryblocks.put(MaliciousIP, Timestamp, {expirationTtl: IPBlocklistTTL})
          return new Response(
            `Marked IP: ${MaliciousIP} and Stored Event: ${Payload}`,
            {status: 200}
          )
        }
        else {
          return new Response(
          `Stored Event: ${Payload}`,
          {status: 200}
          )
        }
      }
    } catch (e) {
      /* use `Error:  ${e}` response string to debug */
      return new Response(``, {status: 200})
    }
  }
