const url = require('url');
const http = require("http");
const query = require('querystring');

http.createServer(function (request, response) {
    // Send the HTTP header 
    // HTTP Status: 200 : OK
    // Content Type: text/plain
    response.writeHead(200, {'Content-Type': 'text/plain'});
    // get seconds
    const parsed = url.parse(request.url);
    const qs = query.parse(parsed.query);
    var seconds = parseInt(qs.wait || 0);
    // wait    
    setTimeout(function(){
        // Send the response body as "Hello World"
        response.end('Hello World after ' + seconds + " seconds");
    }, seconds * 1000);
 }).listen(3000);
 
