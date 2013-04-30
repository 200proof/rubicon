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

            audience_words = json.audience.split " "
            if audience_words[0] == "player"
                @players()[audience_words[1]].addChatMessage(msg)

            # We should add the message to the per-player chat log, but not
            # to the "Server" player (since we don't have one)
            return if json.player == "Server"

            @players()[json.player].addChatMessage(msg)

        @playerNames = ->
            Object.keys(self.players())

        @sendChat = (message, audience, yell) ->
            requestObject = 
                message: message,
                audience: audience
                yell: yell

            return if message == ""

            self.lockInputs()
            $.post "#{window.APIPath}/say", requestObject, (response) ->
                self.unlockInputs(true)

                if yell
                    window.ServerState.addChatMessage
                        "time": new Date(),
                        "player": "Server",
                        "audience": "#{audience} <YELL>",
                        "colorCode": window.ChatVM.colorForAudience[audience],
                        "message": message


            return

        @lockInputs = ->
            $("#chat-form :input, input[name=send-player-message]").attr("disabled", true)
            return

        @unlockInputs = (clear=false) ->
            $("#chat-form :input, input[name=send-player-message]").attr("disabled", false)
            $("input[name=message], input[name=send-player-message]").val("") if clear
            return



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