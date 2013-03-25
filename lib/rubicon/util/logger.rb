require "colorize"

module Rubicon::Util
    # Creates wrappers around ruby's Logger to automatically place a `progname`
    # in the log message.
    class Logger
        COLORS = {
            "DEBUG" => { color: :white, background: :black },
            "INFO" => { color: :light_blue, background: :black },
            "WARN" => { color: :yellow, background: :black },
            "ERROR" => { color: :red, background: :black },
            "FATAL" => { color: :black, background: :red },
            "EVENT" => { color: :white, background: :green },
        }

        # Mutex for puts
        @@console_mutex = Mutex.new 

        def initialize(log_settings)
            @wrappers = {}
            @settings = log_settings
            @src = log_settings[:prefix]

            log_file = File.open(log_settings[:file], "a+")
            @logger = ::Logger.new(log_file)
            @logger.level = log_settings[:level]
            @logger.formatter = proc do |level, datetime, progname, msg|
                progname ||= ""
                level = "EVENT" if level == "ANY"
                prefix = "#{@src.rjust 10}: [#{datetime.strftime "%Y-%m-%d %H:%M:%S"}] [#{level.ljust 5}]#{" "+progname.ljust(15)+" " if !progname.empty?} "
                spacer = " "*prefix.length

                # Push any further lines so they align with the rest of the message
                msg = msg.lines.each_with_index.map { |line, lnum| line = (lnum > 0 ? "#{spacer}#{line}" : line) }.join

                @@console_mutex.synchronize { puts "#{prefix}#{msg}".colorize(COLORS[level]) }
                "#{prefix}#{msg}\n"
            end
        end

        def event(event_name, message=nil, progname, &block)
            # TODO: check if event is to be logged
            @logger.add(::Logger::UNKNOWN, message, progname, &block)
        end

        def message(level, message, progname, &block)
            @logger.add(level, message, progname, &block)
        end

        def with_progname(name)
            @wrappers[name] ||= LoggerWrapper.new(self, name)
        end

        def close
            @logger.close
        end
    end

    class LoggerWrapper
        def initialize(logger, progname)
            @logger = logger
            @progname = progname
        end

        def event(event_name, message=nil, &block)
            @logger.event(event_name, message, @progname, &block)
        end

        log_levels = {
            debug:   ::Logger::DEBUG,
            info:    ::Logger::INFO,
            warn:    ::Logger::WARN,
            error:   ::Logger::ERROR,
            fatal:   ::Logger::FATAL
        }
        log_levels.keys.each do |key|
            define_method key do |message=nil, &block|
                @logger.message(log_levels[key], message, @progname, &block)
            end
        end
    end
end