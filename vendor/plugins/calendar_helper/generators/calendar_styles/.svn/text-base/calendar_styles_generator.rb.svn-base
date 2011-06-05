require 'rmagick'

class CalendarStylesGenerator < Rails::Generator::Base
  attr_accessor :colors, :half_days, :w, :h
  
  def initialize(*runtime_args)
    super(*runtime_args)
    @colors = YAML::load( File.open("#{RAILS_ROOT}/vendor/plugins/calendar_helper/generators/calendar_styles/themes/#{args[0]}.yml") )
    @halfDays = args[1] == 'halfDays'
    cell_ratio = args[2] || 1.3
    
    # We'll just assume that no one will want their cells bigger than 100px big each
    image_size = 100
    @w = (cell_ratio.to_f * image_size).to_i
    @h = image_size
  end
  
  def manifest
    record do |m|
      calendar_themes_dir = File.join('public', 'stylesheets', 'calendar')
      calendar_images_dir = File.join('public', 'images', 'calendar')
      m.directory calendar_themes_dir
      m.directory calendar_images_dir

      # Copy files
      #%w(red blue grey).each do |dir|
      #  m.directory File.join(calendar_themes_dir, dir)
      #  m.file File.join("#{dir}/style.css"), File.join(calendar_themes_dir, "#{dir}/style.css")
      #end
      
      m.template 'style.css', File.join(calendar_themes_dir, "style.css")
      
      m.file 'resultset_previous.png', File.join(calendar_images_dir, "resultset_previous.png")
      m.file 'resultset_next.png', File.join(calendar_images_dir, "resultset_next.png")
      
      generate_half_day_images(calendar_images_dir) if @halfDays
    end
  end
  
  def generate_half_day_images(img_dir)
    # Here we make several images diagonal backgrounds for the half day cells
    
    # Each image will be bigger than the cell, then set as the bg, so the larger part is hidden    
    # Images are need for both the start and end of each half days block
    %w(normalDay weekendDay).each do |day|
      [true, false].each do |pos|

        canvas = Magick::Image.new(@w, @h)
        canvas.background_color = @colors['normalDay']

        half_day_polygon(canvas, pos, @colors['specialDay'])
        half_day_polygon(canvas, !pos, @colors[day])

        canvas.write(File.join(img_dir, "#{day}#{pos ? 'First' : 'Last'}.gif"))
      end
    end
  end
  
  def half_day_polygon(canvas, pos, color)    
    gc = Magick::Draw.new
    gc.fill(color)
    pos ? gc.polygon(0, @h, @w, 0, @w, @h) : gc.polygon(0, 0, @w, 0, 0, @h)
    gc.draw(canvas)
  end
end
