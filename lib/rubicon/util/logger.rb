require "colorize"
require "json"

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
            "EVENT" => { color: :green, background: :black },
        }

        TIME_FORMAT = "%Y-%m-%d %H:%M:%S"

        # Mutex for puts
        @@console_mutex = Mutex.new 

        def initialize(log_settings)
            @wrappers = {}
            @settings = log_settings
            @listener_streams = []

            log_file = File.open(log_settings[:file], "a+")
            @logger = ::Logger.new(log_file)
            @logger.level = log_settings[:level]
            @logger.formatter = proc do |level, datetime, progname, msg|
                progname ||= ""
                level = "EVENT" if level == "ANY"
                prefix = "#{@settings[:prefix].rjust 10}: [#{datetime.strftime TIME_FORMAT}] [#{level.ljust 5}]#{" "+progname.ljust(15)+" " if !progname.empty?} "
                spacer = " "*prefix.length

                # Push any further lines so they align with the rest of the message
                msg = (msg.lines.each_with_index.map { |line, lnum| line = (lnum > 0 ? "#{spacer}#{line}" : line) }).join

                @@console_mutex.synchronize { puts "#{prefix}#{msg}".colorize(COLORS[level]) }
                "#{prefix}#{msg}\n"
            end
        end

        def event(event_name, message=nil, progname, &block)
            msg = message || block.call
            @listener_streams.each do |stream|
                    stream.push event: "event", data: JSON::dump({event: event_name, time: Time.now.strftime(TIME_FORMAT), progname: progname, msg: msg})
            end

            if @settings[:events]
                @logger.add(::Logger::UNKNOWN, msg, progname)
            end
        end

        def message(level, message, progname, &block)
            @logger.add(level, message, progname, &block)

            if level > ::Logger::DEBUG
                message ||= block.call
                @listener_streams.each do |stream|
                        stream.push event: "log", data: JSON::dump({level: level, time: Time.now.strftime(TIME_FORMAT), progname: progname, msg: message})
                end
            end
        end

        def with_progname(name)
            @wrappers[name] ||= LoggerWrapper.new(self, name)
        end

        def close
            @logger.close
        end

        def add_web_listener(stream)
            @listener_streams << stream
        end

        def remove_web_listener(stream)
            @listener_streams.delete stream
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