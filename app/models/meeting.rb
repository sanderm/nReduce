class Meeting < ActiveRecord::Base
  acts_as_mappable
  has_many :startups
  belongs_to :organizer, :class_name => 'User'

  attr_accessible :location_name, :venue_name, :venue_address, :venue_url, :description,  :start_time, :day_of_week, :organizer_id

  validates_presence_of :name
  validates_uniqueness_of :name, :on => :create, :message => "must be unique"

  before_save :geocode_location

  def self.select_options
    Meeting.all.map{|m| [m.name, m.id] }
  end

      # Returns an array with days of week and integer, ex: ['Monday', 1]
  def self.days_of_week_arr
    n = -1
    Date::DAYNAMES.map{|d| n += 1; [d, n] }
  end

      # Returns the group time as a ruby Time object using currently set time zone
  def time_with_zone
    s = "%04d" % self.start_time
    hours = s[0..1]
    mins = s[2..4]
    t = Time.now.in_time_zone(Nreduce::Application.config.time_zone)
    t = t.beginning_of_week.change(:hour => hours, :min => mins) + (self.day_of_week - 1).days
    t = t.in_time_zone(Time.zone)
  end

  protected

  def geocode_location
    return true if self.venue_address.blank? or (!self.venue_address_changed? and !self.lat.blank?)
    begin
      res = Meeting.geocode(self.venue_address)
      self.lat, self.lng = res.lat, res.lng
    rescue
      self.errors.add(:venue_address, "could not be geocoded")
    end
  end
end
