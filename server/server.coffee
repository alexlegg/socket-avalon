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
    r = url.parse(req.url)
    path = r.pathname
    switch path
        when "/", "/game", "/stats"
            fn = if path == "/stats" then "/stats.html" else "/index.html"
            fs.readFile html_dir + fn, (err, data) ->
                return send404 if err
                res.writeHead 200, { 'Content-Type': 'text/html;charset=utf-8' }
                res.write data, 'utf8'
                res.end()
        when "/bootstrap.min.css", "/bootstrap-theme.min.css", "/avalon.css", "stats.css"
            fs.readFile style_dir + path, (err, data) ->
                return send404 res if err
                res.writeHead 200, { 'Content-Type': 'text/css' }
                res.write data, 'utf8'
                res.end()
        when "/avalon.js", "/jquery.min.js", "/bootstrap.min.js", "/jquery.cookie.js", "/stats.js"
            fs.readFile script_dir + path, (err, data) ->
                return send404 res if err
                res.writeHead 200, { 'Content-Type': 'text/javascript' }
                res.write data, 'utf8'
                res.end()

        #Stats API
        when "/gamestats"
            if r.query != null && r.query['id'] != null
                Game.findById r.query['id'], (err, game) ->
                    res.writeHead 200, { 'Content-Type': 'application/json' }
                    res.write JSON.stringify(game), 'utf8'
                    res.end()
            else
                Game.find {}, (err, games) ->
                    res.writeHead 200, { 'Content-Type': 'application/json' }
                    res.write JSON.stringify(games), 'utf8'
                    res.end()
        else send404 res

send404 = (res) ->
    res.writeHead 404
    res.write "404"
    res.end()
 
server.listen PORT

io = io.listen server
io.set('transports', ['websocket'])

if DEBUG
    io.set('log level', 3)
else
    io.set('log level', 0)
    io.enable('browser client minification')
