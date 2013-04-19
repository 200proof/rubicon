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

    def self.servers
        @@server_instances
    end

    def self.web_ui_config
        @@config["webui"]
    end

    def self.start_web_ui
        @@thin_instance = Thin::Server.new @@config["webui"]["listen"]["ip"], @@config["webui"]["listen"]["port"], 
            Rubicon::WebUI::WebUIApp, signals: false, threaded: true

        # for some reason threaded: true doesnt set threaded mode :/
        @@thin_instance.threaded = true
        @@thin_instance.start
    end

    def self.shutdown!
        return if @@shutting_down # last server to disconnect may end up calling this, no need to run it again

        logger.info ("Shutting down. This may take up to 30 seconds.")
        @@thin_instance.stop!
        @@shutting_down = true
        # TODO: change me back to a normal value when i'm done deving
        servers.each_value { |server| server.message_channel.send(:shutdown); }
    rescue Exception => e
        logger.fatal ("Exception shutting down! #{e.message} (#{e.class})")
        logger.fatal (e.backtrace || [])[0..10].join("\n") 
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

        Rubicon::Util::PermissionsManager.set_global_permissions(@@config["permissions"])
        @@running_clients = 0
        @@server_instances = {}
        @@shutting_down = false

        shutdown_proc = proc do
            puts # just to keep the console neat if a control char pops up
            Thread.new {
                logger.info ("Received SIGINT/SIGTERM, shutting down gracefully.")
                Rubicon.shutdown!
            }
        end

        Signal.trap "INT", shutdown_proc
        Signal.trap "TERM", shutdown_proc

        # Get a beefier threadpool for more concurrent Thin requests.
        EventMachine.threadpool_size = 50
        EventMachine.run do
            EventMachine.error_handler do |e|
                logger("EM").error "Exception during event: #{e.message} (#{e.class})"
                logger("EM").error (e.backtrace || [])[0..10].join("\n")
            end

            start_web_ui

            config["servers"].each do |server|
                server_config_object = {
                    name: server["name"],
                    password: server["password"],
                    settings_file: server["config"] || server["name"].gsub(/[^0-9A-z.\-]/, '_')+".yml",
                    log_settings: {
                        prefix: server["name"],
                        level: @@log_level,
                        file: server["log_file"] || server["name"].gsub(/[^0-9A-z.\-]/, '_')+".log",
                        events: server["log_events"] || true
                    }
                }
                EventMachine.connect server["server"], server["port"], Rubicon::Frostbite::RconClient, server_config_object
            end
        end

        logger.debug ("EventMachine reactor stopped.")
        logger.info ("Shutdown complete.")
   end
end