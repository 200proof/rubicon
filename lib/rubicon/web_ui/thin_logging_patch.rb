# Monkey-patches Thin's logging facilities to use Rubicon's own
module Thin::Logging
    def debug(msg=nil, &block)
        Rubicon.logger("ThinServer").debug(msg, &block) if Thin::Logging.debug?
    end

    def trace(msg=nil, &block)
        debug(msg, &block) if Thin::Logging.trace?
    end

    def log(msg)
        Rubicon.logger("ThinServer").info(msg) unless Thin::Logging.silent?
    end

    def log_error(e=$!)
        Rubicon.logger("ThinServer").error ("Error in Thin Server! #{e.message} (#{e.class})")
        Rubicon.logger("ThinServer").error (e.backtrace || [])[0..10].join("\n") 
    end
end

# Redirect Rack's CommonLogger to a Rubicon debug logger
class Rack::CommonLogger
    def log(env, status, header, began_at)
      now = Time.now
      length = extract_content_length(header)

      Rubicon.logger("Rack").debug FORMAT % [
        env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
        env["REMOTE_USER"] || "-",
        now.strftime("%d/%b/%Y %H:%M:%S"),
        env["REQUEST_METHOD"],
        env["PATH_INFO"],
        env["QUERY_STRING"].empty? ? "" : "?"+env["QUERY_STRING"],
        env["HTTP_VERSION"],
        status.to_s[0..3],
        length,
        now - began_at ]
    end
end