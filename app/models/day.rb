class Day < ActiveRecord::Base
  # Accessors for instance variables.
  attr_accessor :error, :assigned_as
  
  # Relationships.
  has_many :assignments
  has_many :assigned_users, :through => :assignments, :source => :user

  has_many :user_restrictions
  has_many :restricted_users, :through => :user_restrictions, :source => :user

  has_many :role_restrictions
  has_many :restricted_role_types, :through => :role_restrictions, :source => :role_type

  has_many :required_roles
  has_many :required_role_types, :through => :required_roles, :source => :role_type
  
  
  # 
  # Create a JSON payload from the Day model and its
  # relationships.
  def get_payload
    payload = {
      :day => self.date.strftime('%b %d, %Y'),
      :assigned_users => [],
      :required_roles => [],
      :restricted_roles => [],
      :required_user_count => self.required_user_count
    }
    
    # User types that cannot be assigned to this day.
    self.restricted_role_types.each do |role_type|
      payload[:restricted_roles] << role_type.name
    end
    
    # Roles that are required on the day.
    self.required_roles.each do |required_role|
      role_type = required_role.role_type
      tmp_struct = {
        :count => required_role.count,
        :name => role_type.name
      }
      payload[:required_roles] << tmp_struct
    end

    # Users attached to this day.
    user_lookup = {}
    self.assigned_users.each do |user|
      user_lookup[user.id] = user.get_payload
      user_lookup[user.id][:tags] = []
      payload[:assigned_users] << user_lookup[user.id]
    end
        
    # Return the tags attached to a given user.
    self.assignments.each do |assignment|
      assignment.applied_tags.each do |tag|
        puts 'user id ' + assignment.user_id.to_s + ' tag ' + tag.text
        user_lookup[assignment.user_id][:tags] << tag.text
        user_lookup[assignment.user_id][:tags] = user_lookup[assignment.user_id][:tags].to_set.to_a # Make sure elements remain unique.
      end
    end
    
    payload
  end
  
  # Can this user be assigned to this day?
  # Check restrictions and requirements.
  def can_assign? user
    
    # Fetch the type of the user being added.
    if user.role_types[0]
      user_role = user.role_types[0].name
    else
      user_role = 'Any Type'
    end
    
    # Does this user match any restrictions?
    self.restricted_role_types.each do |role_type|
      if user_role == role_type.name
        @error = "You are restricted from assigning users of the type '" + user_role + "' to this day."
        return false
      end
    end
    
    # Does this user fit into a category of required
    # users that is not yet filled?
    self.required_roles.each do |required_role|
      role_type = required_role.role_type
      if user_role == role_type.name 
        if required_role.count > self.sum_users(user_role)
          self.assigned_as = user_role
          return true
        end
      end
    end
    
    # Perhaps we have slots available for any type of user on this day?
    puts 'Users required ' + required_user_count.to_s
    if self.required_user_count > self.sum_any_users
      self.assigned_as = 'any'
      return true
    end
    
    @error = "You cannot currently add a user of type '" + user_role + "' to this day."
    return false;
  end
  
  # Count the number of users assigned for
  # a given role type.
  def sum_users role_name
    count = 0
    self.assignments.each do |assignment|
      if assignment.assignment_type == role_name
        count += 1
      end
    end
    return count
  end
  
  # Sums the number of users assigned within the 'any'
  # category.
  def sum_any_users
    count = 0
    self.assignments.each do |assignment|
      if assignment.assignment_type == 'any'
        count += 1
      end
    end
    puts count.to_s
    return count
  end
  
  # Return an array of emails that should be notified
  # on a given day.
end
