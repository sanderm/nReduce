class ApiController < ApplicationController 
  before_filter :login_required
end