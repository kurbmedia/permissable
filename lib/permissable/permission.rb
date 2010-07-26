class Permission < ActiveRecord::Base
  belongs_to :member,   :polymorphic => true
  belongs_to :resource, :polymorphic => true
  
  class << self
    def for_member(member)
      member = flatten(member)
      where(:member_id => member[:ids], :member_type => member[:types])
    end
    
    def for_resource(resource)
      resource = flatten(resource)
      where(:resource_id => resource[:ids], :resource_type => resource[:types])
    end
    
    def for_member_and_resource(member, resource)
      for_member(member).for_resource(resource)
    end
    
    def with_permission_to(perm)
      perm = perm.is_a?(Array) ? perm.collect{ |p| p.to_s } : perm.to_s
      where(:permission_type => perm)
    end
    
    def flatten(obj)
      return { :ids => obj, :types => obj.class.to_s } unless obj.is_a?(Array)
      { :ids => obj.collect{ |o| o.id }, :types => obj.collect{ |o| o.class.to_s } }
    end
    
  end
    
end