module Rubicon::Frostbite::BF3
    class Server
        def initialize(connection, password)
            @connection = connection
            @password = password
            @logger = Rubicon.logger("BF3Server")

            p @logger
        end

        def connected
            @logger.debug { "Connected to a BF3 server!" }
            @connection.send_request("login.plainText", @password)
            @connection.send_command("admin.eventsEnabled", "true")
        end

        def start_event_pump
            while message = @connection.message_channel.receive
                @logger.debug { message.words.inspect }
            end
        end     
    end

    Rubicon::Frostbite::RconClient::game_handlers["BF3"] = Server
end