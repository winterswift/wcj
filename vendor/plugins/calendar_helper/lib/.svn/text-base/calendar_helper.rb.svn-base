require 'date'

# CalendarHelper allows you to draw a databound calendar with fine-grained CSS formatting
module CalendarHelper
  # Returns an HTML calendar. In its simplest form, this method generates a plain
  # calendar (which can then be customized using CSS) for a given month and year.
  # However, this may be customized in a variety of ways -- changing the default CSS
  # classes, generating the individual day entries yourself, and so on.
  # 
  # The following options are required:
  #  :year  # The  year number to show the calendar for.
  #  :month # The month number to show the calendar for.
  # 
  # The following are optional, available for customizing the default behaviour:
  #   :table_class       => "calendar"        # The class for the <table> tag.
  #   :month_name_class  => "monthName"       # The class for the name of the month, at the top of the table.
  #   :other_month_class => "otherMonth" # Not implemented yet.
  #   :day_name_class    => "dayName"         # The class is for the names of the weekdays, at the top.
  #   :day_class         => "day"             # The class for the individual day number cells.
  #                                             This may or may not be used if you specify a block (see below).
  #   :abbrev            => (0..2)            # This option specifies how the day names should be abbreviated.
  #                                             Use (0..2) for the first three letters, (0..0) for the first, and
  #                                             (0..-1) for the entire name.
  #   :first_day_of_week => 0                 # Renders calendar starting on Sunday. Use 1 for Monday, and so on.
  # 
  # For more customization, you can pass a code block to this method, that will get one argument, a Date object,
  # and return a values for the individual table cells. The block can return an array, [cell_text, cell_attrs],
  # cell_text being the text that is displayed and cell_attrs a hash containing the attributes for the <td> tag
  # (this can be used to change the <td>'s class for customization with CSS).
  # This block can also return the cell_text only, in which case the <td>'s class defaults to the value given in
  # +:day_class+. If the block returns nil, the default options are used.
  # 
  # Example usage:
  #   calendar(:year => 2005, :month => 6) # This generates the simplest possible calendar.
  #   calendar({:year => 2005, :month => 6, :table_class => "calendar_helper"}) # This generates a calendar, as
  #                                                                             # before, but the <table>'s class
  #                                                                             # is set to "calendar_helper".
  #   calendar(:year => 2005, :month => 6, :abbrev => (0..-1)) # This generates a simple calendar but shows the
  #                                                            # entire day name ("Sunday", "Monday", etc.) instead
  #                                                            # of only the first three letters.
  #   calendar(:year => 2005, :month => 5) do |d| # This generates a simple calendar, but gives special days
  #     if listOfSpecialDays.include?(d)          # (days that are in the array listOfSpecialDays) one CSS class,
  #       [d.mday, {:class => "specialDay"}]      # "specialDay", and gives the rest of the days another CSS class,
  #     else                                      # "normalDay". You can also use this highlight today differently
  #       [d.mday, {:class => "normalDay"}]       # from the rest of the days, etc.
  #   end
  #
  # An additional 'weekend' class is applied to weekend days. 
  #
  # For consistency with the themes provided in the calendar_styles generator, use "specialDay" as the CSS class for marked days.
  # 
  
  def setup_calendar(options = {}, &block)
    raise(ArgumentError, "No year given")  unless options.has_key?(:year)
    #raise(ArgumentError, "No month given") unless options.has_key?(:month)
    if options.has_key?(:ajax_paging)
      raise(ArgumentError, "No controller given") unless options[:ajax_paging].has_key?(:controller)
      raise(ArgumentError, "No action given") unless options[:ajax_paging].has_key?(:action)
    end

    block                        ||= Proc.new {|d| nil}

    defaults = {
      :table_class => 'calendar',
      :calendar_name_class => 'calendarName',
      :other_month_class => 'otherMonth',
      :day_name_class => 'dayName',
      :month_name_class => 'monthName',
      :day_class => 'day',
      :abbrev => (0..2),
      :first_day_of_week => 0,
      :half_days => false
    }
    options = defaults.merge options

    first_weekday = first_day_of_week(options[:first_day_of_week])
    last_weekday = last_day_of_week(options[:first_day_of_week])
    
    # Used to apply half day classes
    in_block = false
    cells = []
    
    day_names = Date::DAYNAMES.dup
    first_weekday.times do
      day_names.push(day_names.shift)
    end
    
    cal = %(<table class="#{options[:table_class]}" border="0" cellspacing="0" cellpadding="0">)

    # For a monthly cal get the start and end of this month, otherwise the start and end of this year
    if options.has_key?(:month)
      first = Date.civil(options[:year], options[:month], 1)
      last = Date.civil(options[:year], options[:month], -1)
      prevm = first.to_time.last_month
      nextm = first.to_time.next_month
      prev_cell = nil
      
      # Add ajax paging if needed
      if options.has_key?(:ajax_paging)
        cal << %(<thead><tr class="#{options[:calendar_name_class]}"><th colspan=\"7\">)

        url = url_for(options[:ajax_paging].merge({:year => prevm.year, :month => prevm.month}))
        cal << "<a href=\"#{url}\" class=\"prevcal\" onclick=\"new Ajax.Request('#{url}', {asynchronous:true, evalScripts:true}); return false;\"><img alt=\"#{Date::MONTHNAMES[prevm.month]}\" class=\"icon\" src=\"/images/calendar/resultset_previous.png\" /></a>"

        cal << "#{Date::MONTHNAMES[options[:month]]} #{options[:year]}"

        url = url_for(options[:ajax_paging].merge({:year => nextm.year, :month => nextm.month}))
        cal << "<a href=\"#{url}\" class=\"nextcal\" onclick=\"new Ajax.Request('#{url}', {asynchronous:true, evalScripts:true}); return false;\"><img alt=\"#{Date::MONTHNAMES[nextm.month]}\" class=\"icon\" src=\"/images/calendar/resultset_next.png\" /></a>"

        cal << %(</th></tr><tr class="#{options[:day_name_class]}">)
      else
        cal << %(<thead><tr class="#{options[:month_name_class]}"><th colspan="7">#{Date::MONTHNAMES[options[:month]]}</th></tr><tr class="#{options[:day_name_class]}">)
      end
      
      day_names.each {|d| cal << "<th>#{d[options[:abbrev]]}</th>"}
      cal << "</tr></thead><tbody><tr>"
      beginning_of_week(first, first_weekday).upto(first - 1) do |d|
        cal << %(<td class="#{options[:other_month_class]})
        cal << " weekendDay" if weekend?(d)
        cal << %(">#{d.day}</td>)
      end unless first.wday == first_weekday

      i = 0
      first.upto(last) do |cur|
        cell_text, cell_attrs, half_day = block.call(cur)
        cell_text  ||= cur.mday
        cell_attrs ||= {:class => options[:day_class]}
        if [0, 6].include?(cur.wday)
          cell_attrs[:class] += " weekendDay"
          day_class = 'weekend'
        else
          day_class = 'normal'
        end

        if options[:half_days]
          if half_day and !in_block
            cell_attrs[:class] += " #{day_class}DayFirst"
            in_block = true
          elsif !half_day and in_block
            prev_cell[:cell_attrs][:class] += " #{day_class}DayLast" if prev_cell
            in_block = false
          elsif cur == last and in_block
            cell_attrs[:class] += " #{day_class}DayLast"
            in_block = false
          end
        end

        cells[i] = { :cell_text => cell_text, :cell_attrs => cell_attrs, :date => cur }
        prev_cell = cells[i]

        i += 1
      end

      cells.each do |cell|
        cell_attrs = cell[:cell_attrs].map {|k, v| %(#{k}="#{v}") }.join(" ")
        cal << "<td #{cell_attrs}>#{cell[:cell_text]}</td>"
        cal << "</tr><tr>" if cell[:date].wday == last_weekday
      end

      (last + 1).upto(beginning_of_week(last + 7, first_weekday) - 1)  do |d|
        cal << %(<td class="#{options[:other_month_class]})
        cal << " weekendDay" if weekend?(d)
        cal << %(">#{d.day}</td>)
      end unless last.wday == last_weekday
      cal << "</tr></tbody></table>"
      
    else
      m = 0
      months = []
      prev_cell = nil
      
      1.upto(12) do |month|
        first = Date.civil(options[:year], month, 1)
        last = Date.civil(options[:year], month, -1)

        cells = []
        
        0.upto(first.wday-1) do |wday|
          cells << { :cell_text => '', :cell_attrs => { :class => 'otherMonth' } }
        end
        
        i = cells.length
        first.upto(last) do |cur|
        
          cell_text, cell_attrs, half_day = block.call(cur)
          cell_text  ||= cur.mday
          cell_attrs ||= {:class => options[:day_class]}
          if [0, 6].include?(cur.wday)
            cell_attrs[:class] += " weekendDay"
            day_class = 'weekend'
          else
            day_class = 'normal'
          end

          if options[:half_days]
            if half_day and !in_block
              cell_attrs[:class] += " #{day_class}DayFirst"
              in_block = true
            elsif !half_day and in_block
              prev_cell[:cell_attrs][:class] += " #{day_class}DayLast" if prev_cell
              in_block = false
            end
          end

          cells[i] = { :cell_text => cell_text, :cell_attrs => cell_attrs, :date => cur }
          prev_cell = cells[i]

          i += 1
        end
        
        months << cells
        m += 1
      end
      
      # Find the longets month so we know how many columns there are
      num_days = months.collect { |m| m.size }.sort.last

      if options.has_key?(:ajax_paging)
        cal << %(<thead><tr class="#{options[:calendar_name_class]}"><th colspan=\"#{num_days}\">)

        url = url_for(options[:ajax_paging].merge({:year => options[:year] - 1}))
        cal << %(<a href="#{url}" class="prevcal" onclick="new Ajax.Request('#{url}', {asynchronous:true, evalScripts:true}); return false;"><img alt="#{options[:year] - 1}" class="icon" src="/images/calendar/resultset_previous.png" /></a>)

        cal << %(<span class="caltitle">#{options[:year]}</span>)
        
        
        url = url_for(options[:ajax_paging].merge({:year => options[:year] + 1}))
        cal << %(<a href="#{url}" class="nextcal" onclick="new Ajax.Request('#{url}', {asynchronous:true, evalScripts:true}); return false;"><img alt="#{options[:year] + 1}" class="icon" src="/images/calendar/resultset_next.png" /></a>)

      else
        cal << %(<thead><tr class="#{options[:month_name_class]}"><th colspan="#{num_days}">#{options[:year]}</th></tr><tr class="#{options[:day_name_class]}">)
      end
      
       cal << %(</tr><tr class="#{options[:day_name_class]}">)
      
      cal << %(<th></th>)
      1.upto(num_days) do |d|
        cal << %(<th>#{day_names[(d-1)%7][options[:abbrev]]}</th>)
      end
      
      cal << %(</tr></thead><tbody>)

      months.each_with_index do |mcells, m|
        cal << %(<tr>)
        cal << %(<td class="#{options[:month_name_class]}">#{Date::MONTHNAMES[m+1][0..2]}</td>)
        mcells.each do |cell|
          cell_attrs = cell[:cell_attrs].map {|k, v| %(#{k}="#{v}") }.join(" ")
          cal << "<td #{cell_attrs}>#{cell[:cell_text]}</td>"
        end  
        cal << %(</tr>)
      end
      cal << %(</tbody></table>)
    end
  end
  
  private
  
  def first_day_of_week(day)
    day
  end
  
  def last_day_of_week(day)
    if day > 0
      day - 1
    else
      6
    end
  end
  
  def days_between(first, second)
    if first > second
      second + (7 - first)
    else
      second - first
    end
  end
  
  def beginning_of_week(date, start = 1)
    days_to_beg = days_between(start, date.wday)
    date - days_to_beg
  end
  
  def weekend?(date)
    [0, 6].include?(date.wday)
  end
  
end