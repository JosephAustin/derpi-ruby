class LoginController < ApplicationController
  # GET - Site root
  # Don't bother the user to log in unless they aren't already
  def welcome
    if current_user
      redirect_to images_path
    end
  end

  # POST
  # Log in a user by their API key simply by shoving that into the cookies
  def login
    if params[:key].nil? || params[:key].empty?
      redirect_to root_path
    else
      cookies[:key] = params[:key]
      redirect_to images_path
    end
  end

  # POST
  # Log the user out
  def logout
    cookies[:key] = nil
    redirect_to root_path
  end
end
