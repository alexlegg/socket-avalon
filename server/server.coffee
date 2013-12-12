io = require('socket.io')
express = require('express')
app = express()
server = app.listen(PORT)

app.configure () ->
    app.use express.static(__dirname + '/js')
    app.use express.static(__dirname + '/css')
    app.use express.static(__dirname + '/img')

app.get '/', (req, res) ->
    res.set('Pragma', 'no-cache')
    res.sendfile(__dirname + '/html/index.html')

app.get '/nocookie', (req, res) ->
    res.send('var cookies = document.cookie.split(";"); for (var i = 0; i < cookies.length; i++) eraseCookie(cookies[i].split("=")[0]);')

io = io.listen server
io.set('transports', ['websocket', 'htmlfile', 'xhr-polling', 'jsonp-polling'])

parseCookies = (headers) ->
    cookies = {}
    if headers.cookie
        for c in headers.cookie.split("; ")
            s = c.split("=")
            if s.length == 2
                cookies[s[0]] = s[1]
    return cookies

io.set 'authorization', (data, cb) ->
    cookies = parseCookies(data.headers)
    if not cookies || not cookies['player_id']
        if data.query['player_id']
            cookies = {player_id: data.query['player_id']}

    data.headers.cookie = cookies
    cb(null, true)

if DEBUG
    io.set('log level', 3)
else
    io.set('log level', 0)
    io.enable('browser client minification')
