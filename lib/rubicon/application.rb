module Rubicon
    def self.logger(progname="")
        @@logger ||= Rubicon::Util::Logger.new(@@config[:rubicon][:log_file], @@config[:rubicon][:log_level])
        @@logger.with_progname(progname)
    end

    def self.start!(config)
        @@config = config
        bootstrap!
        logger.info("Starting Rubicon version #{VERSION}")
        logger.info("Loaded config from #{config[:config_file]}")

        EventMachine.run do
            EventMachine.connect config[:rubicon][:server], config[:rubicon][:port], Rubicon::Frostbite::RconClient, config[:rubicon][:password]
        end
   end
end