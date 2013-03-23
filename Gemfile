source "https://rubygems.org"

gem "eventmachine"
gem "thread"

# Load any gems that plugins require
Dir.glob(File.expand_path("../**/Gemfile", __FILE__)) do |f|
    eval File.read(f) if f != __FILE__
end