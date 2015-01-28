# Gallery controller to interact with Derpibooru - displays images which may be tagged for removal from view.
# Written 2015 by Joseph Austin

require 'json'
require 'net/http'

class GalleryController < ApplicationController
  def index
    if user = current_user
      # RESTful state options
      @rest = {}
      @rest[:min] = params[:min] || ""            # Minimum ID displayed
      @rest[:max] = params[:max] || ""            # Maximum ID displayed
      @job_completion = check_for_jobs(user.id)   # Whether user is busy now
      
      # Get the thumbs to be rendered. If the list is empty, try again without min or max ids
      thumb_list = get_thumb_listing(@rest, user.id, @message, user)
      if thumb_list.empty?
        @rest[:min] = @rest[:max] = ""
        thumb_list = get_thumb_listing(@rest, user.id, @message, user)
      end
      @thumbs = thumb_list
    end
  end
  
  def login_user
    cookies[:key] = params[:key]
    redirect_to gallery_index_path
  end
  
  def apply_tags
    if user = current_user
      tag_ids(user.id, params[:checked_ids]) if params[:checked_ids]
      redirect_to gallery_index_path({:min => params[:min], :max => params[:max]})
    end
  end
  
  def import_tags
    if user = current_user
      # If a file was uploaded, start the transfer to database
      id_file = params[:id_file]
      tag_ids_large(user.id, id_file.read.split("\n")) if id_file && id_file.respond_to?(:read)        
      redirect_to gallery_index_path
    end
  end
  
  private
  
  # The design is meant to scan our database first and use min or max id constraints to put less weight on the website while doing this.
  def get_thumb_listing(data, user_id, error, user)
    thumbs = []
    
    # Create numerical versions of maximum and minimum for our needs
    min = data[:min].to_i unless data[:min].empty?
    max = data[:max].to_i unless data[:max].empty?

    # Only one direction may be used
    min = max = nil if min && max
    
    while thumbs.length < 50
      page_thumbs = []
      needed_thumbs = 50 - thumbs.length # Remaining thumbnails needed to construct a page
      
      # First, if there's a min or max, use our local database to collect items we already know about to keep some of the weight off derpibooru
      #if min || max
      #  while page_thumbs.length < needed_thumbs && (lc = (LocalCopy.find_by image_id: min ? min.to_s : max.to_s))
      #    page_thumbs << {:id => min ? min.to_s : max.to_s, :link => lc.link, :thumb => lc.thumb}.merge(get_thumb_data(min ? min.to_s : max.to_s, lc.link, lc.score, user_id))
      #    if min
      #      min += 1
      #    else
      #      max -= 1
      #    end
      #  end
      #end
      
      # If we don't have enough for a page yet, read a page from derpibooru
      if page_thumbs.length < needed_thumbs
        response = nil
        if min
          response = parse_site("key=#{cookies[:key]}&order=a&constraint=id&gte=#{min}&deleted=true", error)
        elsif max
          response = parse_site("key=#{cookies[:key]}&order=d&constraint=id&lte=#{max}&deleted=true", error)
        else
          response = parse_site("key=#{cookies[:key]}&order=d&deleted=true", error)
        end
        break unless response # Crap out if you cant get a reply
        
        # Get the thumbnails from the page we just loaded in
        page_thumbs = collect_thumbs(JSON.parse(response.body), user_id, user)
        
        # When no min and max were set, we are starting from the most recent; therefore begin with the very first image descending
        max = page_thumbs[0][:id].to_i unless min || max
      end
      
      # If we yielded no results, we're done; this means we've reached the end in some direction.
      break if page_thumbs.empty?
      
      # As we collect these thumbnails, it changes our maximum or minimum (whichever direction we're browsing) for every untagged thumbnail,
      # such that the LAST will set our new max or minimum if we need to load more.
      thumbs_found = false
      page_thumbs.each do |thumb|
        unless thumb[:tagged]
          thumbs_found = true
          
          # No link means the image was deleted. Add it to our database so that it can be parsed over from now on
          ActiveRecord::Base.transaction do
            query = {:belongs_to => user_id, :image_id => thumb[:id].to_i}
            TaggedItems.create(query) unless(thumb[:link] || TaggedItems.find_by(query))
          end
          
          # Add the thumb based on which direction we're browsing, and change the min or maximum as needed
          if max
            thumbs << thumb if thumb[:link]
            max = thumb[:id].to_i - 1
          elsif min
            thumbs.insert(0, thumb) if thumb[:link]
            min = thumb[:id].to_i + 1
          end
        end
      end
      if thumbs_found
        unless thumbs.length == 50
          # Scan across gaps between the last thumb found and the next expected one
          ActiveRecord::Base.transaction do
            while TaggedItems.find_by belongs_to: user_id, image_id: max
              batch_records = TaggedItems.order("image_id DESC").where("belongs_to = #{user_id} AND image_id <= #{max}").to_a
              
              while rec = batch_records.shift
                if max == rec.image_id
                  max -= 1
                else
                  break
                end
              end
            end
          end
        end
      else
        # Scan ahead, no thumbnails found
        ActiveRecord::Base.transaction do
          if max
            max -= 1 while TaggedItems.find_by belongs_to: user_id, image_id: max
          elsif min
            min += 1 while TaggedItems.find_by belongs_to: user_id, image_id: min
          end
        end
      end
    end
    
    # We're done using min and max for our purposes. Supply the actual range to the view for its links.
    unless thumbs.empty?
      data[:min] = thumbs.last[:id]
      data[:max] = thumbs.first[:id]
    end
    
    thumbs
  end
  
  # Attempt to parse information from Derpibooru; returns response if succeeded
  def parse_site(request, message)
    puts "BUGGING DERPI #{request}"
    # URI request rules
    uri = URI.parse("https://derpiboo.ru/images.json?#{request}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 10
    http.read_timeout = 20
    http.use_ssl = true
    attempts = 1
    
    # Limit attempts so we dont annoy Derpibooru
    response = nil
    while (attempts < 4) && response.nil?
      begin
        response = http.request_get(uri)
      rescue
        sleep(attempts * 2)
        attempts += 1
      end
    end

    message = "Could not get a response from Derpibooru. Wait a few minutes and try again." unless response
    
    puts "Okay got a reply."
    
    response
  end
  
  # Fetch a user by key, or add it if it isn't there yet
  def get_user(key)
    if key
      user = UserKeys.find_by key: key
      unless user
        user = UserKeys.new(key: key)
        user.save
      end
    
      user
    else
      nil
    end
  end
  
  # From a JSON parsed listing off of derpibooru, returns the thumbnails (array) for the user and tagging options
  def collect_thumbs(items, user_id, user)
    thumbs = []
    #items.each_value do |outer|
    
    items.each do |inner|
      if inner
        id = inner["id_number"].to_s
        link = inner["image"]
        hours_old = (((DateTime::now.to_time - DateTime.parse(inner["created_at"]).to_time) / 60) / 60).to_i

        linkbase = link ? File.basename(link) : ""
        if link
          # Determine my preserved tags in link
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
        
        thumbs << {:id => id, :link => link, :thumb => thumb}.merge(get_thumb_data(id, link, inner["score"], image_tags, user_id, user))
        
        #if hours_old > 48
         # ActiveRecord::Base.transaction do
            # Maintain local database
        #    unless LocalCopy.find_by image_id: id
        #      LocalCopy.create image_id: id, link: link, thumb: thumb, score: link ? inner["score"] : "0"
        #    end
        #  end
        #end
      end
    end
    
    thumbs
  end
  
  def get_thumb_data(image_id, file_link, score, image_tags, user_id, user)
    tagged = false
    check = false
    css_id = "link"
    
    if file_link
      base = File.basename(file_link)
      tagged = TaggedItems.find_by belongs_to: user_id, image_id: image_id.to_i
      
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

