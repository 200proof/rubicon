source "https://rubygems.org"

gem "eventmachine", "~> 1.0.3"

# Thread goodies like message channels and promises
gem "thread", "~> 0.0.6.2"

# Web stuff
gem "thin", "~> 1.5.1"
gem "sinatra", "~> 1.4.2"
gem "async_sinatra", "~> 1.1.0"
gem "sass", "~> 3.2.7"
gem "compass", "~> 0.12.2"
gem "coffee-script", "~> 2.2.0"
gem "sinatra-flash", "~> 0.3.0"
gem "sinatra-sse", "0.1"
gem "async_sinatra", "~> 1.1.0"

# Pretty colors
gem "colorize", "~> 0.5.8"
gem 'win32console', "~> 1.3.2", :platforms => [:mswin, :mingw]

# Load any gems that plugins require
Dir.glob(File.expand_path("../**/Gemfile", __FILE__)) do |f|
    eval File.read(f) if f != __FILE__
end
