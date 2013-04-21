class LogViewModel
    constructor: ->
        self = @
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

        @hookEvents = ->
            $("a[data-target=#log]").on "shown", ->
                self.stickyAutoscroller(true)
                return

            return