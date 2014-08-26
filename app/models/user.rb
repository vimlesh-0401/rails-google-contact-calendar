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


      # Uncomment the section below if you want users to be created if they don't exist
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
      user.get_google_contacts
      user.get_google_calendars
      user
  end

  def call_api(url)
    response = open(url)
    JSON.parse(response.read)

    #uri = URI.parse(url)

    #http = Net::HTTP.new(uri.host, uri.port)
    #http.use_ssl = true
    #http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    #request = Net::HTTP::Get.new(uri.request_uri)
    #result = http.request(request).body
    #ActiveSupport::JSON.decode(result)
  end


  def get_google_contacts
    url = "https://www.google.com/m8/feeds/contacts/default/full?access_token=#{token}&alt=json&max-results=100"
    response = open(url)
    json = JSON.parse(response.read)
    my_contacts = json['feed']['entry']

    my_contacts.each do |contact|
      name = contact['title']['$t'] || nil
      email = contact['gd$email'] ? contact['gd$email'][0]['address'] : nil
      tel = contact['gd$phoneNumber'] ? contact["gd$phoneNumber"][0]["$t"] : nil
      if contact['link'][1]['type'] == "image/*"
        picture = "#{contact['link'][1]['href']}?access_token=#{token}"
      else
        picture = nil
      end
      contacts.create(name: name, email: email, tel: tel, picture: picture)
    end
  end

  def get_google_calendars
    url = "https://www.googleapis.com/calendar/v3/users/me/calendarList?access_token=#{token}"
    response = open(url)
    json = JSON.parse(response.read)
    calendars = json["items"]
    calendars.each { |cal| get_events_for_calendar(cal) }
  end

  def get_events_for_calendar(cal)

    url = "https://www.googleapis.com/calendar/v3/calendars/#{cal["id"]}/events?access_token=#{token}"
    response = open(url)
    json = JSON.parse(response.read)
    my_events = json["items"]

    my_events.each do |event|
      name = event["summary"] || "no name"
      creator = event["creator"] ? event["creator"]["email"] : nil
      start = event["start"] ? event["start"]["dateTime"] : nil
      status = event["status"] || nil
      link = event["htmlLink"] || nil
      calendar = cal["summary"] || nil

      events.create(name: name,
                    creator: creator,
                    status: status,
                    start: start,
                    link: link,
                    calendar: calendar
                    )
    end
  end

end