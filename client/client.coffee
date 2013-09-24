socket = io.connect('http://localhost')
socket.on 'connect', (data) ->
    console.log("connected")

socket.on 'gamelist', (games) ->
    $("#entername").hide()
    $("#lobby").show()
    $("#gamelist").empty()
    for g in games
        join_btn = $('<input>').attr
            class : "btn_joingame"
            type : "button"
            value : "Join"
            id : "joingame" + g.id

        join_btn.click (e) ->
            game_id = e.target.id.substr(8)
            socket.emit 'joingame', { game_id : game_id }
            $('#lobby').hide()
            $('#pregame').show()

        $("#gamelist").append(
            $('<tr>').append($('<td>').text(g.name))
                .append($('<td>').text(g.num_players + "/5"))
                .append($('<td>').append(join_btn))
        )

socket.on 'gameinfo', (game) ->
    console.log "game info"
    $("#lobby").hide()
    if !game.started
        $("#pregame").show()
        $("#gameinfo").empty()
        for p in game.players
            ready = if p.ready then '\u2714' else '\u2715'
            $("#gameinfo").append(
                $('<tr>').append($('<td>').text(p.name))
                    .append($('<td>').text(ready)))
    else
        $("#pregame").hide()
        $("#game").show()

        me = game.players[game.me]
        if me.isEvil
            $("#myrole").addClass("evil")
        else
            $("#myrole").addClass("good")
        $("#myrole").text(me.role)

        for i in me.info
            $("#hiddeninfo").append(i.otherPlayer + " is " + i.information + "<br /")

jQuery ->
    $("#btn_playername").on 'click', () ->
        socket.emit 'newuser', {name: $("#playername").val()}

    $("#new_game").on 'click', () ->
        console.log "new game"
        socket.emit 'newgame'

    $("#btn_ready").on 'click', () ->
        if $("#btn_ready").attr("value") == "I am Ready"
            $("#btn_ready").attr("value", "I am not Ready")
        else
            $("#btn_ready").attr("value", "I am Ready")
        socket.emit 'ready'

    $("#btn_showinfo").on 'click', () ->
        $("#hiddeninfo").toggle()
