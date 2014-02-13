formatDate = (d) ->
    d = new Date(d)
    d_names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    ampm = if (d.getHours() < 13) then "am" else "pm"
    h = d.getHours() % 12
    h = if h == 0 then 12 else h
    s = d_names[d.getDay()] + " " +
        d.getDate() + "/" +
        (d.getMonth() + 1) + "/" +
        d.getFullYear() + " " +
        h + ":" + d.getMinutes() + ampm

jQuery ->
    switch window.location.pathname
        when "/games"
            gamesReq = $.ajax
                url : '/api?type=games'

            gamesReq.done (res, status, jqXHR) ->
                if not res then return

                for r in res
                    li = $("<a>")
                        .addClass("list-group-item")
                        .prop("href", "/game?id=" + r.id)
                        .html($("<b>").text(formatDate(r.date)))
                        .append($("<br>"))
                        .append(r.name)
                    $("#gamelist").append(li)

        when "/game"
            gameReq = $.ajax
                url : '/api' + window.location.search + '&type=game'

            gameReq.done (res, status, jqXHR) ->
                console.log res
