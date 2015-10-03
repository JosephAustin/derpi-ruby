# Gallery controller to interact with Derpibooru - displays images which may be tagged for removal from view.
# Written 2015 by Joseph Austin

require 'json'
require 'net/http'

class GalleryController < ApplicationController
  REQUEST_STRING = "images.json?deleted=true&constraint=id" # Generic images request
  THUMBS_PER_PAGE = 100

  # GET /images
  # Display the current page of images between a minimum or maximum
  # PARAMS
  #  min - minumum desired image indexer to display
  #  max - the maximum of the same
  def images
    user = current_user

    if user
      @error = nil  # Returned message if something went wrong, or nil for success
      @images = []  # Image data for view rendering; array of hashes. Hash format is as follows:
        # indexer: Derpibooru's indexer number for the image
        # direct_link: Link to full sized image
        # thumb_link: Link to image thumbnail
        # checked: True if the image should be checked by default
        # css_id: Id for css used when displaying the image

      # Minimum and maximum indexers of the images that are returned
      @min = 0
      @max = 0

      # Only allow one direction between min and max
      min = params[:min].to_i
      max = params[:max].to_i
      min = max = nil if min && max

      begin
        images = []; # This is used only for each individual loop

        # Skim through images already databased
        if min ^ max
          begin
            databased_image = Image.where(indexer: min ? min : max).first
            if databased_image
              min += 1 if min
              max -= 1 if max
              images << databased_image
            end
          end while databased_image
        end

        # If we haven't reached our desired thumbnail count, ask derpibooru for more
        unless (@images.length + images.length) >= THUMBS_PER_PAGE
          response = make_request(generate_request(user, min, max), @error)
          if response
            images += process_response(user, response)
          else
            @images = nil
            break
          end
          # Update min and max for the images we just covered so another set can be requested as needed
          sorted_images = images.sort { |x, y| x.indexer.to_i <=> y.indexer.to_i}
          if min
            min = sorted_images.last.indexer.to_i + 1
          else
            max = sorted_images.first.indexer.to_i - 1
          end
        end

        # Now we must process these images for the view
        images.each do |image|
          unless(image.dead || user.discarded?(image.id))
            @images << process_image(user, image)
          end
        end
      end while (images.length > 0) && (@images.length < THUMBS_PER_PAGE)

      # Compute final minimum and maximum values of the final thumbnails
      range = (images.collect {|x| x.indexer.to_i}).sort
      @min = range.first.to_s
      @max = range.last.to_s
    else
      # Nope - not logged in!
      redirect_to root_path
    end
  end

  # POST
  # Hide the desired thumbnails selected on the page
  # PARAMS
  #  checked_images - indexers of images to be hidden for this user
  #  max - maximum desired image indexer that was shown in the view
  def hide
    user = current_user

    if user
      checked_images = params[:checked_images]
      max = params[:max]

      ActiveRecord::Base.transaction do
        checked_images.each do |indexer|
          databased_image = Image.where(indexer: indexer).first
          if databased_image
            HiddenImage.where(image_id: databased_image.id, user_id: user.id).first_or_create
          end
        end
      end

      redirect_to images_path max: max
    else
      # Nope - not logged in!
      redirect_to root_path
    end
  end

  private

  def generate_request(user, min, max)
    if min
      request = REQUEST_STRING + "&order=a&gte=#{min}"
    elsif max
      request = REQUEST_STRING + "&order=d&lte=#{max}"
    else
      request = REQUEST_STRING + "&order=d"
    end
    request += "&key=#{user.key}"
  end

  # Attempt to parse information from Derpibooru; returns response in json form if succeeded
  def make_request(request, error)
    # URI request with timeouts
    uri = URI.parse("https://derpiboo.ru/#{request}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 10
    http.read_timeout = 20
    http.use_ssl = true
    attempts = 1
    # Limit attempts so we dont annoy Derpibooru too badly
    response = nil
    while (attempts < 4) && response.nil?
      begin
        response = http.request_get(uri.request_uri)
      rescue
        sleep(attempts * 2)
        attempts += 1
      end
    end

    if response
      return JSON.parse(response.body)
    else
      error = "Could not get a response from Derpibooru. Wait a few minutes and try again."
      return nil
    end
  end

  # Collect the relevant image data out of a json response from derpibooru. This will add Images to the
  # database and return those processed by this method.
  def process_response(user, response)
    images = []
    ActiveRecord::Base.transaction do
      response["images"].each do |inner|
        if inner
          indexer = inner["id_number"].to_s
          # Quick check to make sure we dont try to add something to the database we already had
          databased_image = Image.exists?(indexer: indexer)
          if databased_image
            images << Image.where(indexer: indexer).first
          else
            link = inner["image"]
            images << Image.create({
              :indexer => indexer,
              :dead => link.nil?,
              :thumb_link => inner["representations"] ? inner["representations"]["thumb"].to_s : nil,
              :tags => inner["tags"] ? inner["tags"] : [],
              :score => inner["score"],
              :base_link => link ? "#{File.dirname(link)}/#{indexer}__" : "",
              :extension => link ? File.extname(link) : ""})
          end
        end
      end
    end
    images
  end

  # Determine the hash the view expects for properly displaying a passed in Image
  def process_image(user, image)
    image_tags = image.tags.split(", ") # Tags in the image, as a neat and tidy array

    # Select the tags to keep in the full link by intersecting file tags with user tags
    user_tags = user.file_tags ? user.file_tags.split(",") : []
    link_tags = (image_tags & user_tags).join "_"

    # The default construct
    result = {
      indexer: image.indexer,
      thumb_link: image.thumb_link,
      direct_link: image.base_link + link_tags + image.extension,
      checked: false,
      css_id: "link"
    }

    # Grab the user's tags in arrays
    best_list = user.best_tags ? user.best_tags.split(",") : []
    good_list = user.good_tags ? user.good_tags.split(",") : []
    bad_list = user.bad_tags ? user.bad_tags.split(",") : []
    worst_list = user.worst_tags ? user.worst_tags.split(",") : []

    # First the easy ones...
    if worst_list.any? { |tag| image_tags.include?(tag) }
      result[:css_id] = "redlight"
    elsif best_list.any? { |tag| image_tags.include?(tag) }
      result[:css_id] = "highlight"
    else
      # Then, the score checking to let rating come into play
      if image.score.to_i >= 100
        result[:css_id] = "highlight"
      elsif image.score.to_i <= -5
        result[:css_id] = "redlight"
      else
        # Last, low priority weights
        if good_list.any? { |tag| image_tags.include?(tag) }
          result[:css_id] = "highlight"
        elsif bad_list.any? { |tag| image_tags.include?(tag) }
          result[:css_id] = "redlight"
        end
      end
    end

    # Check mark red (bad) images automatically
    result[:checked] = true if result[:css_id] == "redlight"
    result
  end
end
