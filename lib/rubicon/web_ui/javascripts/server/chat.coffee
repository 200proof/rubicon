class ChatViewModel
    constructor: (serverState) ->
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

        @sendChatFromForm = (yell) ->
            message  = $("input[name=message]").val()
            audience = $("select[name=audience]").val()
            
            serverState.sendChat message, audience, yell

        @hookEvents = ->
            $("a[data-target=#chat]").on "shown", ->
                self.stickyAutoscroller(true)
                return

            $("#chat-form > *").bind "keypress", (e) ->
                if (e.which == 13) # 13 == enter
                    self.sendChatFromForm(e.shiftKey)

                return true

            return

    # using bootstrap colors because #yolo
    colorForAudience: {
        "all"  : "",
        "squad": "success",
        "team" : "info"
    }