class ApplicationController < ActionController::Base
  protect_from_forgery
  
  helper_method :current_user
  helper_method :logged_in?

  private
    
    def current_user
      @current_user ||= User.find(session[:user_id]) if session[:user_id]
    end

    # Filter method to enforce a login requirement
    # Apply as before_filter on any controleller you want to protect
    def authenticate
      logged_in? ? true : access_denied
    end
    
    def logged_in?
      current_user.is_a? User
    end

    def access_denied
      redirect_to login_path, :notice => "Please, login to continue"
    end

end
