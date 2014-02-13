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

app.get '/games', (req, res) ->
    res.sendfile(__dirname + '/html/games.html')

app.get '/game', (req, res) ->
    res.sendfile(__dirname + '/html/game.html')

app.get '/api', (req, res) ->
    return if not req.query['type']
    switch req.query['type']
        when "games"
            Game.find {}, (err, games) ->
                response = []
                for g in games
                    if g.state != GAME_FINISHED
                        continue

                    response.push
                        name : g.name()
                        date : g.created
                        id   : g._id

                res.send(response)
        when "game"
            Game.findById req.query['id'], (err, game) ->
                res.send(game)
        else
            res.send("{blah: 'blah'}")

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
