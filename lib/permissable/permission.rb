class Permission < ActiveRecord::Base
  belongs_to :member,   :polymorphic => true
  belongs_to :resource, :polymorphic => true
  
  class << self
    
    def for_resource(resource)
      resource = Permissable.flatten_resource(resource)
      where(resource)
    end
    
    def for_member(member)
      where(member)
    end
    
    def with_permission_to(methods)
      where(:permission_type => [methods].flatten.uniq.collect{ |m| m.to_s.downcase })
    end
    
  end
    
end