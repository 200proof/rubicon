class ServerModel
    constructor: () ->
        self = @
        @teams = ko.observableArray()
        @targetScore = ko.observable 0
        @players = ko.observable {}
        @loadedAtLeastOnce = ko.observable false

        @teams.push(new TeamModel(team_num, [], 0)) for team_num in [0..16]

        @updateScoreboard = (json) ->
            for teamObject in json
                team = @teams()[teamObject.id]

                if teamObject.players.length == 0
                    # I have no idea why the neutral team is retaining at least one player....
                    # unless I manually do this :/
                    team.players([])
                else
                    team.players(@updateOrCreatePlayers(teamObject.players, team))

                team.players.sort (a, b) ->
                    b.score() - a.score()

                @teams.valueHasMutated()

        @updateTeamScores = (json) ->
            targetScore = json.target
            for score, index in json.scores
               team = @teams()[index]
               team.score(score)
               team.targetScore(targetScore) if team.targetScore() != targetScore
            
            @teams.valueHasMutated()

        @updateOrCreatePlayers = (playerObjects, team) ->
            ret = []
            for playerJSON in playerObjects
                player = @players()[playerJSON.name]

                if player
                    player.update(playerJSON, team)
                else
                    player = new PlayerModel(playerJSON, team)
                    @players()[playerJSON.name] = player

                ret.push player

            @players.valueHasMutated()
            return ret

        @addChatMessage = (json) ->
            msg = {
                "time": json.time,
                "player": json.player,
                "audience": json.audience,
                "colorCode": window.ChatVM.colorForAudience[json.audience],
                "message": json.message
            }
            window.ChatVM.addItem(msg)

            return if json.player == "Server"

            @players()[json.player].addChatMessage(msg)

        @playerNames = ->
            Object.keys(self.players())

class PlayerModel
    constructor: (json, team) ->
        @name     = ko.observable json.name
        @guid     = ko.observable json.guid
        @rank     = ko.observable json.rank
        @kills    = ko.observable json.kills
        @deaths   = ko.observable json.deaths
        @score    = ko.observable json.score
        @team     = ko.observable team
        @squad    = ko.observable json.squad
        @messages = ko.observableArray([])

        @update = (json, team) ->
            @name(json.name)
            @guid(json.guid)
            @rank(json.rank)
            @kills(json.kills)
            @deaths(json.deaths)
            @score(json.score)
            if @team().id() != team.id()
                @team().players.remove(@)
                @team(team)
            @squad(json.squad)
            return

        @addChatMessage = (msg) ->
            @messages.push msg
            return


class TeamModel
    constructor: (id, players, targetScore) ->
        @id = ko.observable id
        @players = ko.observableArray()
        @score = ko.observable 0
        @targetScore = ko.observable(targetScore)

        @players.push new PlayerModel(player, @) for player in players

        @progressBarWidth = ko.computed ->
            widthPercentage = (@score()/@targetScore()) * 100
            "#{widthPercentage}%"
        , @

        @hasPlayers = ko.computed ->
            @players().length > 0
        , @

class ScoreboardViewModel
    constructor: ->
        self = @
        @targetScore = window.ServerState.targetScore
        @teams = window.ServerState.teams

        @hasPlayers = ko.computed ->
            for team in @teams()
                if team.players().length != 0
                    return true

            false
        , @

        @nonNeutralTeams = ko.computed ->
            self.teams()[1..16]

        @neutralPlayers = ko.computed ->
            self.teams()[0]

        @hasNeutralPlayers = ko.computed ->
            self.neutralPlayers().players().length > 0

        @currentModalUser = ko.observable()

        @openUserModal = (user) ->
            self.currentModalUser(user)
            return

        @closeUserModal = ->
            self.currentModalUser(undefined)
            return

        @highlightSquadmates = (player) ->
            $("#team-#{player.team().id()} .squad-#{player.squad()}").addClass("squad-highlight")
            return

        @removeSquadmateHighlights = (player) ->
            $("#team-#{player.team().id()} .squad-#{player.squad()}.squad-highlight").removeClass("squad-highlight")
            return

class LogViewModel
    constructor: ->
        @logItems = ko.observableArray()

        @stickyAutoscroller = (forceScroll) ->
            height = $("#log-table > table").height()
            scroll = $("#log-table").scrollTop()
            tolerance = $("#log-table").height() + 50

            if ((height - scroll) < tolerance || forceScroll == true)
                $("#log-table").scrollTop(height)
            return

        @addLogItem = (msg) ->
            @logItems.shift() if @logItems().length > 350
            @logItems.push(msg)

class ChatViewModel
    constructor: ->
        @messages = ko.observableArray()

        @stickyAutoscroller = (forceScroll) ->
            height = $("#chat-table > table").height()
            scroll = $("#chat-table").scrollTop()
            tolerance = $("#chat-table").height() + 50

            if ((height - scroll) < tolerance || forceScroll == true)
                $("#chat-table").scrollTop(height)

            return

        @addItem = (msg) ->
            @messages.shift() if @messages().length > 350
            @messages.push(msg) 
            return

        @sendChat = (yell) ->
            requestObject = 
                message: $("input[name=message]").val(),
                audience: $("select[name=audience]").val(),
                yell: yell

            $("#chat-form :input").attr("disabled", true)

            $.post "#{window.APIPath}/say", requestObject, (response) ->
                $("input[name=message]").val("")
                $("#chat-form :input").attr("disabled", false)

            return

    # using bootstrap colors because #yolo
    colorForAudience: {
        "all"  : "",
        "squad": "success",
        "team" : "info"
    }

