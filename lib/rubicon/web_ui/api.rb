# This file gets loaded by web_ui.rb and is evaluated in the context of
# Rubicon::WebUI::WebUIApp

get "/:server_name/api/stream" do
    if server = Rubicon.servers[params[:server_name]]
        sse_stream do |stream|
            server.add_web_stream(stream)
            stream.callback { server.remove_web_stream(stream) }
        end
    else
        error 404
    end
end

aget "/:server_name/api/ban-list" do
    if server = Rubicon.servers[params[:server_name]]
        threaded_render { JSON.generate server.ban_list }
    else
        error 404
    end 
end

apost "/:server_name/api/ban-list" do
    if server = Rubicon.servers[params[:server_name]]
    else
        error 404
    end 
end

aget "/:server_name/api/reserved-slots" do
    if server = Rubicon.servers[params[:server_name]]
        threaded_render { JSON.generate server.reserved_slots }
    else
        error 404
    end 
end

apost "/:server_name/api/say" do
    if server = Rubicon.servers[params[:server_name]]
        message  = params[:message]
        audience = params[:audience].split " "
        yell     = (params[:yell] == "true")

        words    = []

        if yell
            words += ["admin.yell", message, 20]
        else
            words += ["admin.say", message]
        end

        words += audience

        threaded_render { server.send_request(*words).read_word }
    else
        error 404
    end 
end