
<!-- saved from url=(0098)https://raw.github.com/jstirnaman/BibApp/63a57d664a0d130fa78b939a9f025c2a3be70d17/config/routes.rb -->
<html><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"><style type="text/css"></style></head><body><pre style="word-wrap: break-word; white-space: pre-wrap;">Bibapp::Application.routes.draw do


  def make_routes
    resources :works do
      collection do
        get :orphans
        #delete :destroy_multiple
        delete :merge_multiple
        post :orphans_delete
        get :shared
      end
      member do
        get :add_to_saved
        get :remove_from_saved
        put :change_type
      end

      resources :attachments
    end

    #####
    # Person routes
    #####
    resources :people do
      collection do
        get :batch_csv_show
        post :batch_csv_create
      end
      resources :attachments
      resources :works
      resources :groups
      resources :pen_names
      resources :memberships
      resources :roles do
        collection do
          get :new_admin
          get :new_editor
        end
      end
      resources :keywords do
        collection do
          get :timeline
        end
      end
    end

    #####
    # Group routes
    #####
    # Add Auto-Complete routes for adding new groups
    resources :groups do
      collection do
        get :autocomplete
        get :hidden
      end
      member do
        get :hide
        get :unhide
      end
      resources :works
      resources :people
      resources :roles do
        collection do
          get :new_admin
          get :new_editor
        end
      end
      resources :keywords do
        collection do
          get :timeline
        end
      end
    end

    #####
    # Membership routes
    #####
    # Add Auto-Complete routes
    resources :memberships do
      collection do
        put :create_multiple
        post :sort
        post :ajax_sort
        post :search_groups
      end
    end

    #####
    # Contributorship routes
    #####
    resources :contributorships do
      collection do
        get :admin
        get :archivable
        put :act_on_multiple
      end

      member do
        put :verify
        put :deny
      end
    end
    #####
    # Publisher routes
    #####
    resources :publishers do
      collection do
        get :authorities
        put :update_multiple
        get :add_to_box
        get :remove_from_box
        get :autocomplete
      end
    end

    #####
    # Publication routes
    #####
    resources :publications do
      collection do
        get :authorities
        put :update_multiple
        get :add_to_box
        get :remove_from_box
        get :autocomplete
      end
    end

    ####
    # User routes
    ####
    # Make URLs like /user/1/password/edit for Users managing their passwords
    resources :users do
      resources :imports do
        member do
          post :create_pen_name
          post :destroy_pen_name
        end
      end
      resource :password
      collection do
        match 'activate(/:activation_code)', :to =&gt; 'users#activate', :as =&gt; 'activate'
      end
      member do
        get :update_email
        post :request_update_email
      end
    end

    ####
    # Import routes
    ####
    resources :imports do
      resource :user
      resources :attachments
    end

    ####
    # Search route
    ####
    match 'search', :to =&gt; 'search#index', :as =&gt; 'search'
    match 'search/advanced', :to =&gt; 'search#advanced', :as =&gt; 'advanced_search'

    ####
    # Saved routes
    ####
    match 'saved', :to =&gt; 'user_sessions#saved', :as =&gt; 'saved'
    match 'sessions/delete_saved', :to =&gt; 'user_sessions#delete_saved',
          :as =&gt; 'delete_saved'
    match 'sessions/add_many_to_saved', :to =&gt; 'user_sessions#add_many_to_saved',
          :as =&gt; 'add_many_to_saved'
    ####
    # Authentication routes
    ####
    # Make easier routes for authentication (via restful_authentication)
    match 'signup', :to =&gt; 'users#new', :as =&gt; 'signup'
    match 'login', :to =&gt; 'user_sessions#new', :as =&gt; 'login'
    match 'logout', :to =&gt; 'user_sessions#destroy', :as =&gt; 'logout'
    match 'activate/:activation_code', :to =&gt; 'users#activate', :as =&gt; 'activate'

    ####
    # DEFAULT ROUTES
    ####
    # Install the default routes as the lowest priority.
    resources :name_strings do
      collection do
        get :autocomplete
      end
    end
    resources :memberships
    resources :pen_names do
      collection do
        post :create_name_string
        post :live_search_for_name_strings
        post :ajax_add
        post :ajax_destroy
      end
    end
    resources :keywords
    resources :keywordings
    resources :passwords
    resources :attachments do
      collection do
        get :add_upload_box
      end
    end

    # Default homepage to works index action
    root :to =&gt; 'works#index'

    match 'citations', :to =&gt; 'works#index'

    resource :user_session

    resources :authentications
    match 'auth/:provider/callback' =&gt; 'authentications#create'
    match 'auth/failure' =&gt; 'user_sessions#new'
    match 'admin/index' =&gt; "admin#index"
    match 'admin/duplicates' =&gt; "admin#duplicates"
    match 'admin/ready_to_archive' =&gt; "admin#ready_to_archive"
    match 'admin/update_sherpa_data' =&gt; "admin#update_sherpa_data"
    match 'admin/deposit_via_sword' =&gt; "admin#deposit_via_sword"
    match 'admin/update_publishers_from_sherpa' =&gt; "admin#update_publishers_from_sherpa"

    match 'roles/index' =&gt; "roles#index"
    match 'roles/destroy' =&gt; "roles#destroy"
    match 'roles/create' =&gt; "roles#create"
    match 'roles/new_admin' =&gt; "roles#new_admin"
    match 'roles/new_editor' =&gt; "roles#new_editor"
  
    #####
  # Static Pages routes KUMC
  #####
  # Add Routes for FAQ, About, etc.
    match 'pages/about'
    match 'pages/faq'
  end

  if I18n.available_locales.many?
    locale_regexp = Regexp.new(I18n.available_locales.join('|'))
    scope "(:locale)", :locale =&gt; locale_regexp do
      make_routes
    end
    #uncomment to make multi-locale version able to direct locale-less routes as well
    #make_routes
  else
    make_routes
  end


end
</pre></body></html>