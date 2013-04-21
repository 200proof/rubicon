class ChatViewModel
    constructor: ->
        self = @
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

        @sendChat = (message, audience, yell) ->
            requestObject = 
                message: message,
                audience: audience
                yell: yell

            return if message == ""

            $("#chat-form :input, input[name=send-player-message]").attr("disabled", true)

            $.post "#{window.APIPath}/say", requestObject, (response) ->
                $("input[name=message], input[name=send-player-message]").val("")
                $("#chat-form :input, input[name=send-player-message]").attr("disabled", false)

                if yell
                    window.ServerState.addChatMessage
                        "time": new Date(),
                        "player": "Server",
                        "audience": "#{audience} <YELL>",
                        "colorCode": window.ChatVM.colorForAudience[audience],
                        "message": message


            return

        @sendChatFromForm = (yell) ->
            message  = $("input[name=message]").val()
            audience = $("select[name=audience]").val()
            
            self.sendChat message, audience, yell

        @sendChatFromPlayerForm = (yell) ->
            message  = $("input[name=send-player-message]").val()
            audience = "player #{window.ScoreboardVM.currentModalUser().name()}"
            
            self.sendChat message, audience, yell

        @hookEvents = ->
            $("a[data-target=#chat]").on "shown", ->
                self.stickyAutoscroller(true)
                return

            $("#chat-form > *").bind "keypress", (e) ->
                if (e.which == 13) # 13 == enter
                    self.sendChatFromForm(e.ctrlKey)

                return true

            $("#scoreboard-player-modal").on "keypress", "input[name=send-player-message]", (e) ->
                if (e.which == 13) # 13 == enter
                    self.sendChatFromPlayerForm(e.ctrlKey)

                return true

            return

    # using bootstrap colors because #yolo
    colorForAudience: {
        "all"  : "",
        "squad": "success",
        "team" : "info"
    }