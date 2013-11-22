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
GAME_ASSASSIN   = 5
GAME_FINISHED   = 6

ObjectId = mongoose.Schema.Types.ObjectId

playerSchema = new mongoose.Schema
    name        : String
    password    : String
    socket      : String
    currentGame : ObjectId

Player = mongoose.model('Player', playerSchema)

playerSchema.methods.set_password = (password, cb) ->
    bcrypt.hash password, 8, (err, hash) ->
        this.password = hash
        cb()

playerSchema.methods.check_password = (password, cb) ->
    bcrypt.compare password, this.password, (err, res) ->
        cb(err, res)

gameSchema = new mongoose.Schema
    state       : {type: Number, default: GAME_LOBBY}
    gameOptions : {
        mordred     : Boolean
        oberon      : Boolean
        showfails   : Boolean
    }
    roles       : [
        name    : String
        isEvil  : Boolean
    ]
    players     : [
        id      : ObjectId
        name    : String
        socket  : String
        ready   : Boolean
        order   : Number
        role    : String
        isEvil  : Boolean
        info    : [
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
    evilWon         : Boolean
    assassinated    : ObjectId

gameSchema.methods.name = () ->
    names = @players.map (p) -> p.name
    return names.join(', ')

gameSchema.methods.add_player = (p) ->
    this.players.push
        id  : p._id
        name : p.name
        socket : p.socket
        ready : false
        role : undefined
        isEvil : undefined
        info : []

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

gameSchema.methods.setup_missions = () ->
    np = this.players.length
    for i in [0..4]
        this.missions.push
            numReq : mission_reqs[np][i]
            failsReq : if i == 3 && np >= 7 then 2 else 1
            players : []

    this.currentMission = 0

gameSchema.methods.set_next_leader = () ->
    next = 0
    for p in this.players
        if p.id.equals(this.currentLeader)
            next = (p.order + 1) % this.players.length

    for p in this.players
        if p.order == next
            this.currentLeader = p.id

gameSchema.methods.check_for_game_end = () ->
    succ = ((if m.status == 2 then 1 else 0) for m in this.missions)
    succ = succ.sum()
    fail = ((if m.status == 1 then 1 else 0) for m in this.missions)
    fail = fail.sum()
    if succ == 3
        this.state = GAME_ASSASSIN
        for p in this.players
            if p.role == "Assassin"
                this.currentLeader = p.id
    else if fail == 3
        this.state = GAME_FINISHED
        this.evilWon = true
    else
        this.currentMission += 1
        this.state = GAME_PROPOSE

Game = mongoose.model('Game', gameSchema)

