require "open-uri"

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  devise :omniauthable, :omniauth_providers => [:google_oauth2]

  has_many :contacts
  has_many :events

  def self.find_for_google_oauth2(oauth, signed_in_resource=nil)
    credentials = oauth.credentials
    data = oauth.info
    user = User.where(:email => data["email"]).first

    unless user
      user = User.create(
        first_name: data["first_name"],
        last_name: data["first_name"],
        picture: data["image"],
        email: data["email"],
        password: Devise.friendly_token[0,20],
        token: credentials.token,
        refresh_token: credentials.refresh_token
      )
    end
    # user.get_google_contacts
    # user.get_google_calendars
    user.load_events
    user
  end

  def load_events
    begin
      client = self.create_client
      service = client.discovered_api('calendar', 'v3')
      calendars = client.execute(
        :api_method => service.events.list,
        :parameters => list_parameters
      )
      calendars.data.items
    rescue Faraday::Error::ConnectionFailed => e
      puts e
    rescue Exception => e
      puts e
    end
  end
  
  def create_client
    client = Google::APIClient.new(application_name: "rails-google-calendars", application_version: 3.0)
    client.authorization.access_token = self.token
    client.authorization.refresh_token = self.refresh_token if self.refresh_token
    client.auto_refresh_token=true
    client
  end

  def list_parameters
    parameters = {
      'calendarId' => self.email,
      'showDeleted': true,
      'maxResults': 10
    }
    parameters
  end

end
