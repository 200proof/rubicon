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
            @@active_sessions = {}

            #set :sass_dir, "../"
            set :root, File.dirname(__FILE__)

            use Rack::Session::Cookie,
                key: "Rubicon.WebUI",
                path: "/",
                secret: Rubicon.web_ui_config["session_secret"]

            register Sinatra::Flash
            register Sinatra::Async
        end

        helpers do
            # The config set in the config file passed to Rubicon on startup
            def configuration
                Rubicon.web_ui_config
            end

            # Validates a user's credentials and logs them in if appropriate
            def authenticate_user!(username, password)
                if configuration["users"].include? ({"name"=>username, "password"=>password})
                    flash[:success] = "Logged in successfully!"
                    session[:username] = username
                    @@active_sessions[session[:username]] = session[:session_id]

                    current_user
                else
                    flash[:error] = "Invalid username or password!"
                    nil
                end
            end

            # Logs out a user
            def logout_user!
                if current_user
                    @@active_sessions.delete session[:username]
                    session[:username] = nil
                    flash[:success] = "Logged out successfully!"
                end
            end

            # Gets the current user's username if the user is logged in
            def current_user
                if @@active_sessions[session[:username]] == session[:session_id]
                    session[:username]
                else
                    nil
                end
            end

            # Renders any messages in the session flash hash in a bootstrap-friendly manner
            def flash_messages(key=:flash)
                return "" if flash(key).empty?
                id = (key == :flash ? "flash" : "flash_#{key}")
                messages = flash(key).collect { |message|
                    "<div class='alert alert-#{message[0]}'>#{message[1]}<button type='button' class='close' data-dismiss='alert'><i class='icon-remove-sign'></i></button></div>\n"
                }
                "<div id='#{id}'>\n" + messages.join + "</div>"
            end

            # Defers rendering operations in asynchronous requests (i.e., aget, apost, etc.) to
            # avoid blocking the reactor leading to deadlocks. (server.send_request is a blocking operation)
            def threaded_render (&block)
                EventMachine.defer block, proc { |result| body result }
            end

            # Because we dont keep our stylesheets in views/ like good boys
            def sass(template, *args)
                template = :"../stylesheets/#{template}" if template.is_a? Symbol
                super(template, *args)
            end

            # Recursively concatenates CoffeeScript files via a `#include "filename"` mechanism
            #
            # Basically a poor man's Sprockets
            def concatenate_coffeescript(filename, already_included=[])
                file_path = File.expand_path("#{filename}.coffee", "#{settings.root}/javascripts/")
                file      = File.new(file_path, "r")
                base_path = File.dirname(file.path)
                contents  = file.read

                already_included << file_path

                contents.gsub(/\#include\s+"([^"]+)"/) do |match|
                    full_include_path = File.expand_path($1, base_path)

                    unless already_included.include? "#{full_include_path}.coffee"
                        concatenate_coffeescript(full_include_path, already_included) 
                    else
                        Rubicon.logger("WebUI").warn "Already #include'd `#{full_include_path}.coffee`! (in #{filename}.coffee)"
                        match
                    end
                end
            end
        end

        # Enforce login on non-assets and login page
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
            sass params[:name].to_sym, Compass.sass_engine_options
        end

        get "/javascripts/:name.js" do
            filename = params[:name]

            content_type 'text/javascript', :charset => 'utf-8'
            coffee concatenate_coffeescript(filename)
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