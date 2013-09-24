http = require('http')
io = require('socket.io')
fs = require('fs')
url = require('url')
sys = require(if process.binding('natives').util then 'util' else 'sys')

html_dir = "./html"
script_dir = "./js"
style_dir = "./css"

#
# Web server
#

server = http.createServer (req, res) ->
    path = url.parse(req.url).pathname
    switch path
        when "/"
            fs.readFile html_dir + "/index.html", (err, data) ->
                return send404 if err
                res.writeHead 200, { 'Content-Type': 'text/html;charset=utf-8' }
                res.write data, 'utf8'
                res.end()
        when "/bootstrap.min.css", "/bootstrap-theme.min.css", "/avalon.css"
            fs.readFile style_dir + path, (err, data) ->
                return send404 res if err
                res.writeHead 200, { 'Content-Type': 'text/css' }
                res.write data, 'utf8'
                res.end()
        when "/avalon.js", "/jquery.min.js", "/bootstrap.min.js"
            fs.readFile script_dir + path, (err, data) ->
                return send404 res if err
                res.writeHead 200, { 'Content-Type': 'text/javascript' }
                res.write data, 'utf8'
                res.end()
        else send404 res
 
send404 = (res) ->
    res.writeHead 404
    res.write "404"
    res.end()
 
server.listen 80

io = io.listen server
