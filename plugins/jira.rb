require 'open-uri'
require 'hpricot'
require 'tempfile'

class Jira < CampfireBot::Plugin
  
  at_interval 3.minutes, :check_jira
  on_command 'checkjira', :checkjira_command
  
  
  def initialize
    log "initializing... "
    @data_file  = File.join(BOT_ROOT, 'tmp', "jira-#{BOT_ENVIRONMENT}-#{bot.config['room']}.yml")
    @cached_ids = YAML::load(File.read(@data_file)) rescue {}
    @last_checked ||= 10.minutes.ago
  end

  # respond to checkjira command-- same as interval except we answer with 'no issues found' if 
  def checkjira_command(msg)
    msg.speak "no new issues since I last checked #{lastlast} ago" if check_jira(msg)
  end
  
  def check_jira(msg)
    
    saw_an_issue = false
    old_cache = Marshal::load(Marshal.dump(@cached_ids)) # since ruby doesn't have deep copy
    
    lastlast = time_ago_in_words(@last_checked)
    tix = fetch_jira_url
    
    tix.each do |ticket|
      if seen?(ticket, old_cache)
        saw_an_issue = true

        @cached_ids = update_cache(ticket, @cached_ids) 
        flush_cache(@cached_ids)
  
        messagetext = "#{ticket[:type]} - #{ticket[:title]} - #{ticket[:link]} - reported by #{ticket[:reporter]} - #{ticket[:priority]}"
        msg.speak(messagetext)
        log messagetext
          
      end
    end

    @last_checked = Time.now
    log "no new issues." if !saw_an_issue
  
    saw_an_issue
  end
  
  protected
  
  # fetch jira url and return a list of ticket Hashes
  def fetch_jira_url()
    begin
      log "checking jira for new issues..."
      xmldata = open(bot.config['jira_url']).read
      doc = REXML::Document.new(xmldata)
    rescue Exception => e
      log "error connecting to jira: #{e.message}"
    end
      
    doc.elements.inject('rss/channel/item', []) do |tix, element|
      tix.push(parse_ticket_info(element))
    end
    
  end
  
  # extract ticket hash from individual xml element
  def parse_ticket_info(xml_element)
    id = xml_element.elements['key'].text
    id, spacekey = split_spacekey_and_id(id)
    
    link = xml_element.elements['link'].text
    title = xml_element.elements['title'].text
    reporter = xml_element.elements['reporter'].text
    type = xml_element.elements['type'].text
    priority = xml_element.elements['priority'].text
    
    return {
      :spacekey => spacekey,
      :id => id,
      :link => link,
      :title => title,
      :reporter => reporter,
      :type => type,
      :priority => priority
    }
  end
  
  # extract the spacekey and id from the ticket id
  def split_spacekey_and_id(key)
    spacekey = key.scan(/^([A-Z]+)/).to_s
    id = key.scan(/([0-9]+)$/)[0].to_s.to_i
    return id, spacekey
  end
  
  # has this ticket been seen before this run?
  def seen?(ticket, old_cache)
    !old_cache.key?(ticket[:spacekey]) or old_cache[ticket[:spacekey]] < ticket[:id]
  end
  
  # only update the cached highest ID if it is in fact the highest ID
  def update_cache(ticket, cache)
    cache[ticket[:spacekey]] = ticket[:id] if seen?(ticket, cache)
    cache
  end

  # write the cache to disk
  def flush_cache(cache)
    File.open(@data_file, 'w') do |out|
      YAML.dump(cache, out)
    end
  end
  
  # log
  def log(message)
    puts "#{Time.now} | #{bot.config['room']} | JIRA Plugin | #{message}"
  end
  
  
  # 
  # time/utility functions
  # 
  
  
  def time_ago_in_words(from_time, include_seconds = false)
    distance_of_time_in_words(from_time, Time.now, include_seconds)
  end
  
  def distance_of_time_in_words(from_time, to_time = 0, include_seconds = false)
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    distance_in_minutes = (((to_time - from_time).abs)/60).round
    distance_in_seconds = ((to_time - from_time).abs).round

    case distance_in_minutes
      when 0..1
        return (distance_in_minutes == 0) ? 'less than a minute' : '1 minute' unless include_seconds
        case distance_in_seconds
          when 0..4   then 'less than 5 seconds'
          when 5..9   then 'less than 10 seconds'
          when 10..19 then 'less than 20 seconds'
          when 20..39 then 'half a minute'
          when 40..59 then 'less than a minute'
          else             '1 minute'
        end

        when 2..44           then "#{distance_in_minutes} minutes"
        when 45..89          then 'about 1 hour'
        when 90..1439        then "about #{(distance_in_minutes.to_f / 60.0).round} hours"
        when 1440..2879      then '1 day'
        when 2880..43199     then "#{(distance_in_minutes / 1440).round} days"
        when 43200..86399    then 'about 1 month'
        when 86400..525599   then "#{(distance_in_minutes / 43200).round} months"
        when 525600..1051199 then 'about 1 year'
        else                      "over #{(distance_in_minutes / 525600).round} years"
    end
  end
  
end