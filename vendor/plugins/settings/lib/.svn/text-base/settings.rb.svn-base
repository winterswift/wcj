#
# 2006-12-26  james.anderson  replaces @@cache with $SETTINGS_CACHE to prevent reloading

$SETTINGS_CACHE ||= {}.with_indifferent_access

class Settings < ActiveRecord::Base
  @@defaults      = (defined?(SettingsDefaults) ? SettingsDefaults::DEFAULTS : {}).with_indifferent_access

  
  #get or set a variable with the variable as the called method
  def self.method_missing(method, *args)
    method_name = method.to_s
    
    if method_name.include? '='
      #set a value for a variable
      var_name = method_name.gsub('=', '')
      value = args.first
      self[var_name] = value
    else
      #retrieve a value
      self[method_name]
    end
  end
  
  #destroy the specified settings record
  def self.destroy(var_name)
    return $SETTINGS_CACHE.delete(var_name.to_s) if delete_all(['var = ?', var_name.to_s]) #variable exists, destroy row and cache
    raise "Setting variable \"#{var_name}\" not found"
  end

  #retrieve all settings as a hash
  def self.all
    vars = find(:all, :select => 'var, value')
    
    result = {}.with_indifferent_access
    vars.each do |record|
      result[record.var] = YAML::load(record.value)
    end
    $SETTINGS_CACHE.replace(result)
    result
  end
  
  #reload all settings from the db
  def self.reload
    self.all
    self
  end
  
  def self.bound?(var_name)
    $SETTINGS_CACHE.has_key?(var_name)
  end
  
  #retrieve a setting value bar [] notation
  def self.[](var_name)
    #retrieve a setting
    var_name = var_name.to_s
    # puts("[#{var_name}]: #{self.object_id}.#{$SETTINGS_CACHE.object_id}: #{$SETTINGS_CACHE.keys.join(',')}")
    # return cached value (allow false/nil)
    if ( $SETTINGS_CACHE.has_key?(var_name) )
      return $SETTINGS_CACHE[var_name]
    end
    # puts("fetching; #{self.object_id}.#{$SETTINGS_CACHE.object_id}: #{var_name}")
    if var = find(:first, :conditions => ['var = ?', var_name])
      value = YAML::load(var.value)
      $SETTINGS_CACHE[var_name] = value
      return value
    elsif @@defaults[var_name]
      return @@defaults[var_name]
    else
      return nil
    end
  end
  
  #set a setting value by [] notation
  def self.[]=(var_name, value)
    if self[var_name] != value
      var_name = var_name.to_s
      
      record = Settings.find(:first, :conditions => ['var = ?', var_name]) || Settings.new(:var => var_name)
      record.value = value.to_yaml
      record.save
      
      $SETTINGS_CACHE[var_name] = value
    end
  end
  
  def self.each()
    $SETTINGS_CACHE.each{|k, v| yield(k, v)}
  end
  
end