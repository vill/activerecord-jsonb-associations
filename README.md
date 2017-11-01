# Activerecord::Jsonb::Associations

Use PostgreSQL JSONB fields to store association information of your models.

## Usage

### One-to-one and One-to-many associations

```ruby
class Profile < ActiveRecord::Base
  # Setting additional :store option on :belongs_to association
  # enables saving of foreign ids in :extra JSONB column 
  belongs_to :user, store: :extra
end

class SocialProfile < ActiveRecord::Base
  belongs_to :user, store: :extra
end

class User < ActiveRecord::Base
  # Parent model association needs to specify :foreign_store
  # for associations with JSONB storage
  has_one :profile, foreign_store: :extra
  has_many :social_profiles, foreign_store: :extra
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activerecord-jsonb-associations'
```

And then execute:

```bash
$ bundle install
```

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
