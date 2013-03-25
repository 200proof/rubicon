module Rubicon::Util
    # Listens for commands sent to a UNIX socket and dispatches them 
    # to any applicable servers
    class DomainSocketConsole < EventMachine::Connection
        def initialize()
            @logger = Rubicon.logger("UNIXConsole")
        end

        def receive_data(data)
            @logger.info{ "Received command via console: #{data}" }
            Rubicon.message_channels.each { |channel| channel.send([:console_command, data]) }
        end
    end
end