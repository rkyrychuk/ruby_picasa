# Note that in all defined classes I'm ignoring values I don't happen to care
# about. If you care about them, please feel free to add support for them,
# which should not be difficult.
#
# Declare which namespaces are supported with the namespaces method. Any
# elements defined in other namespaces are automatically ignored.
module RubyPicasa
  # attributes :url, :height, :width
  class PhotoUrl < Objectify::ElementParser
    attributes :url, :height, :width
  end


  class ThumbnailUrl < PhotoUrl
    # The name of the current thumbnail. For possible names, see Photo#url
    def thumb_name
      url.scan(%r{/([^/]+)/[^/]+$}).flatten.compact.first
    end
  end


  # Base class for User, Photo and Album types, not used independently.
  #
  #   attribute :id, 'id'
  #   attributes :updated, :title
  #   
  #   has_many :links, Objectify::Atom::Link, 'link'
  #   has_one :content, PhotoUrl, 'media:content'
  #   has_many :thumbnails, ThumbnailUrl, 'media:thumbnail'
  #   has_one :author, Objectify::Atom::Author, 'author'
  class Base < Objectify::DocumentParser
    namespaces :openSearch, :gphoto, :media
    flatten 'media:group'

    attribute :id, 'id'
    attributes :updated, :title

    has_many :links, Objectify::Atom::Link, 'link'
    has_one :content, PhotoUrl, 'media:content'
    has_many :thumbnails, ThumbnailUrl, 'media:thumbnail'
    has_one :author, Objectify::Atom::Author, 'author'

    # Return the link object with the specified rel attribute value.
    def link(rel)
      links.find { |l| l.rel == rel }
    end

    def session=(session)
      @session = session
    end

    # Should return the Picasa instance that retrieved this data.
    def session
      if @session
        @session
      else
        @session = parent.session if parent
      end
    end

    # Retrieves the data at the url of the current record.
    def load(options = {})
      session.get_url(id, options)
    end

    # If the results are paginated, retrieve the next page.
    def next
      if link = link('next')
        session.get_url(link.href)
      end
    end

    # If the results are paginated, retrieve the previous page.
    def previous
      if link = link('previous')
        session.get_url(link.href)
      end
    end
  end


  # Includes attributes and associations defined on Base, plus:
  #
  #   attributes :total_results, # represents total number of albums
  #     :start_index,
  #     :items_per_page,
  #     :thumbnail
  #   has_many :entries, :Album, 'entry'
  class User < Base
    attributes :total_results, # represents total number of albums
      :start_index,
      :items_per_page,
      :thumbnail
    has_many :entries, :Album, 'entry'

    # The current page of albums associated to the user.
    def albums
      entries
    end
  end


  # Includes attributes and associations defined on Base and User, plus:
  #
  #   has_many :entries, :Photo, 'entry'
  class RecentPhotos < User
    has_many :entries, :Photo, 'entry'

    # The current page of recently updated photos associated to the user.
    def photos
      entries
    end

    undef albums
  end


  # Includes attributes and associations defined on Base, plus:
  #
  #   attributes :published,
  #     :summary,
  #     :rights,
  #     :gphoto_id,
  #     :name,
  #     :access,
  #     :numphotos, # number of pictures in this album
  #     :total_results, # number of pictures matching this 'search'
  #     :start_index,
  #     :items_per_page,
  #     :allow_downloads
  #   has_many :entries, :Photo, 'entry'
  class Album < Base
    attributes :published,
      :summary,
      :rights,
      :gphoto_id,
      :name,
      :access,
      :numphotos, # number of pictures in this album
      :total_results, # number of pictures matching this 'search'
      :start_index,
      :items_per_page,
      :allow_downloads
    has_many :entries, :Photo, 'entry'

    # True if this album's rights are set to public
    def public?
      rights == 'public'
    end

    # True if this album's rights are set to private
    def private?
      rights == 'private'
    end

    # The current page of photos in the album.
    def photos(options = {})
      if entries.blank? and !@photos_requested
        @photos_requested = true
        self.session ||= parent.session
        self.entries = session.album(id, options).entries if self.session
      else
        entries
      end
    end
  end


  class Search < Album
    # The current page of photos matching the search.
    def photos(options = {})
      super
    end
  end


  # Includes attributes and associations defined on Base, plus:
  #
  #   attributes :published,
  #     :summary,
  #     :gphoto_id,
  #     :version, # can use to determine if need to update...
  #     :position,
  #     :albumid, # useful from the recently updated feed for instance.
  #     :width,
  #     :height,
  #     :description,
  #     :keywords,
  #     :credit
  #   has_one :author, Objectify::Atom::Author, 'author'
  class Photo < Base
    attributes :published,
      :summary,
      :gphoto_id,
      :version, # can use to determine if need to update...
      :position,
      :albumid, # useful from the recently updated feed for instance.
      :width,
      :height,
      :description,
      :keywords,
      :credit
    has_one :author, Objectify::Atom::Author, 'author'

    # Thumbnail names are by image width in pixels. Sizes up to 160 may be
    # either cropped (square) or uncropped:
    #
    #   cropped:        32c, 48c, 64c, 72c, 144c, 160c
    #   uncropped:      32u, 48u, 64u, 72u, 144u, 160u
    #
    # The rest of the image sizes should be specified by the desired width
    # alone. Widths up to 800px may be embedded on a webpage:
    # 
    #   embeddable:     200, 288, 320, 400, 512, 576, 640, 720, 800
    #   not embeddable: 912, 1024, 1152, 1280, 1440, 1600
    def url(thumb_name = nil)
      if thumb_name
        if thumb = thumbnail(thumb_name)
          thumb.url
        end
      else
        content.url
      end
    end

    # See +url+ for possible image sizes
    def thumbnail(thumb_name)
      thumbnails.find { |t| t.thumb_name == thumb_name }
    end
  end
end

