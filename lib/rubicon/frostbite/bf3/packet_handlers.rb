class Rubicon::Frostbite::BF3::Server
    @@packet_handlers = {}
    def self.signal(sig, &block)
        @@packet_handlers[sig] = block
    end
end