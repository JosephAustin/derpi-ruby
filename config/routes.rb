Rails.application.routes.draw do
  root 'gallery#index'
  
  get 'gallery/index'
  get 'gallery/login'
  post 'gallery/login_user'
  post 'gallery/apply_tags'
  post 'gallery/import_tags'
  
  get 'settings/show'
  post 'settings/apply'
end
