require "digest/md5"

module Rubicon::Frostbite::BF3
    class Server
        require 'rubicon/frostbite/bf3/signal_handlers'
        require 'rubicon/frostbite/bf3/event_handlers'

        attr_reader :connection, :settings, :permissions_manager
        attr_accessor :name, :players, :max_players, :game_mode,
            :current_map, :rounds_played, :rounds_total, :scores,
            :score_target, :online_state, :ranked, :punkbuster,
            :has_password, :uptime, :round_time, :ip,
            :punkbuster_version, :join_queue, :region,
            :closest_ping_site, :country, :matchmaking,
            :teams, :plugin_manager

        # TODO: refactor @config and @settings to be less
        # confusing
        def initialize(connection, config_object, logger)
            @connection = connection
            @config = config_object 
            @settings = Rubicon::Util::ConfigManager.new(config_object[:settings_file])
            @permissions_manager = Rubicon::Util::PermissionsManager.new(@settings["permissions"] || {})

            @logger = logger

            @teams = []

            # 0 = neutral, 16 possible teams
            17.times do |idx|
                @teams[idx] = Team.new(self, idx)
            end
        end

        # Called when successfully connected to a BF3 RCON server
        def connected
            @players = PlayerCollection.new(self)

            logger.debug { "Connected to a BF3 server!" }

            process_signal(:refresh_server_info)

            logger.info { "Connected to #{@name}!" }

            if !attempt_login
                logger.fatal { "Failed to log in!" }
                return false
            end

            Rubicon.message_channels[@config[:name]] = @connection.message_channel

            process_signal(:refresh_scoreboard)

            @plugin_manager = Rubicon::PluginManager.new(self)
            @connection.send_command "admin.eventsEnabled", "true"

            return true
        end

        # Attempts to log in using a hashed password
        def attempt_login
            salt_packet = @connection.send_request("login.hashed")
            
            salt = salt_packet.words[1]
            result = @connection.send_request("login.hashed", hash_password(salt))

            result.response == "OK"
        end

        # Hashes a password given a HexString-encoded salt
        def hash_password(salt)
            salt = [salt].pack("H*")
            salted_password = salt + @config[:password]
            Digest::MD5.hexdigest(salted_password).upcase
        end

        # Process signals and events
        def start_event_pump
            while message = @connection.message_channel.receive
                command, *args = message
                p args if command == :test
                if (command.is_a? Rubicon::Frostbite::RconPacket)
                    process_event(command)
                elsif (command.is_a? Symbol)
                    if (command == :shutdown)
                        shutdown!
                        break
                    end
                    process_signal(command, *args)
                else
                    logger.warn("Discarding unknown message: #{message}")
                end
            end
            logger.debug { "Event pump stopped. Shutting down like a boss."}
        end

        def shutdown!
            @connection.close_connection
        end

        def process_signal(signal, *args)
            if @@signal_handlers[signal]
                @@signal_handlers[signal].call(self, *args)
            else
                logger.warn { "No handler for signal #{signal}" }
            end
        end

        def process_event(event)
            if @@event_handlers[event.words[0]]
                begin
                    @@event_handlers[event.words[0]].call(self, event)
                rescue Exception => e
                    logger.error { "Exception processing event #{event.words[0]}" }
                    logger.error { "Offending packet: #{event.inspect}"}
                    logger.error { "Exception in plugin: #{e.message} (#{e.class})" }
                    logger.error (e.backtrace || [])[0..10].join("\n")
                end
            else
                logger.warn { "No handler for packet #{event.words[0]}" }
            end
        end  

        def logger(progname="BF3Server")
            @logger.with_progname(progname)
        end   
    end

    # Registers our server state manager
    Rubicon::Frostbite::RconClient::game_handlers["BF3"] = Server
end