socket = io.connect('http://' + document.domain)
socket.on 'connect', (data) ->
    alert "connected"
    console.log("connected")

socket.on 'gamelist', (games) ->
    $("#form-signin").hide()
    $("#lobby").show()
    $("#gamelist").empty()
    for g in games
        join_btn = $('<a>')
            .attr(class : "list-group-item")
            .text(g.name)
            .append($('<span>').attr(class: "badge").text(g.num_players))
            .on 'click touchstart', () ->
                socket.emit 'joingame', { game_id : g.id }
                $('#lobby').hide()
                $('#pregame').show()

        $("#gamelist").append(join_btn)

socket.on 'gameinfo', (game) ->
    console.log "game info"
    $("#lobby").hide()
    if !game.started
        $("#pregame").show()
        $("#gameinfo").empty()
        for p in game.players
            ready = if p.ready then '\u2714' else '\u2715'
            li = $('<li>')
                .attr(class : "list-group-item")
                .text(p.name)
                .append($('<span>').attr(class: "badge").text(ready))
            $("#gameinfo").append li
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
    $("#form-signin").on 'submit', (e) ->
        socket.emit 'newuser', {name: $("#playername").val()}
        e.preventDefault()

    $("#btn_newgame").on 'click touchstart', () ->
        console.log "new game"
        socket.emit 'newgame'

    $("#btn_ready").on 'click touchstart', () ->
        if $("#btn_ready").text()  == "I am Ready"
            $("#btn_ready").text("I am not Ready")
        else
            $("#btn_ready").text("I am Ready")
        socket.emit 'ready'

    $("#btn_showinfo").on 'click touchstart', () ->
        $("#hiddeninfo").toggle()
