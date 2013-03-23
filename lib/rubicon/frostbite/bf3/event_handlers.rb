class Rubicon::Frostbite::BF3::Server
    @@event_handlers = {}
    def self.event(sig, &block)
        @@event_handlers[sig] = block
    end

    event "player.onKill" do |server, packet|
        event_name = packet.read_word
        event_args = {
            killer: server.players[packet.read_word],
            victim: server.players[packet.read_word],
            weapon: server.players["Server"],
            weapon: packet.read_word,
            headshot?: packet.read_bool
        }
        
        server.plugin_manager.dispatch_event(event_name, event_args)
    end
end