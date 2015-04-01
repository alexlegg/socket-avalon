db_url = "localhost"
mongoose = require('mongoose')
bcrypt = require('bcrypt')

db = mongoose.connect(db_url)

#
# Database schema definition
#

GAME_LOBBY      = 0
GAME_PREGAME    = 1
GAME_PROPOSE    = 2
GAME_VOTE       = 3
GAME_QUEST      = 4
GAME_LADY       = 5
GAME_ASSASSIN   = 6
GAME_FINISHED   = 7

ObjectId = mongoose.Schema.Types.ObjectId

playerSchema = new mongoose.Schema
    name        : String
    password    : String
    socket      : String
    currentGame : ObjectId

#playerSchema.methods.set_password = (password, cb) ->
#    bcrypt.hash password, 8, (err, hash) ->
#        this.password = hash
#        cb()
#
#playerSchema.methods.check_password = (password, cb) ->
#    bcrypt.compare password, this.password, (err, res) ->
#        cb(err, res)

playerSchema.methods.leave_game = (cb) ->
    player = this
    Game.findById this.currentGame, (err, game) ->
        return if err || not game

        for p in game.players
            if p.id.equals(player._id)
                if game.state == GAME_LOBBY || game.state == GAME_PREGAME
                    index = game.players.indexOf(p)
                    game.players.splice(index, 1)
                else
                    p.left = true
                    p.socket = undefined
                break

        if game.players.length == 0
            game.remove()

        game.save (err, game) ->
            cb(err, game)

Player = mongoose.model('Player', playerSchema)

gameSchema = new mongoose.Schema
    state       : {type: Number, default: GAME_LOBBY}
    gameOptions : {
        mordred     : Boolean
        oberon      : Boolean
        showfails   : Boolean
        ladylake    : Boolean
        danmode     : Boolean
    }
    roles       : [
        name    : String
        isEvil  : Boolean
    ]
    players      : [
        id       : {type: ObjectId, ref: 'Player'}
        name     : String
        socket   : String
        order    : Number
        role     : String
        isEvil   : Boolean
        left     : {type: Boolean, default: false}
        info     : [
            otherPlayer : String
            information : String
        ]
    ]
    missions    : [
        numReq      : Number
        failsReq    : Number
        players     : [
            id      : ObjectId
            success : Boolean
        ]
        status  : {type: Number, default: 0}
    ]
    votes       : [
        mission : Number
        team    : [ObjectId]
        votes   : [
            id      : ObjectId
            vote    : Boolean
        ]
    ]
    currentMission  : Number
    currentLeader   : ObjectId
    finalLeader     : ObjectId
    lady            : ObjectId
    pastLadies      : [ObjectId]
    evilWon         : Boolean
    assassinated    : ObjectId
    reconnect_vote  : [Number]
    reconnect_user  : String
    reconnect_sock  : String
    created         : {type: Date, default: Date.now}

gameSchema.methods.name = () ->
    names = @players.map (p) -> p.name
    return names.join(', ')

gameSchema.methods.add_player = (p) ->
    for gp in this.players
        if gp.name == p.name
            return false

    this.players.push
        id  : p._id
        name : p.name
        socket : p.socket
        role : undefined
        isEvil : undefined
        info : []
    return true

gameSchema.methods.get_player = (id) ->
    for p in this.players
        if p.id.equals(id)
            return p
    return null

mission_reqs =
    5 : [2, 3, 2, 3, 3]
    6 : [2, 3, 4, 3, 4]
    7 : [2, 3, 3, 4, 4]
    8 : [3, 4, 4, 5, 5]
    9 : [3, 4, 4, 5, 5]
    10 : [3, 4, 4, 5, 5]
    11 : [4, 5, 5, 6, 6]
    12 : [4, 5, 5, 6, 6]

gameSchema.methods.setup_missions = () ->
    np = this.players.length
    for i in [0..4]
        this.missions.push
            numReq : mission_reqs[np][i]
            failsReq : if i == 3 && np >= 7 then 2 else 1
            players : []

    this.currentMission = 0

