class Rubicon::Frostbite::BF3::Server
    @@event_handlers = {}
    def self.event(sig, &block)
        @@event_handlers[sig] = block
    end
end