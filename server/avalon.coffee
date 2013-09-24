http = require('http')
url = require('url')
fs = require('fs')
io = require('socket.io')
sys = require(if process.binding('natives').util then 'util' else 'sys')
db_url = "localhost"
mongoose = require('mongoose')

db = mongoose.connect(db_url)

html_dir = "./html"
script_dir = "."

#
# Database schema definition
#

gameSchema = new mongoose.Schema
    started     : {type: Boolean, default: false}
    roles       : [
        name    : String
        isEvil  : Boolean
    ]
    players     : [
        name    : String
        socket  : String
        ready   : Boolean
        role    : String
        isEvil  : Boolean
        info    : [
            otherPlayer : String
            information : String
        ]
    ]

gameSchema.methods.name = () ->
    names = @players.map (p) -> p.name
    return names.join(', ')

gameSchema.methods.add_player = (name, sock) ->
    this.players.push
        name : name
        socket : sock
        ready : false
        role : undefined
        isEvil : undefined
        info : []

Game = mongoose.model('Game', gameSchema)

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
        when "/client.js", "/jquery-2.0.3.min.js"
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
 
server.listen 8080
 
io = io.listen server

#
# Server side game functions
#

send_game_list = () ->
    Game.find {}, (err, games) ->
        data = games.map (g) -> 
            id : g.id
            name : g.name()
            num_players : g.players.length
        io.sockets.in('lobby').emit('gamelist', data)

send_game_info = (game) ->
    data =
        started : game.started
        id      : game.id
        roles   : game.roles

    players = []
    socks = []
    for p in game.players
        socks.push(io.sockets.socket(p.socket))
        players.push
            name        : p.name
            ready       : p.ready

    data.players = players

    for s, i in socks
        data.players[i].role = game.players[i].role
        data.players[i].isEvil = game.players[i].isEvil
        data.players[i].info = game.players[i].info
        data.me = i
        s.emit('gameinfo', data)
        data.players[i].role = undefined
        data.players[i].isEvil = undefined
        data.players[i].info = []

leave_game = (socket, game_id) ->
    Game.findById game_id, (err, game) ->
        for p in game.players
            if p.socket == socket
                index = game.players.indexOf(p)
                game.players.splice(index, 1)
                break
        game.save()

        if game.players.length == 0
            game.remove()
        send_game_list()
        send_game_info(game)

shuffle = (a) ->
      for i in [a.length-1..1]
          j = Math.floor Math.random() * (i + 1)
          [a[i], a[j]] = [a[j], a[i]]
      return a

start_game = (game) ->
    game.started = true

    #Temporary roles (no options yet)
    game.roles.push
        name    : "Merlin"
        isEvil  : false
    game.roles.push
        name    : "Assassin"
        isEvil  : true
    game.roles.push
        name    : "Percival"
        isEvil  : false
    game.roles.push
        name    : "Morgana"
        isEvil  : true
    cur_evil = 2

    #Fill evil
    num_evil = Math.ceil(game.players.length / 3)
    while (cur_evil < num_evil)
        game.roles.push
            name : "Minion"
            isEvil : true
        cur_evil += 1

    #Fill good
    while (game.roles.length < game.players.length)
        game.roles.push
            name : "Servant"
            isEvil : false

    #Assign roles
    playerroles = shuffle(game.roles)
    for p in game.players
        r = playerroles.pop()
        p.role = r.name
        p.isEvil = r.isEvil

    #Give info
    for p in game.players
        switch p.role
            when "Merlin", "Assassin", "Minion", "Morgana"
                for o in game.players
                    if o.isEvil
                        p.info.push
                            otherPlayer : o.name
                            information : "evil"
            when "Percival"
                for o in game.players
                    if o.role == "Merlin" || o.role == "Morgana"
                        p.info.push
                            otherPlayer : o.name
                            information : "magic"

#
# Socket handling
#

io.on 'connection', (socket) ->
    socket.on 'newuser', (data) ->
        socket.set('name', data['name'])
        socket.join('lobby')
        send_game_list()

    socket.on 'newgame', (game) ->
        socket.get 'name', (err, name) ->
            game = new Game()
            game.add_player(name, socket.id)
            game.save (err, data) ->
                socket.leave('lobby')
                socket.set('game', game._id)
                send_game_list()
                send_game_info(game)

    socket.on 'joingame', (data) ->
        game_id = data.game_id
        socket.get 'name', (err, name) ->
            Game.findById game_id, (err, game) ->
                game.add_player(name, socket.id)
                game.save (err, data) ->
                    socket.leave('lobby')
                    socket.set('game', game._id)
                    send_game_list()
                    send_game_info(game)

    socket.on 'ready', () ->
        socket.get 'game', (err, game_id) ->
            return if game_id == null
            Game.findById game_id, (err, game) ->
                all_ready = true
                for p in game.players
                    if p.socket == socket.id
                        p.ready = !p.ready
                    all_ready = false if !p.ready

                if game.players.length >= 5 && all_ready
                    start_game(game)

                game.save()
                send_game_info(game)
  
    socket.on 'disconnect', () ->
        socket.get 'game', (err, game_id) ->
            if game_id
                leave_game(socket.id, game_id)
