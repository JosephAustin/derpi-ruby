Rails.application.routes.draw do
  root 'login#welcome'
  post 'login', to: 'login#login'
  post 'logout', to: 'login#logout'

  get 'images', to: 'gallery#images'
  post 'hide', to: 'gallery#hide'

  get 'settings', to: 'settings#show'
  post 'settings/apply'
  post 'settings/delete'
end
