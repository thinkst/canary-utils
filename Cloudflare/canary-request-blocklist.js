addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

// Edit this string to include any source IP addresses that should be able to retrieve the IP blocklist.
const AllowedIPs = "1.2.3.4,5.6.7.8"

async function handleRequest(request) {
  // check we have a GET request
  if (request.method !== "GET") {
    return new Response(``, {status: 200})
  }
  // validate client IP
  const clientIP = request.headers.get("CF-Connecting-IP")
  if(AllowedIPs.search(clientIP) > -1){
      try {
        const values = await canaryblocks.list()
        const keys = values.keys;
    
        if (!keys) {
          return new Response(``, {status: 200})
          }
        
        const length = keys.length
        var content = keys[0].name
    
        if (length > 1) {
          for (let i = 1; i < length; i++) {
            content = content + `\n` + keys[i].name
          }
        }
        return new Response(content, {status: 200})
      }
      catch (e) {
        /* use `Error:  ${e}` response string to debug */
        return new Response(``, {status: 200})
      }
  }
  else {
  // if we made it here, the IP was rejected
  return new Response(``, {status: 403})
  }
}
