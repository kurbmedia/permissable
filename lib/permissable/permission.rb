class Permission < ActiveRecord::Base
  belongs_to :member,   :polymorphic => true
  belongs_to :resource, :polymorphic => true
  
  class << self
    
    def for_resource(resource)
      resource = flatten(resource)
      where(resource)
    end
    
    def with_permission_to(methods)
      where(:permission_type => [methods].flatten.uniq.collect{ |m| m.to_s.downcase })
    end
    
    def flatten(obj)
      return { :resource_id => obj, :resource_type => obj.class.to_s } unless obj.is_a?(Array)
      { :resource_id => obj.collect{ |o| o.id }, :resource_type => obj.collect{ |o| o.class.to_s } }
    end
    
  end
    
end