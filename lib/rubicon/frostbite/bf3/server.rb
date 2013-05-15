require "digest/md5"

module Rubicon::Frostbite::BF3
    class Server
        GAME_NAME = "bf3"

        require 'rubicon/frostbite/bf3/signal_handlers'
        require 'rubicon/frostbite/bf3/event_handlers'

        attr_reader :settings, :permissions_manager, :disconnected_players, :players, :web_streams
        attr_accessor :name, :max_players,
            :game_mode, :current_map, :rounds_played, :rounds_total, :scores,
            :score_target, :online_state, :ranked, :punkbuster, :has_password, 
            :uptime, :round_time, :ip, :punkbuster_version, :join_queue, :region,
            :closest_ping_site, :country, :matchmaking, :teams, :plugin_manager

        # TODO: refactor @config and @settings to be less
        # confusing
        def initialize(connection, config_object, logger)
            @connection = connection
            @config = config_object 
            @settings = Rubicon::Util::ConfigManager.new(config_object[:settings_file])
            @permissions_manager = Rubicon::Util::PermissionsManager.new(@settings["permissions"] || {})

            @logger = logger

            @teams = []

            @mutex = Mutex.new

            # 0 = neutral, 16 possible teams
            17.times do |idx|
                @teams[idx] = Team.new(self, idx)
            end
        end

        # Called when successfully connected to a BF3 RCON server
        def connected
            @players = PlayerCollection.new(self)
            @disconnected_players = {}
            @web_streams = []

            logger.debug { "Connected to a BF3 server!" }

            process_signal(:refresh_server_info)

            logger.info { "Connected to #{@name}!" }

            if !attempt_login
                logger.fatal { "Failed to log in!" }
                return false
            end

            Rubicon.servers[@config[:name]] = self

            process_signal(:refresh_scoreboard)
            
            @scoreboard_timer = Rubicon::Util::Timer.new (5) { message_channel.send :refresh_scoreboard }
            @scoreboard_timer.start!

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

        # Disables all plugins, saves config and closes the connection.
        def shutdown!
            @scoreboard_timer.stop
            Rubicon.servers.delete @config[:name]
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

        def say(msg)
            send_command("admin.say", msg, "all")
        end

        def yell(msg, duration=20)
            send_command("admin.yell", msg, duration, "all")
        end

        def logger(progname="BF3Server")
            @logger.with_progname(progname)
        end

        # Adds a web stream to the list of streams
        # to dispatch events to via `push_to_web_streams`
        def add_web_stream(stream)
            @web_streams << stream
            @logger.add_web_listener(stream)

            # queue up a scoreboard refresh ASAP
            message_channel.send :refresh_scoreboard
        end   

        # Removes a web stream from the list of streams
        # to dispatch events to via `push_to_web_streams`
        def remove_web_stream(stream)
            @web_streams.delete stream
            @logger.remove_web_listener(stream)
        end

        # Pushes an event to any web clients listening.
        def push_to_web_streams(event_name, data)
            @web_streams.each { |stream| stream.push event: event_name, data: JSON::dump(data) }
        end

        # The message channel from which this server processes
        # events and signals.
        def message_channel
            @connection.message_channel
        end

        # Sends a command to the server, ignoring any responses
        # to the command
        def send_command(*args)
            @connection.send_command(*args)
        end

        # Sends a request to the server, and blocks until a response
        # is received
        def send_request(*args)
            @connection.send_request(*args)
        end

        # Sends a request to the server, and returns a promise
        # whose value can be accessed via ~promise when it is
        # responded to. 
        def send_request!(*args)
            @connection.send_request!(*args)
        end

        # Gets a list of players who are banned on this server
        def ban_list
            all_bans = []
            last_offset = 0

            loop do
                packet = send_request("banList.list", last_offset)
                status = packet.read_word

                # every ban list entry has 6 words attached to it
                break if (status != "OK") || (packet.words_left == 0) || (packet.words_left % 6 != 0)
                until packet.words_left == 0
                    all_bans << {
                        id_type: packet.read_word,
                        id: packet.read_word,
                        ban_type: packet.read_word,
                        seconds_left: packet.read_word,
                        rounds_left: packet.read_word,
                        reason: packet.read_word
                    }
                    last_offset += 1
                end
            end
            all_bans
        end

        # Gets a list of players who have "VIP" status on the server (i.e., they get to
        # skip the queue or have someone kicked to make room for them if aggressive joining
        # is enabled on the server)
        def reserved_slots
            all_slots = []
            last_offset = 0
            loop do
                packet = send_request("reservedSlotsList.list", last_offset)
                status = packet.read_word

                # every ban list entry has 6 words attached to it
                break if (status != "OK") || (packet.words_left == 0)

                last_offset += packet.words_left
                all_slots += packet.remaining_words
            end

            all_slots
        end

        # Kicks `player_name`. If a reason is given, it is used instead of the
        # BF3 server's default of "Kicked by administrator."
        def kick_player(player_name, reason=nil)
            if reason && reason != ""
                send_request("admin.kickPlayer", player_name, reason).read_word
            else
                send_request("admin.kickPlayer", player_name).read_word
            end
        end

        # Kills `player_name`.
        def kill_player(player_name)
            send_request("admin.killPlayer", player_name).read_word
        end

        # Bans a player from the server.
        #
        # `id_type`       : Can be one of :name, :guid, or :ip
        # `id`            : Which name/guid/ip the ban applies to
        # `reason`        : The reason to tell the user. If this is left blank, the default is "Banned by admin"
        # `timeout_type`  : Can be :perm, :rounds, or :seconds. Defaults to :perm.
        # `timeout_length`: When the ban expires. If this is 0, the ban will be permanent regardless of `timeout_type`
        #
        # Returns the server's response to the command.
        def ban_player(id_type, id, reason=nil, timeout_type=:perm, timeout_length=0)
            raise "id_type must be one of :name, :guid, or :ip" unless [:name, :guid, :ip].include? id_type
            raise "timeout_type must be one of :perm, :rounds, :seconds" unless [:perm, :rounds, :seconds].include? timeout_type

            timeout_words = [timeout_type, timeout_length]
            if timeout_type == :perm || timeout_length == 0
                timeout_words = [:perm]
            end

            if reason && reason != ""
                send_request("banList.add", id_type, id, *timeout_words, reason).read_word
            else
                send_request("banList.add", id_type, id, *timeout_words).read_word
            end
        end

        # Unbans a player from the server.
        #
        # `id_type`: can be one of :name, :guid, or :ip
        # `id`     : which name/guid/ip to unban
        #
        # Returns the server's response to the command
        def unban_player(id_type, id)
            raise "id_type must be one of :name, :guid, or :ip" unless [:name, :guid, :ip].include? id_type

            send_request("banList.remove", id_type, id).read_word
        end

        # Adds a player to the reserved slot list
        #
        # `name`: the name of the player to add to the list
        #
        # Returns the server's response to the command
        def add_reserved_slot(name)
            packet = send_request("reservedSlotsList.add", name)
            send_request("reservedSlotsList.save")

            packet.read_word
        end

        # Removes a player from the reserved slots list
        #
        # `name`: the name of the player to remove from the list
        #
        # Returns the server's response to the command
        def remove_reserved_slot(name)
            packet = send_request("reservedSlotsList.remove", name)
            send_request("reservedSlotsList.save")

            packet.read_word
        end
    end

    # Registers our server state manager
    Rubicon::Frostbite::RconClient::game_handlers["BF3"] = Server
end