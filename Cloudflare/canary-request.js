addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  // check we have a POST request
  if (request.method !== "GET") {    
    return new Response(``, {status: 200}) 
  }
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
    return new Response(``, {status: 200})
  }
}
