db_url = "localhost"
mongoose = require('mongoose')

db = mongoose.connect(db_url)

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
        id      : Number
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
    missions    : [
        numReq      : Number
        failsReq    : Number
        players     : [
            id      : Number
            success : Boolean
        ]
        succeeded   : Boolean
    ]
    votes       : [
        team    : [Number]
        votes   : [Number, Boolean]
    ]
    currentMission  : Number
    currentLeader   : Number

gameSchema.methods.name = () ->
    names = @players.map (p) -> p.name
    return names.join(', ')

gameSchema.methods.add_player = (name, sock) ->
    this.players.push
        id  : this.players.length
        name : name
        socket : sock
        ready : false
        role : undefined
        isEvil : undefined
        info : []

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

Game = mongoose.model('Game', gameSchema)

