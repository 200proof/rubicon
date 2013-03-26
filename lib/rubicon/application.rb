module Rubicon
    def self.connected
        @@running_clients += 1
    end

    def self.disconnected
        @@running_clients -= 1
        EventMachine.stop_event_loop if @@running_clients < 1
    end

    def self.logger(progname="Rubicon")
        @@logger ||= Rubicon::Util::Logger.new({
            prefix: "console",
            level: @@log_level,
            file: @@log_file,
            kills: true,
            chat: true,
            join: true,
            other: true            
        })
        @@logger.with_progname(progname)
    end

    def self.message_channels
        @@message_channels
    end

    def self.start!(config)
        @@config = config

        # Jump-start logging
        @@log_file = config["rubicon"]["log_file"]
        @@log_level = config["rubicon"]["log_level"]

        bootstrap!

        logger.info("Starting Rubicon version #{VERSION}")
        logger.info("Loaded config from #{config[:config_file]}")

        Rubicon::PluginManager.load_plugins(config["rubicon"]["plugins_dir"])
        @@running_clients = 0
        @@message_channels = []

        shutdown_proc = proc do
            puts # just to keep the on-console neat if a control char pops up
            Thread.new {
                logger.info ("Received SIGINT/SIGTERM, shutting down gracefully.")
                logger.info ("This may take up to 30 seconds.")
                @@shutting_down = true
                @@refresh_timer.join(31)
                @@message_channels.each { |channel| channel.send :shutdown }
                EM.stop_event_loop if @@running_clients == 0 # User might potentially have to wait if they 
                                                             # SIGINT while a connection is waiting to time out
            }
        end

        # EM::PeriodicTimer seems to block the whole event loop except on JRuby 
        # (tested on MRI 1.9.3, MRI 2.0, and Rubinius 2.0.0dev)
        # so I'm using a thread that loops instead
        @@refresh_timer = Thread.new do
            until @@shutting_down
                logger.debug { "Dispatching :refresh_scoreboard" }
                message_channels.each { |channel| channel.send :refresh_scoreboard }
                logger.debug { "All :refresh_scoreboards dispatched" }
                sleep 15
            end
        end

        Signal.trap "INT", shutdown_proc
        Signal.trap "TERM", shutdown_proc

        EventMachine.run do
            EventMachine.error_handler do |e|
                logger("EM").error "Exception during event: #{e.message} (#{e.class})"
                logger("EM").error (e.backtrace || [])[0..10].join("\n")
            end

            if(RbConfig::CONFIG["host_os"] =~ /mswin|mingw|cygwin|jruby/) || (defined? JRUBY_VERSION)
                logger.warn ("UNIX domain sockets are not supported on this platform!")
                logger.warn ("Domain socket administration disabled.")
            elsif !config["rubicon"]["domain_socket_path"]
                logger.debug ("Not starting domain socket listener.")
            else
                EventMachine.start_unix_domain_server config["rubicon"]["domain_socket_path"], Rubicon::Util::DomainSocketConsole
            end

            config["servers"].each do |server|
                server_config_object = {
                    name: server["name"],
                    password: server["password"],
                    settings_file: server["config"] || server["name"].gsub(/[^0-9A-z.\-]/, '_')+".yml",
                    log_settings: {
                        prefix: server["name"],
                        level: @@log_level,
                        file: server["log_file"] || server["name"].gsub(/[^0-9A-z.\-]/, '_')+".log",
                        kills: server["log_kills"] || true,
                        chat: server["log_chat"] || true,
                        join: server["log_joins"] || true,
                        other: server["log_other"] || true
                    }
                }
                EventMachine.connect server["server"], server["port"], Rubicon::Frostbite::RconClient, server_config_object
            end
            
            # stop_checker = proc do
            #     EventMachine.stop if @@running_clients == 0
            #     EventMachine.next_tick(stop_checker)
            # end

            # stop_checker.call
        end

        logger.info ("EventMachine reactor stopped.")
        logger.info ("Shutdown complete.")
   end
end