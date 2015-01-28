# Primary application controller
# Written 2015 by Joseph Austin

class ApplicationController < ActionController::Base
  @@upload_thread = nil
  
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  
  protected
  
  def current_user
    user = nil
    
    if (cookies[:key].nil?) || (cookies[:key].empty?)
      redirect_to gallery_login_path
    else
      user = UserKeys.find_by key: cookies[:key]
      if user.nil?
        user = UserKeys.new(key: cookies[:key])
        user.save
      end
    end
    
    user
  end
  
  # Tag an array of IDs in the database for a single user
  def tag_ids(user_id, image_ids)
    queries = []
    image_ids.each { |img_id| queries << {:belongs_to => user_id, :image_id => img_id.to_i } }
    ActiveRecord::Base.transaction do
      queries.each { |query| TaggedItems.create query unless TaggedItems.find_by query }
    end
  end
  
  # For a massive amount of IDs. This will occur in a thread.
  def tag_ids_large(user_id, image_ids)
    # Describe the job
    job = {:data => image_ids, :completion => 0.0, :rate => 100.0 / image_ids.length.to_f}
    
    # If the thread exists, apply this job directly, otherwise launch it
    if @@upload_thread && @@upload_thread.alive?
      @@upload_thread[:jobs][user_id] = job
    else
      @@upload_thread = Thread.new(user_id, job) {
        jobs = Thread.current[:jobs] # Shorthand for the jobs listing
        
        # Keep working until all jobs are completed
        until jobs.keys.empty?
          sleep(0.25)
          jobs.keys.each do |job_key|
            sleep(0.25)
            job = jobs[job_key]
            
            # Delete this job if it has nothing to do
            if job[:data].empty?
              jobs.delete job_key
            else
              # Do UP TO 100 items of the remaining data for this job before moving on to others, so everyone gets a turn
              items = []
              100.times do |i|
                img_id = job[:data].shift
                # Skip items that exist in the database
                if TaggedItems.find_by belongs_to: user_id, image_id: img_id.to_i
                  job[:completion] += job[:rate]
                else
                  items << {:belongs_to => user_id, :image_id => img_id.to_i}
                end
                break if job[:data].length == 0
              end
              
              # All items not skipped are now tossed in one transaction to the database
              unless items.empty?
                ActiveRecord::Base.transaction do
                  items.each { |item| TaggedItems.create item }
                end                    
                job[:completion] += job[:rate] * items.length
              end
            end
          end
        end
      }
      
      # Initialize the thread's jobs so it can be requested before the thread begins (as in busy?())
      @@upload_thread[:jobs] = { user_id => job }
    end
  end
  
  # Returns % complete of the user job, or nil if there isn't one
  def check_for_jobs(user_id)
    is_busy = @@upload_thread && @@upload_thread[:jobs][user_id]

    if is_busy
      @@upload_thread[:jobs][user_id][:completion]
    else
      nil
    end
  end
end

