module LoginHelper
  def current_user
    invalid_key = cookies[:key].nil? || cookies[:key].empty?
    invalid_key ? nil : User.where(key: cookies[:key]).first_or_create
  end
end