class BanModel
    constructor: (json) ->
        prefixes = {
            "name": "Name",
            "ip": "IP Address",
            "guid": "GUID"
        }

        @json = json
        @reason = ko.observable json.reason

        @id = ko.computed ->
            "#{prefixes[@json.id_type]}: #{@json.id}"
        , @

        @expires = ko.computed ->
            switch @json.ban_type
                when "perm"
                    "Never"
                when "seconds"
                    expiry = new Date(Date.now() + (@json.seconds_left*1000))
                    "#{expiry.toRelativeTime()}"
                when "rounds"
                    "in #{@json.rounds_left} rounds"
        , @


class BanListViewModel
    constructor: ->
        self = @
        @entries = ko.observableArray([])
        @refreshEntries = ->
            self.entries([])
            $("#ea-ban-list .loading-row").show()
            $.getJSON "#{window.APIPath}/ban-list", (json) ->
                self.entries.push(new BanModel(entry)) for entry in json
                $("#ea-ban-list .loading-row").hide()
                return

        @currentModalBan = ko.observable()
        @openBanModal = (banEntry) ->
            self.currentModalBan(banEntry)
            return

        @closeBanModal = ->
            self.currentModalBan(undefined)
            return

        @removeBan = (ban) ->
            console.log "Undo a ban here, yeah?"
            console.log ban
            self.closeBanModal()
            return

class ReservedListViewModel
    constructor: ->
        self = @
        @entries = ko.observableArray([])
        @refreshEntries = ->
            self.entries([])
            $("#reserved-list .loading-row").show()
            $.getJSON "#{window.APIPath}/reserved-slots", (json) ->
                $("#reserved-list .loading-row").hide()
                self.entries(json)
                return

        @currentModalSlot = ko.observable()
        @openRemoveModal = (username) ->
            self.currentModalSlot(username)
            return

        @closeRemoveModal = ->
            self.currentModalSlot(undefined)
            return

        @removeSlot = (name) ->
            $.ajax
                method:  "DELETE"
                url:     "#{window.APIPath}/reserved-slots/#{name}"
                success: (e) ->
                    self.refreshEntries()
                    return

            self.closeRemoveModal()
            return

        @addSlot = (inputField) ->
            name = inputField.value

            $(inputField).attr "disabled", true
            $(inputField).val("Adding #{name}...")

            $.ajax
                method:  "PUT"
                url:     "#{window.APIPath}/reserved-slots/#{name}"
                success: (e) ->
                    $(inputField).attr "disabled", false
                    $(inputField).val ""
                    self.refreshEntries()
                    return

            return

setupSSE = ->
    window.EventStream = new EventSource "#{window.APIPath}/stream"

    EventStream.addEventListener "log", (event) ->
        logMessage = $.parseJSON(event.data)
        logMessage["colorCode"] = "info"
        window.LogVM.addLogItem(logMessage)
        return
    , false

    EventStream.addEventListener "event", (event) ->
        logMessage = $.parseJSON(event.data)
        logMessage["colorCode"] = ""
        window.LogVM.addLogItem(logMessage)
        return
    , false

    EventStream.addEventListener "scoreboard", (event) ->
        scoreboard = $.parseJSON(event.data)
        window.ServerState.updateScoreboard(scoreboard)
        window.ServerState.loadedAtLeastOnce(true)
        return
    , false

    EventStream.addEventListener "team_scores", (event) ->
        teamScores = $.parseJSON(event.data)
        window.ServerState.updateTeamScores(teamScores)
        return
    , false

    EventStream.addEventListener "chat", (event) ->
        messageInfo = $.parseJSON(event.data)
        window.ServerState.addChatMessage(messageInfo)
        return
    , false

$ ->
    window.APIPath = "#{window.location.pathname}/api"

    window.ServerState    = new ServerModel()
    window.LogVM          = new LogViewModel()
    window.ChatVM         = new ChatViewModel()
    window.ScoreboardVM   = new ScoreboardViewModel()
    window.BanListVM      = new BanListViewModel()
    window.ReservedListVM = new ReservedListViewModel()

    setupSSE()

    ko.applyBindings
        "logStream":    window.LogVM,
        "chatMessages": window.ChatVM,
        "scoreboard":   window.ScoreboardVM,
        "banList":      window.BanListVM,
        "reservedList": window.ReservedListVM

    $(".loading-row").toggle()

    $("a[data-target=#log]").on "shown", ->
        window.LogVM.stickyAutoscroller(true)

    $("a[data-target=#ban-list]").on "shown", ->
        window.BanListVM.refreshEntries()

    $("a[data-target=#reserved-list]").on "shown", ->
        window.ReservedListVM.refreshEntries()

    $("input.player-name").typeahead
        source: window.ServerState.playerNames

    $("#chat-form > *").bind "keypress", (e) ->
        if (e.which == 13) # 13 == enter
            if e.ctrlKey
                window.ChatVM.sendChat true
            else
                window.ChatVM.sendChat false

        return true

    $("input[name=new-slot-name]").bind "keypress", (e) ->
        window.ReservedListVM.addSlot(e.target) if (e.which == 13)

    return