gameSchema.methods.set_next_leader = (new_mission) ->
    next = -1
    for p in this.players
        if p.id.equals(this.currentLeader)
            next = (p.order + 1) % this.players.length

    final = -1
    for p in this.players
        if p.order == next
            this.currentLeader = p.id
            final = (p.order + 4) % this.players.length

    if new_mission
        for p in this.players
            if p.order == final
                this.finalLeader = p.id

gameSchema.methods.check_for_game_end = () ->
    succ = ((if m.status == 2 then 1 else 0) for m in this.missions)
    succ = succ.sum()
    fail = ((if m.status == 1 then 1 else 0) for m in this.missions)
    fail = fail.sum()
    if succ == 3
        hasAssassin = false
        for p in this.players
            if p.role == "Assassin"
                hasAssassin = true
                this.currentLeader = p.id
                this.state = GAME_ASSASSIN
        if not hasAssassin
            this.state = GAME_FINISHED
    else if fail == 3
        this.state = GAME_FINISHED
        this.evilWon = true
    else
        this.currentMission += 1
        if this.gameOptions.ladylake
            this.state = GAME_LADY
        else this.state = GAME_PROPOSAL

shuffle = (a) ->
      for i in [a.length-1..1]
          j = Math.floor Math.random() * (i + 1)
          [a[i], a[j]] = [a[j], a[i]]
      return a

gameSchema.methods.start_game = (order) ->
    this.state = GAME_PROPOSE


    if this.gameOptions.danmode
        for p, i in this.players
            if p.name == "Dan"
                p.role = "Servant"
                p.isEvil = false

                this.roles.push
                    name    : "Servant"
                    isEvil  : false
            else
                p.role = "Minion"
                p.isEvil = true

                this.roles.push
                    name    : "Minion"
                    isEvil  : true

            if i == 0
                p.order = 0
            else
                p.order = order[p.id]
    else
        this.roles.push
            name    : "Merlin"
            isEvil  : false
        this.roles.push
            name    : "Assassin"
            isEvil  : true
        this.roles.push
            name    : "Percival"
            isEvil  : false
        this.roles.push
            name    : "Morgana"
            isEvil  : true
        cur_evil = 2

        num_evil = Math.ceil(this.players.length / 3)

        if this.gameOptions.mordred && cur_evil < num_evil
            this.roles.push
                name    : "Mordred"
                isEvil  : true
            cur_evil += 1

        if this.gameOptions.oberon && cur_evil < num_evil
            this.roles.push
                name    : "Oberon"
                isEvil  : true
            cur_evil += 1

        #Fill evil
        while (cur_evil < num_evil)
            this.roles.push
                name : "Minion"
                isEvil : true
            cur_evil += 1

        #Fill good
        while (this.roles.length < this.players.length)
            this.roles.push
                name : "Servant"
                isEvil : false

        #Assign roles
        playerroles = shuffle(this.roles)
        for p, i in this.players
            r = playerroles.pop()
            p.role = r.name
            p.isEvil = r.isEvil
            if i == 0
                p.order = 0
            else
                p.order = order[p.id]

    #Sort by order
    this.players.sort((a, b) -> a.order - b.order)

    #Give info
    for p in this.players
        switch p.role
            when "Merlin", "Assassin", "Minion", "Morgana", "Mordred"
                for o in this.players
                    if o.isEvil
                        if p.role == "Merlin" && o.role == "Mordred"
                            continue
                        if p.role != "Merlin" && o.role == "Oberon"
                            continue
                        p.info.push
                            otherPlayer : o.name
                            information : "evil"
            when "Percival"
                for o in this.players
                    if o.role == "Merlin" || o.role == "Morgana"
                        p.info.push
                            otherPlayer : o.name
                            information : "magic"

    this.setup_missions()
    leader = Math.floor Math.random() * this.players.length
    this.currentLeader = this.players[leader].id

    final = (this.players[leader].order + 4) % this.players.length
    for p in this.players
        if p.order == final
            return this.finalLeader = p.id

    if this.gameOptions.ladylake
        lady = (this.players[leader].order - 1) % this.players.length
        for p in this.players
            if p.order == lady
               return this.lady = p.id
        this.pastLadies = []

Game = mongoose.model('Game', gameSchema)

