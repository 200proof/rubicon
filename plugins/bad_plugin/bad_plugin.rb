class MyBadPlugin < Rubicon::Plugin
    def initialize
        puts "This is a big no-no around these parts."
    end
end