class Permission < ActiveRecord::Base
  belongs_to :member,   :polymorphic => true
  belongs_to :resource, :polymorphic => true
  
  class << self
    def for_member(member)
      where(:member_id => member.id, :member_type => member.class.to_s)
    end
    
    def for_resource(resource)
      where(:resource_id => resource.id, :resource_type => resource.class.to_s)
    end
    
    def for_member_and_resource(member, resource)
      for_member(member).for_resource(resource)
    end
    
    def with_permission_to(perm)
      where(:permission_type => perm.to_s)
    end
  end
  
end