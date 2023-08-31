addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

// Change this to a unique value -- this will become the authentication header field "auth" string for the PowerShell fetch script to use.
// Note: Be careful not to use the " or $ character in this authentication string
const authString = "canhasauthenticated"

async function handleRequest(request) {
  // check we have a POST request
  if (request.method !== "GET") {    
    return new Response(``, {status: 200}) 
  }
  try {
    let Auth = request.headers.get("auth")
    
    // check to make sure the request is authenticated with a secret
    if (Auth !== authString){
      return new Response(``, {status: 200})
    }
    else {
      const values = await canaryevents.list()
      const keys = values.keys;

      // no data to send
      if (!keys) {
        return new Response(``, {status: 204})
        }
    
      const length = keys.length
      var content = keys[0].name
      await canaryevents.delete(keys[0].name)
      
      if (length > 1) {
        for (let i = 1; i < length; i++) {
          content = content + `\n` + keys[i].name
          await canaryevents.delete(keys[i].name)
        }
      }
      return new Response(content, {status: 200})
    }
  }
  // if error (likely no data to send)
  catch (e) {
    return new Response(``, {status: 204})
  }
}
