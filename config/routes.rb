Rails.application.routes.draw do
  root 'gallery#login'
  
  get 'login', to: 'gallery#login'
  post 'login', to: 'gallery#login'
  post 'logout', to: 'gallery#logout'
  
  get 'images', to: 'gallery#images'
  post 'search', to: 'gallery#search'
  
  get 'settings', to: 'settings#show'
  post 'settings/apply'
  post 'settings/delete'
end
