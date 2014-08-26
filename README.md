# Google-connect on top of devise

## Gemfile

```ruby
# Devise with fb-omniauth extension
gem "devise"
gem "omniauth-google-oauth2"
```

## Integrate omniauth-google

### Create the google project

- Create a new project on [Google developper console](https://console.developers.google.com/project).
- In the list of APIs, activate at least the google contacts and google calendar APIs (cause we gonna play with those).
- In the credentials, don't forget to create a client ID, and change the callback URI of the settings to **http://localhost:3000/users/auth/google_oauth2/callback**

Remember your client ID and client Secret for what follows.

### Configure devise with API keys

To protect our keys use the [figaro gem](https://github.com/laserlemon/figaro).

- run `rails generate figaro:install` if you haven't already. It will create a *config/application.yml* to put all your API keys and add this file in *.gitignore*

- copy / paste your Google keys in *config/application.yml* as follows

```
development:
  GOOGLE_ID: 4*********0
  GOOGLE_SECRET: 5********************2
```

Now **here is the tricky part**

- Modify `config/initializers/devise.rb` to tell devise to use these keys

```ruby
config.omniauth :google_oauth2, ENV["GOOGLE_ID"], ENV["GOOGLE_SECRET"], {
  scope: "https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/userinfo.profile,http://www.google.com/calendar/feeds,http://www.google.com/m8/feeds"
}
```

When you configure devise for google omniauth, you have to specify a scope of all google APIs you are going to use.


Now you are set up to integrate Google connect in your core-app (routes/controller/model)


### Add omniauth callbacks controller and routing

- Create a new controller **app/controllers/users/omniauth_callbacks_controller.rb**. This will handle all omniauth callbacks from other services. In this controller, add a `facebook` action that handle fb callback as follows

```ruby
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    # You need to implement the method below in your model (e.g. app/models/user.rb)
    @user = User.find_for_google_oauth2(request.env["omniauth.auth"], current_user)

    if @user.persisted?
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", :kind => "Google"
      sign_in_and_redirect @user, :event => :authentication
    else
      session["devise.google_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end
end
```

- Note that all the magic will come from `User#find_for_google_oauth2` class method (see next section)

- Change the normal `devise_for :users` route to link omniauth callbacks to this new controller.

```ruby
devise_for :users, :controllers => { :omniauth_callbacks => "users/omniauth_callbacks" }
```

### Now pimp the model

Make your user model omniauthable.

```ruby
class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable


  # Following line makes your model google-omniauthable
  devise :omniauthable, :omniauth_providers => [:google_oauth2]

end
```

For the `User` model, we want to add new attributes we will retrieve from FB (like the profile picture, the username, or the FB token in order to use FB API). Generate a new migration for that


```
rails g migration AddColumnsToUsers first_name last_name picture name token token_expiry:datetime
```

And run `rake db:migrate` to run this migration


Then add the `find_for_facebook_oauth` in your user model. This is the one we call in the facebook action of our callbacks controller. This method will retrieve all user's infos from fb callbacks.

```ruby
def self.find_for_google_oauth2(oauth, signed_in_resource=nil)
  credentials = oauth.credentials
  data = oauth.info
  user = User.where(email: data["email"]).first


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
  user.get_google_contacts   # Wait for next section
  user.get_google_calendars  # Wait for next section
  user
end
```


### Get a cool navbar with Google profile pic

We are nice buddies, we give you the code for a wunderbar-navbar integrating fb profile pic.

```html
<nav class="navbar navbar-default" role="navigation">
  <div class="container-fluid">
    <!-- Brand and toggle get grouped for better mobile display -->
    <div class="navbar-header">
      <a class="navbar-brand" href="#">FACEBOOK-CONNECT</a>
    </div>

    <!-- Collect the nav links, forms, and other content for toggling -->
    <div class="collapse navbar-collapse" id="bs-example-navbar-collapse-1">
      <ul class="nav navbar-nav navbar-right">

        <% if user_signed_in? %>
        <li class="dropdown">
          <% if current_user.provider %>
            <a href="#" class="dropdown-toggle" data-toggle="dropdown"><%= image_tag current_user.picture, class: "img img-circle" %><b class="caret"></b></a>
          <% else %>
            <a href="#" class="dropdown-toggle" data-toggle="dropdown"><%= current_user.email %><b class="caret"></b></a>
          <% end %>
          <ul class="dropdown-menu">
            <li><%= link_to "Sign Out", destroy_user_session_path, method: :delete %></li>
          </ul>
        </li>
        <% else %>

        <% end %>
      </ul>
    </div><!-- /.navbar-collapse -->
  </div><!-- /.container-fluid -->
</nav>
```

Even some css rules to make your navbar look nice

```css
.navbar {
  height: 80px;
}

.navbar >.container-fluid .navbar-brand {
  line-height: 50px;
}

.navbar-default .navbar-nav>li>a {
  line-height: 50px;
}

```


## Now the cool part

You can play with Google APIs thanks to the [Oauth playground](https://developers.google.com/oauthplayground/). Make some experiments on that before you code

### Google contacts API

Generate a `Contact` model with

```bash
$ rails g model contact email name tel picture
```

Now add this new method to your user model to store all the contacts of the user when he first logs in.

```ruby
def get_google_contacts

  uri = URI.parse("https://www.google.com/m8/feeds/contacts/default/full?access_token=#{token}&alt=json&max-results=100")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)
  result = http.request(request).body
  my_contacts = ActiveSupport::JSON.decode(result)['feed']['entry']

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
```

### Google calendar API

Now, in the same way, generate a model for the events:

```bash
rails g model event name creator start status link calendar
```

And now the methods in your model to call the calendar API

```ruby
def get_google_calendars

  uri = URI.parse("https://www.googleapis.com/calendar/v3/users/me/calendarList?access_token=#{token}")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)
  result = http.request(request).body
  calendars = ActiveSupport::JSON.decode(result)["items"]

  calendars.each { |cal| get_events_for_calendar(cal) }

end

def get_events_for_calendar(cal)

  uri = URI.parse("https://www.googleapis.com/calendar/v3/calendars/#{cal["id"]}/events?access_token=#{token}")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)
  result = http.request(request).body
  my_events = ActiveSupport::JSON.decode(result)["items"]

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
```