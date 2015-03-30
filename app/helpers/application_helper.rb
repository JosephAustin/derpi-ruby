module ApplicationHelper
  def current_user
    user = nil
    
    unless (cookies[:key].nil?) || (cookies[:key].empty?)
      user = UserKeys.find_by key: cookies[:key]
      if user.nil?
        user = UserKeys.new(key: cookies[:key])
        user.save
      end
    end
    
    user
  end
end
