class PlayerModalViewModel
    constructor: (serverState) ->
        self = @
        @serverState           = serverState
        @currentModalPlayer    = ko.observable()
        @currentSubmodalAction = ko.observable()

        @openPlayerModal = (user) ->
            self.currentModalPlayer(user)
            self.currentSubmodalAction(undefined)
            return

        @closePlayerModal = ->
            self.currentModalPlayer(undefined)
            self.closeSubmodal()
            return

        @stickyAutoscroller = (forceScroll) ->
            height = $("#modal-chat-table > table").height()
            scroll = $("#modal-chat-table").scrollTop()
            tolerance = $("#modal-chat-table").height() + 50

            if ((height - scroll) < tolerance || forceScroll == true)
                $("#modal-chat-table").scrollTop(height)

        @hookEvents = ->
            $("a[data-target=#modal-chat]").on "shown", ->
                self.stickyAutoscroller(true)
                return

            $("#player-modal").on "keypress", "input[name=send-player-message]", (e) ->
                if (e.which == 13) # 13 == enter
                    self.sendChat(e.shiftKey)

                return true

            $("#player-modal").on "change", "input[name=player-ban-is-permanent]", (e) ->
                targetElement = $("#player-ban-timeout-group")

                if @checked
                    targetElement.addClass "hide"
                else
                    targetElement.removeClass "hide"

                return true

            $(document).on "keyup", "#player-modal", (e) ->
                if (e.which == 27) # 27 == escape
                    if ($("#player-action-submodal").is(":visible"))
                        self.closeSubmodal()
                    else
                        self.closePlayerModal()
                    
                return true

            # Remove the submodal option text and backdrop only after the hide animation completes
            $("#player-modal").on "hide", "#player-action-submodal", (e) ->
                self.currentSubmodalAction(undefined)
                $("#player-action-submodal-backdrop").removeClass("in")
                return

            return

        @sendChat = (yell) ->
            message  = $("input[name=send-player-message]").val()
            audience = "player #{self.currentModalPlayer().name()}"

            serverState.sendChat(message, audience, yell)

            self.stickyAutoscroller(true)
            return

        @actionCommitClass = ko.computed ->
            (
                "kill"    : "btn-inverse",
                "kick"    : "btn-warning",
                "ban"     : "btn-danger",
                undefined : "hide"
            )[self.currentSubmodalAction()]

        @actionCommitText = ko.computed ->
            if player = self.currentModalPlayer()
                name = " #{player.name()}"
            else 
                name = ""

            ({
                "kill": "Kill",
                "kick": "Kick",
                "ban" : "Ban"
            })[self.currentSubmodalAction()] + name

        @openSubmodal = (action) ->
            self.currentSubmodalAction(action)
            $("#modal-player-actions").fadeOut()
            $("#player-action-submodal").subModal('show')
            $("#player-action-submodal-backdrop").removeClass("hide")
            $("#player-action-submodal-backdrop").addClass("in")
            return

        @closeSubmodal = ->
            $("#player-action-submodal").subModal('hide')
            $("#player-action-submodal-backdrop").addClass("hide")
            $("#modal-player-actions").fadeIn()

            return

        @performSubmodalAction = (action) ->
            name          = self.currentModalPlayer().name()
            requestObject = 
                "reason": $("input[name=player-action-reason]").val()

            switch self.currentSubmodalAction()
                when "kill"
                    serverState.lockInputs()
                    $.post "#{window.APIPath}/kill/#{name}", requestObject, (response) ->
                        serverState.unlockInputs(true)
                        self.closeSubmodal()

                when "kick"
                    serverState.lockInputs()
                    $.post "#{window.APIPath}/kick/#{name}", requestObject, (response) ->
                        serverState.unlockInputs(true)
                        self.closePlayerModal()

                when "ban"
                    serverState.lockInputs()

                    idType = $("select[name=player-ban-id-type]").val()

                    if idType == "guid"
                        id = self.currentModalPlayer().guid()
                        requestObject["reason"] = "(#{name}) #{requestObject["reason"]}"
                    else
                        id = name

                    isPermaban = $("input[name=player-ban-is-permanent]").is(":checked")

                    if isPermaban
                        requestObject["timeout_type"] = "perm"
                    else
                        timeoutLength = $("input[name=player-ban-timeout]").val()
                        timeoutFactor = $("select[name=player-ban-timeout-factor]").val()

                        if timeoutFactor == "rounds"
                            requestObject["timeout_length"] = timeoutLength
                            requestObject["timeout_type"]   = "rounds"
                        else
                            requestObject["timeout_type"]   = "seconds"
                            requestObject["timeout_length"] = timeoutLength * timeoutFactor
                            
                    $.ajax
                        method:  "PUT"
                        url:     "#{window.APIPath}/ban-list/#{idType}/#{id}"
                        data:    requestObject
                        success: (data) ->
                            console.log data
                            serverState.unlockInputs(true)
                            self.closePlayerModal()
            return
