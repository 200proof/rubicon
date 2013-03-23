require "digest/md5"

module Rubicon::Frostbite::BF3
    class Server
        require 'rubicon/frostbite/bf3/signal_handlers'
        require 'rubicon/frostbite/bf3/event_handlers'

        attr_reader :connection
        attr_accessor :name, :players, :max_players, :game_mode,
            :current_map, :rounds_played, :rounds_total, :scores,
            :score_target, :online_state, :ranked, :punkbuster,
            :has_password, :uptime, :round_time, :ip,
            :punkbuster_version, :join_queue, :region,
            :closest_ping_site, :country, :matchmaking, :players,
            :teams

        def initialize(connection, password)
            @connection = connection
            @password = password
            @logger = Rubicon.logger("BF3Server")

            @players = {}
            @teams = []

            # 0 = neutral, 16 possible teams
            17.times do |idx|
                @teams[idx] = Team.new(self, idx)
            end
        end

        # Called when successfully connected to a BF3 RCON server
        def connected
            @logger.debug { "Connected to a BF3 server!" }

            process_signal(:refresh_server_info)

            @logger.info { "Connected to #{@name}!" }

            if attempt_login
                @logger.fatal { "Failed to log in!" }
                return false
            end

            process_signal(:refresh_scoreboard)

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
            salted_password = salt + @password
            Digest::MD5.hexdigest(salted_password).upcase
        end

        # Process signals and events
        def start_event_pump
            while message = @connection.message_channel.receive
                if (message.is_a? Rubicon::Frostbite::RconPacket)
                    process_packet(message)
                elsif (message.is_a? Symbol)
                    process_signal(message)
                else
                    @logger.warn("Discarding unknown message: #{message}")
                end
            end
        end

        def process_signal(signal)
            @@signal_handlers[signal].call(self) rescue @logger.warn { "No handler for signal #{signal}" }
        end

        def process_packet(packet)
            @@packet_handlers[packet.words[0]].call(self, packet) rescue @logger.warn { "No handler for packet #{packet.words[0]}" }
        end     
    end

    # Registers our server state manager
    Rubicon::Frostbite::RconClient::game_handlers["BF3"] = Server
end