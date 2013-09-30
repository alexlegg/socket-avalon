socket = io.connect('http://' + document.domain)
socket.on 'connect', (data) ->
    console.log(data)
    console.log("connected")

socket.on 'gamelist', (games) ->
    $("#form-signin").hide()
    $("#lobby").show()
    $("#gamelist").empty()
    for g in games
        do (g) ->
            join_btn = $('<a>')
                .addClass("list-group-item")
                .text(g.name)
                .append($('<span>').addClass("badge").text(g.num_players))
                .click () ->
                    socket.emit 'joingame', { game_id : g.id }

            $("#gamelist").append(join_btn)

socket.on 'gameinfo', (game) ->
    $("#lobby").hide()
    if !game.started
        $("#pregame").show()
        $("#gameinfo").empty()
        for p in game.players
            ready = if p.ready then '\u2714' else '\u2715'
            li = $('<li>')
                .addClass("list-group-item")
                .text(p.name)
                .append($('<span>').addClass("badge").text(ready))
            $("#gameinfo").append li
    else
        $("#pregame").hide()
        $("#game").show()

        me = game.players[game.me]
        $("#players").empty()
        for p in game.players
            li = $("<li>")
                .addClass("list-group-item")
                .text(p.name)

            icons = $("<span>")
                .addClass("pull-right")
                .attr(style : "font-size: 16px;")

            if game.currentLeader == p.id
                icons.append('\u2654')

            if game.currentLeader == me.id
                li.on 'click', (e) ->
                    select_for_mission($(e.target))
                input = $("<input>").attr
                    type    : 'hidden'
                    name    : p.id
                    value   : 0
                li.append(input)

            li.append(icons)
            $("#players").append(li)

        if game.currentLeader == me.id
            $("#btn_select_mission").show()
        else
            $("#btn_select_mission").hide()

        $("#hiddeninfo").empty()
        info = $("<span>").text(me.role)
        if me.isEvil
            info.addClass("evil")
        else
            info.addClass("good")
        li = $("<li>")
            .addClass("list-group-item")
            .text("You are ")
            .append(info)
        $("#hiddeninfo").append(li)

        for i in me.info
            info = $("<span>").text(i.information)
            if i.information == "evil" then info.addClass("evil")
            li = $("<li>")
                .addClass("list-group-item")
                .text(i.otherPlayer + " is ")
                .append(info)
            $("#hiddeninfo").append(li)

jQuery ->
    $("#form-signin").on 'submit', (e) ->
        socket.emit 'newuser', {name: $("#playername").val()}
        e.preventDefault()

    $("#btn_newgame").on 'click', () ->
        socket.emit 'newgame'

    $("#btn_ready").on 'click', () ->
        if $("#btn_ready").text()  == "I am Ready"
            $("#btn_ready").text("I am not Ready")
        else
            $("#btn_ready").text("I am Ready")
        socket.emit 'ready'

    $("#btn_showinfo").on 'click', () ->
        if $("#hiddeninfo").is(":visible")
            $("#btn_showinfo").text("Show Hidden Info")
        else
            $("#btn_showinfo").text("Hide Hidden Info")
        $("#hiddeninfo").toggle()

    $("#form-select-mission").on 'submit', (e) ->
        e.preventDefault()
        mission = []
        $("#players li").each () ->
            input = $($(this).children(":input")[0])
            if input.val() == '1'
                mission.push input.attr('name')
                $(this).removeClass('active')
                $(this).addClass('success')
        console.log(mission)
        $("#btn_select_mission").hide()
        #socket.emit('propose_mission', mission)

    $("#btn_quest").on 'click', () ->
        if $("#quest").is(":visible")
            $("#btn_quest").text("Go on a Quest")
        else
            $("#btn_quest").text("Cancel Quest")
        $("#quest").toggle()

    $("#btn_submitquest").on 'click', (e) ->
        quest_card = $("input[name=quest]:checked").val()
        console.log quest_card
        $("input[name=quest]").button('reset')
        $("#btn_quest").text("Go on a Quest")
        $("#quest").toggle()

select_for_mission = (li) ->
    if $("#btn_select_mission").is(":visible")
        input = $(li.children(":input")[0])
        if li.hasClass("active")
            li.removeClass("active")
            input.attr(value: 0)
        else
            li.addClass("active")
            input.attr(value: 1)
