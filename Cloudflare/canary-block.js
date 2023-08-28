addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

// Set this value to the name of the Canary you want to store IP events from
var MyCanary = "Perimeter"

async function handleRequest(request) {
  // check we have a POST request
  if (request.method !== "POST") {    
    return new Response(``, {status: 200}) 
  }
  try {
    let Auth = request.headers.get("auth")
    
    // check to make sure the request is authenticated with a secret
    if (Auth !== "canhasauthenticated"){
      return new Response(``, {status: 200})
    }
    else {
      // receive input
      const data = await request.json()
      // get title and feed name
      const CanaryName = data.CanaryName
      // check if the event is coming from the canary we are interested in
      if (CanaryName == MyCanary) {
        const MaliciousIP = data.SourceIP
        const Timestamp = data.Timestamp
        // process  
        // Store in KV store (Key-Value store)
        await canaryblocks.put(MaliciousIP, Timestamp)
        return new Response(
          `Marked IP: ${MaliciousIP}`,
          {status: 200}
        )
      }
      else {
        return new Response(
         `Ignored event from ${CanaryName}`,
          {status: 200}
        )
      }
    }
  } catch (e) {
    /* use `Error:  ${e}` response string to debug */
    return new Response(``, {status: 200})
  }
}
