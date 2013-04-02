require "sass"
require "compass"
require "coffee-script"
require "sinatra/flash"
require "sinatra/sse"
require "sinatra/async"
require "json"

module Rubicon::WebUI
    class WebUIApp < Sinatra::Base
        include Sinatra::SSE

        configure do
            Compass.configuration do |config|
                config.project_path = File.dirname(__FILE__)
                config.sass_dir = 'views/stylesheets'
            end

            @@active_sessions = {}

            set :sass, Compass.sass_engine_options
            set :scss, Compass.sass_engine_options
            set :root, File.dirname(__FILE__)

            use Rack::Session::Cookie,
                key: "Rubicon.WebUI",
                path: "/",
                secret: Rubicon.web_ui_config["session_secret"]

            register Sinatra::Flash
            register Sinatra::Async
        end

        helpers do
            def configuration
                Rubicon.web_ui_config
            end

            def authenticate_user!(username, password)
                if configuration["users"].include? ({"name"=>username, "password"=>password})
                    session[:username] = username
                    @@active_sessions[session[:username]] = session[:session_id]
                else
                    flash[:error] = "Invalid username or password!"
                end
            end

            def logout_user!
                if current_user
                    @@active_sessions.delete session[:username]
                    session[:username] = nil
                    flash[:success] = "Logged out successfully!"
                end
            end

            def current_user
                if @@active_sessions[session[:username]] == session[:session_id]
                    session[:username]
                else
                    nil
                end
            end

            def flash_messages(key=:flash)
                return "" if flash(key).empty?
                id = (key == :flash ? "flash" : "flash_#{key}")
                messages = flash(key).collect {|message| "  <div class='alert alert-#{message[0]}'>#{message[1]}</div>\n"}
                "<div id='#{id}'>\n" + messages.join + "</div>"
            end

            def threaded_render (&block)
                result = nil
                Thread.new { result = block.call }

                deferred_poller = proc do
                    if result
                        body result
                    else
                        EventMachine.next_tick deferred_poller
                    end
                end

                EventMachine.next_tick deferred_poller
            end
        end

        before "*" do
            path = params[:splat].first
            exempt = /^\/(login|stylesheets\/.+|javascripts\/.+|__sinatra__)/
            unless exempt.match(path) || current_user
                session[:redirect_to] = path unless path == "/login"
                redirect "/login" 
            end
        end

        get "/stylesheets/:name.css" do
            content_type 'text/css', :charset => 'utf-8'
            sass :"stylesheets/#{params[:name]}", Compass.sass_engine_options
        end

        get "/javascripts/:name.js" do
            filename = params[:splat].first

            content_type 'text/javascript', :charset => 'utf-8'
            coffee :"javascripts/#{params[:name]}"
        end

        get "/login" do
            erb :login
        end

        post "/login" do
            if authenticate_user!(params[:login]["username"], params[:login]["password"])
                redirect_dest = session[:redirect_to] || "/"
                session[:redirect_to] = nil

                redirect redirect_dest
            else
                flash[:error] = "Invalid username or password!"
                erb :login
            end
        end

        get "/logout" do
            logout_user!
            redirect "/"
        end

        get "/" do 
            erb :home
        end

        aget "/:server_name" do
            if server = Rubicon.servers[params[:server_name]]
                threaded_render { erb :server, locals: {server: server} }
            else
                error 404
            end
        end

        get "/:server_name/api/logstream" do
            if server = Rubicon.servers[params[:server_name]]
                sse_stream do |stream|
                    server.add_web_logger(stream)
                    stream.callback { server.remove_web_logger(stream) }
                end
            else
                error 404
            end
        end

        aget "/:server_name/api/players" do
            if server = Rubicon.servers[params[:server_name]]
                threaded_render { JSON.generate server.players.to_hash }
            else
                error 404
            end 
        end

        get "/:server/api" do
            if server = Rubicon.servers[params[:server_name]]
                sse_stream do |stream|
                    server.add_web_logger(stream)
                    stream.callback { server.remove_web_logger(stream) }
                end
            else
                error 404
            end
        end
    end
end