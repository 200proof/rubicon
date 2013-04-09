ko.bindingHandlers['modal'] = 
    init: (element, valueAccessor, allBindingsAccessor) ->
        $(element).addClass("hide modal")
        
        if allBindingsAccessor().modalOptions
            if allBindingsAccessor().modalOptions.beforeClose
                $(element).on 'hide', allBindingsAccessor().modalOptions.beforeClose


        ko.bindingHandlers['with'].init.apply(@, arguments)

    update: (element, valueAccessor) ->
        value = ko.utils.unwrapObservable(valueAccessor())
        ret   = ko.bindingHandlers['with'].update.apply(@, arguments)

        if value
            $(element).modal 'show'
        else
            $(element).modal 'hide'

        ret 
