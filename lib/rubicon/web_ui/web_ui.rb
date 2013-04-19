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
                    flash[:success] = "Logged in successfully!"
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
                messages = flash(key).collect { |message|
                    "<div class='alert alert-#{message[0]}'>#{message[1]}<button type='button' class='close' data-dismiss='alert'><i class='icon-remove-sign'></i></button></div>\n"
                }
                "<div id='#{id}'>\n" + messages.join + "</div>"
            end

            def threaded_render (&block)
                EventMachine.defer block, proc { |result| body result }
            end
        end

        before "*" do
            path = params[:splat].first
            exempt = /^\/(login|stylesheets\/.+|javascripts\/.+|__sinatra__)/
            unless current_user || exempt.match(path)
                # Some browsers *cough* mobile *cough* like to request favicon/touch icons, which ends up
                # overwriting the session's redirect_to, so ignore any images as well as a redirect to '/login'
                session[:redirect_to] = path unless (path == "/login" || path.match(/\.(jpg|png|ico|gif)$/))
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
            if current_user
                redirect '/'
            else
                status 401
                erb :login
            end
        end

        post "/login" do
            if authenticate_user!(params[:login]["username"], params[:login]["password"])
                redirect_dest = session[:redirect_to] || "/"
                session[:redirect_to] = nil

                redirect redirect_dest
            else
                flash[:error] = "Invalid username or password!"
                status 401
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

        get "/:server_name" do
            if server = Rubicon.servers[params[:server_name]]
                erb :server, locals: {server: server} 
            else
                error 404
            end
        end

        # API has been seperated into its own module for great justice
        class_eval File.read(File.expand_path("../api.rb", __FILE__))
    end
end