class UserSessionsController < ApplicationController

  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:destroy, :saved]
  helper UserSessionsHelper
  
  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      flash[:notice] = "Login successful!"
      redirect_to params[:return_to] || session[:return_to] || root_url
    else
      render :action => :new
    end
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_back_or_default new_user_session_url
  end

  def saved
    @works = session[:saved].all_works
  end

  def login_shibboleth
    if current_user
      redirect_to session[:return_to] || root_url
    else
      redirect_to(shibboleth_login_url, :return_to => params[:return_to])
    end
  end

  protected
  
  def shibboleth_login_url
    url = root_url(:protocol => 'https') + "Shibboleth.sso/Login"
    Rails.logger.error("SHIB: base url: #{url}")
    return_to = session[:return_to] || params[:return_to]
    if return_to
      target = root_url + return_to
      url = "#{url}?target=#{CGI.escape(target)}"
      Rails.logger.error("SHIB: target set: #{target}")
      Rails.logger.error("SHIB: full url: #{url}")
    end
    return url
  end

end
