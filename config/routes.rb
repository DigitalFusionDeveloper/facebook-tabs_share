Dojo4::Application.routes.draw do
#
  extend Upload::Routes

#
  match "api(/*path(.:format))" => "api#index", :as => "api"


  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end


##
#
  scope(nil) do
    AuthController::Routes.each do |route|
      match "#{ route }(/:token)"   => "auth##{ route }", :as => "#{ route }"
    end
  end
  scope('auth') do
    AuthController::Routes.each do |route|
      match "#{ route }(/:token)"   => "auth##{ route }", :as => "auth_#{ route }"
    end
  end
  scope('admin') do
    AuthController::Routes.each do |route|
      match "#{ route }(/:token)"   => "admin/auth##{ route }", :as => "admin_#{ route }"
    end
  end
  scope('admin/auth') do
    AuthController::Routes.each do |route|
      match "#{ route }(/:token)"   => "admin/auth##{ route }", :as => "admin_auth_#{ route }"
    end
  end


##
#
  resources :invitations do
    member do
      match :accept
      match :decline
    end
  end


##
#
  match 'dashboard(/:action(/:id(.:format)))', :controller => 'dashboard', :as => 'dashboard'

## /su/jobs interface
#
=begin
  require 'resque'
  require 'resque/server'
  mount(Resque::Server => '/resque/jobs', :constraints => Constraints.admin)
=end


## admin
#
  namespace :admin do
    resources :users do
      match 'welcome', :action => 'welcome', :as => :welcome
    end

    location_routes = proc do
      resources :locations, :controller => 'locations'  do
        collection do
          match 'job/:id', :action => 'job'
          match 'import', :action => 'import'
        end
      end
    end
    instance_eval(&location_routes)

    resources :brands do
      instance_eval(&location_routes)
    end

    resources :reports do
      match 'attachments/:attachment_id', :action => 'attachment', :as => 'attachment', :via => 'get'
    end

    resources :uploads
  end

  match 'admin(/:action(/:id(.:format)))', :controller => 'admin/application', :as => 'admin'

## su
#
  namespace :su do
    resources :uploads
    resources :jobs
    match 'test(/:action(/:id(.:format)))', :controller => 'test'
  end
  match 'su(/:action(/:id(.:format)))', :controller => 'su/application', :as => 'su'


  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
    root :to => 'root#index', :as => :root

    match 'csrf' => 'application#csrf'
    match 'flash_messages' => 'application#flash_messages'

##
#
  scope ':brand' do
    match ':controller(/:action)(.:format)', :constraints => Constraints.brand
  end
  resources :brands

  resources :locations do
    collection do
      match :locator
    end
  end

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
