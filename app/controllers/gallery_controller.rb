# Gallery controller to interact with Derpibooru - displays images which may be tagged for removal from view.
# Written 2015 by Joseph Austin

require 'json'
require 'net/http'

class GalleryController < ApplicationController
  public
  
  def images
    user = current_user
    if user
      @min = params[:min].to_i if params[:min]
      @max = params[:max].to_i if params[:max]
      
      # Only one direction may be used
      @min = @max = nil if @min && @max
      
      # Find the thumbs to be rendered. If the resulting list is empty, try again without min or max ids,
      # which means reset to the beginning.
      @thumbs = get_thumbnails(user, @error)
      unless @error
        if(@thumbs.empty?)
          @min = @max = nil
          @thumbs = get_thumbnails(user, @error)
        end
      end
    else
      # No user key entered, go to login
      redirect_to login_path
    end
  end
  
  def search
    user = current_user
    if user
      # Get the search query
      query_field = params[:search_query]
      @query = nil
      if(query_field && query_field.is_a?(Hash))
        @query = query_field[:keyword]
      end
      
      # If the query was supplied, perform the search
      if(@query && (@query.length > 0))
        @page = params[:page] || "1"
        
        # Find the thumbs to be rendered. If the resulting list is empty, go to first page
        @thumbs = get_thumbnails_for_query(user, @query, @page, @error)
        unless @error
          if(@thumbs.empty?)
            page = "1"
            @thumbs = get_thumbnails_for_query(user, @query, @page, @error)
          end
        end

        render 'images'
      # Otherwise, go back to images
      else
        redirect_to images_path
      end
    else
      # No user key entered, go to login
      redirect_to login_path
    end
  end
  
  def apply_tags
    # Do the tagging
    if user = current_user
      tag_ids(user.id, params[:checked_ids]) if params[:checked_ids]
    end
    
    # Appropriately refresh
    if(params[:page])
      redirect_to search_path(page: params[:page], search_query: eval(params[:search_query]) )
    else
      redirect_to images_path(params)
    end
  end
  
  def login
    if request.post?
      cookies[:key] = params[:key]
      redirect_to images_path
    else
      user = current_user
      
      # Go to images page if already logged in for a key
      if user
        redirect_to images_path
      else
        render :layout => 'application'
      end
    end
  end
  
  def logout
    cookies[:key] = nil
    redirect_to root_path
  end
  
  
  private
  
  # Search for thumbnails from an images query. If min and max arent both provided, this will
  # fill them out.
  def get_thumbnails(user, error)
    thumbs = []
    
    # Generic request parameters to make
    basic_request = "images.json?key=#{cookies[:key]}&deleted=true&constraint=id"
    
    # Strive to collect at least 50 thumbs
    while thumbs.length < 50
      page_thumbs = []
      needed_thumbs = 50 - thumbs.length # Remaining thumbnails needed to construct a page
      
      # If we don't have enough thumbnails for a page yet, read a page from derpibooru
      if page_thumbs.length < needed_thumbs
        parameters = nil # Additional request parameters to make
        if @min
          parameters = "&order=a&gte=#{@min}"
        elsif @max
          parameters = "&order=d&lte=#{@max}"
        else
          parameters = "&order=d"
        end
        
        # Make sure we get a reply
        response = make_request(basic_request + parameters, error)
        if response
          # Parse the response for thumbnails
          page_thumbs = json_to_thumbnails(user, JSON.parse(response.body))
          
          # When no min and max were set, we are starting from the most recent; therefore begin with the very first image descending
          @max = page_thumbs[0][:id].to_i unless @min || @max
        else
          break
        end
      end
      
      # If we yielded no results, we're done
      if page_thumbs.empty?
        break
      else
        # As we collect these thumbnails, it changes our maximum or minimum (whichever direction we're browsing) for every untagged thumbnail,
        # such that the LAST will set our new max or minimum if we need to load more.
        thumbs_found = false
        page_thumbs.each do |thumb|
          unless thumb[:tagged]
            thumbs_found = true
            
            # No link means the image was deleted. Add it to our database so that it can be parsed over from now on
            ActiveRecord::Base.transaction do
              query = {:belongs_to => user.id, :image_id => thumb[:id].to_i}
              TaggedItems.create(query) unless(thumb[:link] || TaggedItems.find_by(query))
            end
            
            # Add the thumb based on which direction we're browsing, and change the min or maximum as needed
            if @max
              thumbs << thumb if thumb[:link]
              @max = thumb[:id].to_i - 1
            elsif @min
              thumbs.insert(0, thumb) if thumb[:link]
              @min = thumb[:id].to_i + 1
            end
          end
        end
        
        if thumbs_found
          unless thumbs.length == 50
            # Scan across gaps between the last thumb found and the next expected one
            ActiveRecord::Base.transaction do
              if @max
              while TaggedItems.find_by belongs_to: user.id, image_id: @max
                  batch_records = TaggedItems.order("image_id DESC").where("belongs_to = #{user.id} AND image_id <= #{@max}").to_a
                  
                  while rec = batch_records.shift
                    if @max == rec.image_id
                      @max -= 1
                    else
                      break
                    end
                  end
                end
              end
            end
          end
        else
          # Scan ahead, no thumbnails found
          ActiveRecord::Base.transaction do
            if @max
              @max -= 1 while TaggedItems.find_by belongs_to: user.id, image_id: @max
            elsif @min
              @min += 1 while TaggedItems.find_by belongs_to: user.id, image_id: @min
            end
          end
        end
      end
    end
    
    # We're done using min and max for our purposes. Supply the actual range to the view for its links.
    unless thumbs.empty?
      @min = thumbs.last[:id]
      @max = thumbs.first[:id]
    end
    
    thumbs
  end
  
  # Search for thumbnails by query, at a certain page.
  def get_thumbnails_for_query(user, query, page, error)
    thumbs = []
    
    # Limit the page to 1 or more
    page = "1" if (page.to_i < 1)
    
    # Generic request parameters to make
    basic_request = "search.json?key=#{cookies[:key]}&page=#{page}"
    
    page_thumbs = []
  
    # Make sure we get a reply
    response = make_request(basic_request + "&q=#{query}", error)
    if response 
      # Parse the response for thumbnails
      page_thumbs = json_to_thumbnails(user, JSON.parse(response.body))
    end
    
    # Do not include tagged thumbnails
    page_thumbs.each do |thumb|
      thumbs << thumb if thumb[:link] unless thumb[:tagged]
    end
    
    thumbs
  end
  
  # Tag an array of IDs in the database for a single user
  def tag_ids(user_id, image_ids)
    queries = []
    image_ids.each { |img_id| queries << {:belongs_to => user_id, :image_id => img_id.to_i } }
    ActiveRecord::Base.transaction do
      queries.each { |query| TaggedItems.create query unless TaggedItems.find_by query }
    end
  end
  
  # Attempt to parse information from Derpibooru; returns response if succeeded
  def make_request(request, error)
    puts "!!! Making Request #{request}"
    
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
    error = "Could not get a response from Derpibooru. Wait a few minutes and try again." unless response    
    response
  end
  
  # From a JSON parsed listing off of derpibooru, returns the thumbnails (array) for the user
  def json_to_thumbnails(user, response)
    thumbs = []
    
    response.each do |inner|
      if inner
        id = inner["id_number"].to_s
        link = inner["image"]

        linkbase = link ? File.basename(link) : ""
        if link
          # Determine preserved tags in link
          tags = ""
          if user.file_tags
            user.file_tags.split(",").each do |tag|
              tags += "_#{tag}" if linkbase.include? tag
            end
          end
        
          fname = File.basename(link).sub(/\_.*\./, "#{tags}.") # True file name with only our tags appended
          link.sub!(File.basename(link), fname) # Replace the file name in the link
        end
              
        repres = inner["representations"]
        thumb = repres ? repres["thumb"].to_s : nil
        image_tags = inner["tags"] ? inner["tags"].split(", ") : []
        
        # Request the thumbnail data
        data = get_thumb_data(id, link, inner["score"], image_tags, user)
        
        # Merge the information to create the thumbnail structure
        thumbs << {:id => id, :link => link, :thumb => thumb}.merge(data)
      end
    end
        
    thumbs
  end
  
  # Create extra data for each thumbnail to help mark it
  def get_thumb_data(image_id, file_link, score, image_tags, user)
    tagged = false
    check = false
    css_id = "link"
    
    if file_link
      base = File.basename(file_link)
      tagged = TaggedItems.find_by belongs_to: user.id, image_id: image_id.to_i
      
      best_list = user.best_tags ? user.best_tags.split(",") : []
      good_list = user.best_tags ? user.good_tags.split(",") : []
      bad_list = user.best_tags ? user.bad_tags.split(",") : []
      worst_list = user.best_tags ? user.worst_tags.split(",") : []

      if tagged
        css_id = "hovlink"
      else
        # High priority check
        green_listed = best_list.any? { |tag| image_tags.include?(tag) }
        black_listed = worst_list.any? { |tag| image_tags.include?(tag) }
        if green_listed
          css_id = "highlight"
        elsif black_listed
          check = true
        else
          # Score check (medium priority)
          if score.to_i >= 100
            css_id = "highlight"
          elsif score.to_i <= -5
            check = true
          else
            # Low priority check
            green_listed = good_list.any? { |tag| image_tags.include?(tag) }
            black_listed = bad_list.any? { |tag| image_tags.include?(tag) }
            if green_listed
              css_id = "highlight"
            elsif black_listed
              check = true
            end
          end
        end
        
        css_id = "redlight" if check
      end
    end

    {:tagged => tagged, :check => check, :css_id => css_id}
  end
end

