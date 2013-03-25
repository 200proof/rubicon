module Rubicon
    def self.connected
        @@running_clients += 1
    end

    def self.disconnected
        @@running_clients -= 1
        EventMachine.stop_event_loop if @@running_clients < 1
    end

    def self.logger(progname="")
        @@logger ||= Rubicon::Util::Logger.new(@@config[:rubicon][:log_file], @@config[:rubicon][:log_level])
        @@logger.with_progname(progname)
    end

    def self.message_channels
        @@message_channels
    end

    def self.start!(config)
        @@config = config
        bootstrap!
        logger("Rubicon").info("Starting Rubicon version #{VERSION}")
        logger("Rubicon").info("Loaded config from #{config[:config_file]}")

        Rubicon::PluginManager.load_plugins(config[:rubicon][:plugins_dir])
        @@running_clients = 0
        @@message_channels = []

        shutdown_proc = proc do
            puts # just to keep the on-console neat if a control char pops up
            Thread.new {
                logger("Rubicon").info ("Received SIGINT/SIGTERM, shutting down gracefully.")
                EM.stop_event_loop if @@running_clients == 0 # User might potentially have to wait if they 
                                                             # SIGINT while a connection is waiting to time out
                @@message_channels.each { |channel| channel.send :shutdown }
            }
        end

        Signal.trap "INT", shutdown_proc
        Signal.trap "TERM", shutdown_proc

        EventMachine.run do
            EventMachine.error_handler do |e|
                logger("EM").error "Exception during event: #{e.message} (#{e.class})"
                logger("EM").error (e.backtrace || [])[0..10].join("\n")
            end

            EventMachine.connect config[:rubicon][:server], config[:rubicon][:port], Rubicon::Frostbite::RconClient, config[:rubicon][:password]
            
            # stop_checker = proc do
            #     EventMachine.stop if @@running_clients == 0
            #     EventMachine.next_tick(stop_checker)
            # end

            # stop_checker.call
        end

        logger("Rubicon").debug { "EventMachine reactor stopped" }
   end
end