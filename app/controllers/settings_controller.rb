# Settings controller - set tags up for automatic highlighting, etc. 
# Written 2015 by Joseph Austin
  
class SettingsController < ApplicationController
  def show
    if user = current_user
      @best = user.best_tags ? user.best_tags.split(",") : []
      @good = user.good_tags ? user.good_tags.split(",") : []
      @bad = user.bad_tags ? user.bad_tags.split(",") : []
      @worst = user.worst_tags ? user.worst_tags.split(",") : []
      @file = user.file_tags ? user.file_tags.split(",") : []
    end
  end
  
  def apply
    if user = current_user
      previous = user[params[:field]]
      if previous
        user[params[:field]] += "," + params[:new_tag]
      else
        user[params[:field]] = params[:new_tag]
      end

      user.save
      redirect_to settings_show_path
    end
  end
end
