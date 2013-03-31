require "sass"
require "compass"
require "coffee-script"
require "sinatra/flash"

module Rubicon::WebUI
    class WebUIApp < Sinatra::Base
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
        end

        before "/*" do
            exempt = /^(login|stylesheets\/.+|javascripts\/.+|__sinatra__)/
            unless exempt.match params[:splat].first
                redirect "/login" unless current_user
            end
        end

        get "/stylesheets/:name.css" do
            content_type 'text/css', :charset => 'utf-8'
            sass :"stylesheets/#{params[:name]}", Compass.sass_engine_options
        end

        get "/javascripts/:name.js" do
            filename = params[:splat].first

            content_type 'text/css', :charset => 'utf-8'
            coffee :"javascripts/#{params[:name]}"
        end

        get "/login" do
            erb :login
        end

        post "/login" do
            if authenticate_user!(params[:login]["username"], params[:login]["password"])
                redirect "/"
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
    end
end