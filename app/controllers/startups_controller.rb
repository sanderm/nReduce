class StartupsController < ApplicationController
  around_filter :record_user_action, :except => [:onboard_next, :stats]
  before_filter :login_required

  # Actions for all startups

  def index
    redirect_to :action => :search
  end

  def show
    if !params[:id].blank?
      @startup = Startup.find(params[:id])
    elsif user_signed_in? and !current_user.startup.blank?
      @startup = current_user.startup
    end
    @owner = true if user_signed_in? and (@startup.id == current_user.startup_id)
    @can_view_details = can_view_details?(@startup)
    @num_checkins = @startup.checkins.count
    @num_awesomes = @startup.awesomes.count
    @checkins = @startup.checkins.ordered
  end

  def search
    if !params[:search].blank?
      # sanitize search params
      params[:search].select{|k,v| [:name, :meeting_id, :industry_id].include?(k) }

      # save in session for pagination
      @search = session[:search] = params[:search]
    elsif !params[:page].blank? 
      @search = session[:search]
    end

    @search ||= {}
    @search[:page] = params[:page] || 1

    # Establish basic query to find public startups
    @startups = Startup.is_public.where(:onboarding_step => Startup.num_onboarding_steps).order('startups.name').includes(:team_members).paginate(:page => @search[:page], :per_page => 10)

    # Add conditions
    # Ignore current user's startup
    #if user_signed_in? and !current_user.startup_id.blank?
    #  @startups = @startups.where("startups.id != '#{current_user.startup_id}'")
    #end
    unless @search[:name].blank?
      @startups = @startups.where(['startups.name LIKE ?', "%#{@search[:name]}%"])
    end
    unless @search[:meeting_id].blank?
      @startups = @startups.where(['startups.meeting_id = ?', @search[:meeting_id]])
    end
    unless @search[:industry_id].blank?
      @startups = @startups.where(['startups.industry_id = ?', @search[:industry_id]])
    end
    @ua = {:data => @search}
    @meetings_by_id = Meeting.location_name_by_id
    @tags_by_startup_id = Startup.tags_by_startup_id(@startups)
  end

  #
  # Actions for user's startup
  #

  def new
    if !registration_open?
      flash[:notice] = "Sorry but registration is closed for the current nReduce class. Email Joe if you have any questions: joe@nReduce.com"
      redirect_to current_user
      return
    end
    return unless redirect_if_user_has_startup
    @startup = Startup.new(:website_url => 'http://')
  end

  def create
    return unless redirect_if_user_has_startup
    @startup = Startup.new(params[:startup])
    if @startup.save
      current_user.update_attribute('startup_id', @startup.id)
      flash[:notice] = "Startup information has been saved. Thanks!"
      redirect_to "/startup"
    else
      render :new
    end
  end

  before_filter :current_startup_required, :only => [:update, :remove_team_member] # allow people to update without valid checkin
  before_filter :current_startup_and_checkin_required, :only => [:show, :edit, :onboard, :onboard_next]

  def dashboard
    @startup = @current_startup
    @step = @startup.onboarding_step
    render :action => :onboard
  end

  def edit
    @startup = @current_startup
  end

  def update
    @startup = @current_startup
    @startup.attributes = params[:startup]
    if @startup.save
      flash[:notice] = "Startup information has been saved. Thanks!"
      redirect_to '/startup'
    else
      render :edit
    end
  end

    # Removes a team member
  def remove_team_member
    u = User.find(params[:user_id])
    if @current_startup.id != u.startup_id
      flash[:alert] = "#{u.name} could not be removed because they aren't a member of your team."
    else
      u.startup_id = nil
      if u.save
        flash[:notice] = "#{u.name} has been removed from your team."
      else
        flash[:alert] = "Sorry, but #{u.name} could not be removed at this time."
      end
    end
    redirect_to edit_startup_path(@current_startup)
  end

    # multi-page process that any new startup has to go through
  def onboard
    @startup = @current_startup
    @step = @startup.onboarding_step
    @complete = @startup.onboarding_complete?
    #@current_startups_with_videos = Startup.with_intro_video.order(updated_at: -1).paginate(:page => params[:page] || 1, :per_page => 10)
    # hack - this needs to be for this week, but we're changing dashboard soon
    @checkin_total = Checkin.count if @startup.onboarding_complete?
  end

    # did this as a separate POST / redirect action so that 
    # if you refresh the onboard page it doesn't go to the next step
  def onboard_next
    @startup = @current_startup
    # Check if we have any form data - Startup form or  Youtube url or 
    if params[:startup_form] and !params[:startup].blank?
      if @startup.update_attributes(params[:startup])
        @startup.onboarding_step_increment! 
      else
        flash.now[:alert] = "Hm, we had some problems updating your startup."
        @step = @startup.onboarding_step
        render :action => :onboard
        return
      end
    elsif params[:startup] and params[:startup][:youtube_intro_url]
      if !params[:startup][:youtube_intro_url].blank? and @startup.update_attribute('intro_video_url', params[:startup][:intro_video_url])
        @startup.onboarding_step_increment!
      else
        flash[:alert] = "Looks like you forgot to paste in your Youtube URL"
      end
    else
      @startup.onboarding_step_increment!
    end
    redirect_to :action => :onboard
  end

  #
  # ADMIN ONLY
  #
  before_filter :admin_required, :only => [:stats]

  def stats
    respond_to do |format|
      format.csv { send_data(Startup.generate_stats_csv,
                   :type => 'text/csv; charset=iso-8859-1; header=present',
                   :disposition => "attachment; filename=startup_stats_#{Date.today.to_s(:db)}.csv")
                 }
      format.html { render :nothing => true }
    end
  end

  protected

  def can_view_details?(startup)
    #if startup.checkins_public?
    if user_signed_in?
      # Admin or this is the user's startup
      return true if current_user.admin? or current_user.startup_id == startup.id
      # They are connected or the other startup has requested to be connected
      return true if current_user.startup.connected_or_pending_to?(startup)
    end
    false
  end

  def redirect_if_user_has_startup
    # Make sure they don't create another startup
    if !current_user.startup_id.blank?
      flash.keep
      redirect_to "/startup"
      return false
    end
    true
  end
end