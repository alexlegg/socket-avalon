socket = io.connect('http://' + document.domain)
socket.on 'connect', (data) ->
    console.log(data)
    console.log("connected")

GAME_LOBBY      = 0
GAME_PROPOSE    = 1
GAME_VOTE       = 2
GAME_QUEST      = 3
GAME_FINISHED   = 4

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
    if game.state == GAME_LOBBY
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

        #Draw the list of players
        me = game.players[game.me]
        $("#players").empty()
        for p in game.players
            li = $("<li>")
                .addClass("list-group-item")
                .text(p.name)

            icons = $("<span>")
                .addClass("pull-right")
                .attr(style : "font-size: 16px;")

            #Add an icon to the leader
            if game.currentLeader == p.id
                icons.append('\u2654')

            if game.state == GAME_VOTE
                currVote = game.votes[game.votes.length - 1]

                #Add an icon to proposed team members
                if p.id in currVote.team
                    icons.append('\u2694')
                    li.addClass("success")

                #Add an icon for votes
                for v in currVote.votes
                    if p.id == v.id
                        voteicon = if v.vote then '\u2714' else '\u2715'
                        icons.append(voteicon)

            #Make players selectable for the leader (to propose quest)
            if game.state == GAME_PROPOSE && game.currentLeader == me.id
                mission = game.missions[game.currentMission]
                window.mission_max = mission.numReq #FIXME global var :(
                li.on 'click', (e) ->
                    select_for_mission(mission.numReq, $(e.target))
                input = $("<input>").attr
                    type    : 'hidden'
                    name    : p.id
                    value   : 0
                li.append(input)

            li.append(icons)
            $("#players").append(li)

        #Make quest proposal button visible to leader
        if game.state == GAME_PROPOSE && game.currentLeader == me.id
            $("#btn_select_mission").show()
            $("#leaderinfo").show()
        else
            $("#btn_select_mission").hide()
            $("#leaderinfo").hide()

        console.log game.state
        if game.state == GAME_VOTE
            $("#vote").show()
        else
            $("#vote").hide()

        #Draw the hidden info box
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
        sel = []
        $("#players li").each () ->
            input = $($(this).children(":input")[0])
            if input.val() == '1'
                mission.push parseInt(input.attr('name'))
                sel.push $(this)

        if mission.length == window.mission_max
            $("#btn_select_mission").hide()
            for s in sel
                s.removeClass('active')
                s.addClass('success')
            socket.emit('propose_mission', mission)
        else
            #TODO: Clean this up after successful submit
            $("#leaderinfo").html("You must select only <b>" + window.mission_max + "</b> players for the quest!")

    $("#btn_quest").on 'click', () ->
        if $("#quest").is(":visible")
            $("#btn_quest").text("Go on a Quest")
        else
            $("#btn_quest").text("Cancel Quest")
        $("#quest").toggle()

    $("#btn_submitvote").on 'click', (e) ->
        vote = $("input[name=vote]:checked").val() == "approve"
        $("input[name=vote]").button('reset')
        $("#vote").hide()
        #TODO: prevent submitting without selecting either option
        socket.emit('vote', vote)

    $("#btn_submitquest").on 'click', (e) ->
        quest_card = $("input[name=quest]:checked").val()
        console.log quest_card
        $("input[name=quest]").button('reset')
        $("#btn_quest").text("Go on a Quest")
        $("#quest").hide()


select_for_mission = (mission_max, li) ->
    if $("#btn_select_mission").is(":visible")

        #Get how many already selected
        mission_count = 0
        $("#players li").each () ->
            input = $($(this).children(":input")[0])
            mission_count += 1 if input.val() == '1'

        #Toggle players if it won't exceed mission maximum
        input = $(li.children(":input")[0])
        if li.hasClass("active")
            li.removeClass("active")
            input.attr(value: 0)
        else
            if mission_count + 1 <= mission_max
                li.addClass("active")
                input.attr(value: 1)
            else
                $("#leaderinfo").html("You must select only <b>" + window.mission_max + "</b> players for the quest!")
