class ServerModel
    constructor: () ->
        self = @
        @teams = ko.observableArray()
        @targetScore = ko.observable 0
        @players = ko.observable {}

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
                    ret.push player
                else
                    player = new PlayerModel(playerJSON, team)
                    @players()[playerJSON.name] = player
                    ret.push player

            @players.valueHasMutated()
            return ret


        # Have to explicitly name window.ServerState as bootstrap's typeahead
        # doesn't set `this` properly
        @playerNames = ->
            Object.keys(window.ServerState.players())

class PlayerModel
    constructor: (json, team) ->
        @name   = ko.observable json.name
        @guid   = ko.observable json.guid
        @rank   = ko.observable json.rank
        @kills  = ko.observable json.kills
        @deaths = ko.observable json.deaths
        @score  = ko.observable json.score
        @team   = ko.observable team
        @squad  = ko.observable json.squad

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
            allEmpty = true

            for team in @teams()
                if team.players().length != 0
                    allEmpty = false
                    break

            !allEmpty
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
            height = $(".tab-pane#log > table").height()
            scroll = $(".tab-pane#log").scrollTop()
            tolerance = $(".tab-pane#log").height() + 50

            if ((height - scroll) < tolerance || forceScroll == true)
                $(".tab-pane#log").scrollTop(height)

            return

        @addLogItem = (msg) ->
            @logItems.shift() if @logItems().length > 350
            @logItems.push (msg)

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
            $.getJSON "#{window.APIPath}/ban-list", (json) ->
                window.BanListVM.entries.push(new BanModel(entry)) for entry in json
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

setupSSE = ->
    window.EventStream = new EventSource "#{window.APIPath}/stream"

    EventStream.addEventListener "log", (event) ->
        logMessage = $.parseJSON(event.data)
        logMessage["colorCode"] = "info"
        window.LogVM.addLogItem(logMessage) #checkme
        return
    , false

    EventStream.addEventListener "event", (event) ->
        logMessage = $.parseJSON(event.data)
        logMessage["colorCode"] = ""
        window.LogVM.addLogItem(logMessage) #checkme
        return
    , false

    EventStream.addEventListener "scoreboard", (event) ->
        scoreboard = $.parseJSON(event.data)
        window.ServerState.updateScoreboard(scoreboard)
        return
    , false

    EventStream.addEventListener "team_scores", (event) ->
        teamScores = $.parseJSON(event.data)
        window.ServerState.updateTeamScores(teamScores)
        return
    , false

$ ->
    window.APIPath = "#{window.location.pathname}/api"

    window.ServerState = new ServerModel()
    window.LogVM = new LogViewModel()
    window.ScoreboardVM = new ScoreboardViewModel()
    window.BanListVM = new BanListViewModel()

    setupSSE()

    ko.applyBindings
        "logStream": window.LogVM,
        "scoreboard": window.ScoreboardVM
        "banList": window.BanListVM

    $("a[data-target=#log]").on "shown", ->
        window.LogVM.stickyAutoscroller(true)

    $("a[data-target=#ban-list]").on "shown", ->
        window.BanListVM.refreshEntries()

    $("input.player-name").typeahead
        source: window.ServerState.playerNames

    return
