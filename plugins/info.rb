require 'yaml'

class Infobot < PluginBase
  
  Infobot::DEFINE_REGEXP = /(no, )*(.+) is ([^\?]+)(?!\?)$/
  Infobot::RESPOND_REGEXP = /(what's|what is|who is|who's|where|where's|how's|how is) ([^\?]+)(?=\?)*/
  
  # if BOT_ENVIRONMENT == 'development'
    on_message Regexp.new("^#{Bot.instance.config['nickname']},\\s+#{RESPOND_REGEXP.source}", Regexp::IGNORECASE), :respond
    on_message Regexp.new("^#{Bot.instance.config['nickname']},\\s+#{DEFINE_REGEXP.source}", Regexp::IGNORECASE), :define
    on_command 'reload', :reload
  # end
  
  def initialize
    puts "entering initialize()"
    
  end
  
  def respond(msg)
    puts "entering respond()"
    @facts ||= init()
    puts msg[:message]
    puts msg[:message] =~ RESPOND_REGEXP # Regexp.new("^#{Bot.instance.config['nickname']},\\s+#{RESPOND_REGEXP.source}", Regexp::IGNORECASE)
    puts $1, $2, $3
    if !@facts.has_key?($2.downcase)
      speak("Sorry, I don't know what #{$2} is.")
    else
      fact = @facts[$2.downcase]
      speak("#{msg[:person].split(" ")[0]}, #{$2} is #{fact}.")
    end
  end
  
  def define(msg)
    puts 'entering define()'
    @facts ||= init()
    puts @facts
    puts msg[:message]
    puts msg[:message] =~ Regexp.new("^#{Bot.instance.config['nickname']},\\s+#{DEFINE_REGEXP.source}", Regexp::IGNORECASE)
    # puts @define_regexp
    puts $1, $2, $3
    @facts[$2.downcase] = $3
    speak("Okay, #{$2} is now #{$3}")
    File.open(File.join(File.dirname(__FILE__), 'infobot.yml'), 'w') do |out|
      YAML.dump(@facts, out)
    end
  end
  
  def init
    puts "entering init()"
    YAML::load(File.read(File.join(File.dirname(__FILE__), 'infobot.yml')))
  end
  
  def reload(msg)
    @facts = init()
    speak("ok, reloaded #{@facts.size} facts")
  end
  
end