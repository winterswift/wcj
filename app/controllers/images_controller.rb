#!/usr/bin/env ruby
#
# 2006-12-15  james.anderson  changed image response operator to be send_file.
#  added methods for index and for public files
#  
#  

VERSIONS[__FILE__] = "$Id: images_controller.rb 888 2007-05-28 12:20:22Z webdev $"

require "ftools"
  
class ImagesController < ApplicationController

  IMAGE_403 = File.join([RAILS_ROOT,"public", "images", "avatar.gif"])
  IMAGE_404 = File.join([RAILS_ROOT,"public", "images", "avatar.gif"])
  IMAGE_404_TYPE = "image/gif"
  
  @@fixture_avatars = nil
  
  before_filter :find_user!, :only =>[ :photo, :avatar ]
  before_filter :find_entry!, :only => [:photo]

  before_filter :restrict_read, :only =>[ :photo, :avatar ]
  
  def self.avatar_pathname(user, file)
    case user
    when Integer; id = user;
    when User; id = user.id;
    end
    File.join([RAILS_ROOT, "images", "avatars", id.to_s, File.basename(file)])
  end
  
  def self.photo_pathname(entry, file, size = nil)

    sub_d = case (size.kind_of?(String) ? size.to_sym : size)
            when :thumb
              'thumb'
            when :medium
              'medium'
            when nil
              nil
            else
              logger.warn("invalid photo size: #{size}.")
              'medium'
            end;
    if size
      File.join([RAILS_ROOT, "images", "photos",
                         entry.id.to_s,
                         sub_d,
                         File.basename(file)])
    else
      File.join([RAILS_ROOT, "images", "photos",
                           # #91, the path must be static
                           # @user.id.to_s,
                           # (@entry.journal ? @entry.journal.id.to_s : "00"),
                           entry.id.to_s,
                           File.basename(file)])
    end
  end
  
  def self.fixture_avatars()
    unless (@@fixture_avatars)
      @@fixture_avatars = []
      Find.find(RAILS_ROOT + "/test/fixtures/photos/"){|file|
        if ((file =~ /.*gif/ || file =~ /.*jpg/) && !(file =~ /.*svn.*/))
          @@fixture_avatars << file
        end
      }
    end
    @@fixture_avatars
  end
    
  def self.initialize_fixture_avatar(user)
    case user
    when Integer; id = user;
    when User; id = user.id;
    end
    avatars = fixture_avatars()
    fixture_pathname = avatars[id.modulo(avatars.length)]
    user_pathname = avatar_pathname(id, fixture_pathname)
    unless File.exist?(user_pathname)
      unless File.exist?(File.dirname(user_pathname))
          FileUtils.mkdir_p(File.dirname(user_pathname))
        end
      File.syscopy(fixture_pathname, user_pathname)
    end
    # puts("user: #{id}, pathname: #{user_pathname}")
    File.basename(fixture_pathname)
  end
  
  
  # actions
  
  # respond with a user's avatar
  # requires @user, @name
  def avatar(user = @user, parameters = params)
    pathname = ImagesController::avatar_pathname(user, parameters[:name])
    # puts("avatar pathname: #{pathname}")
    respond_with_image(pathname)
  end
  
  # respond with a photo for a journal entry
  # requires @user, @entry.journal, @entry, @name
  def photo(entry= @entry, parameters = params)
    pathname = ImagesController::photo_pathname(entry, parameters[:name], parameters[:size])
    # puts("phote pathname: #{pathname}")
    respond_with_image(pathname)
  end

  # respond with public file
  def public()
    if (filename = params[:filename])
      pathname = File.join([RAILS_ROOT, "images", File.basename(filename)])
      respond_with_image(pathname)
    else
      send_data("", :status=> 400)
    end
  end
  
  def index()
    send_data("", :status=> 400)
  end
  
  def self.file_type_mime_type(type)
    case (type.upcase)
    when '.JPG'
      'image/jpeg'
    when '.GIF'
      'image/gif'
    when '.TIFF'
      'image/tiff'
    when '.SVG'
      'image/svg+xml'
    else
      'application/octet-stream'
    end
  end
  
  
  protected
  
  def respond_with_image(pathname)
    if ( File.exist?(pathname) )
      type = ImagesController.file_type_mime_type(File.extname(pathname))
      send_file(pathname, :status=> 200, :disposition=> 'inline', :type=> type)
    else
      send_file(IMAGE_404, :status=> 404, :disposition=> 'inline', :type=> IMAGE_404_TYPE)
    end
  end  
  
  def restrict_read
    case params[:action]
    when 'avatar'
      # puts("testing access: #{(user_is_current_user? || current_user_is_admin? || @user.scope == User::SCOPE_PUBLIC)}")
      (user_is_current_user? || current_user_is_admin? || @user.scope == User::SCOPE_PUBLIC)
    when 'photo'
      # for an entry photo, the journal must be specified
      # either, it is public, the use is admin, or is has access to
      # the journal via a group
      journal = @entry.journal
      if (journal == nil || journal.scope == User::SCOPE_PUBLIC)
        true
      # otherwise, require authentication
      else
        if (logged_in?)
          # do not restrict admins. otherwise both the owner and members of
          # a franchising group can read
          if (current_user_is_admin?() ||
              (journal.owner == current_user) ||
              (journal.groups.any?{|g| g.users.include?(current_user)}))
            true
          else
            permission_denied()
          end
        else
          permission_denied()
        end
      end
    else # unexpected action
      false
    end
  end

  def permission_denied
    logger.info("[authentication] Permission denied to %s at %s for %s" %
      [(logged_in? ? current_user.login : 'guest'), Time.now, request.request_uri])

    redirect_to IMAGE_403
    return false
  end

end
