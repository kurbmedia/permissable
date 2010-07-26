module Permissable
  
  module Resource
    
    def self.included(base)
      base.class_eval{ has_many(:permissions, :as => :resource, :conditions => { :resource_type => "#{self.to_s}" }) }
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      private 
      def set_permissions!(permission_list)
        class_inheritable_accessor :permissable_methods
        write_inheritable_attribute(:permissable_methods, []) if permissable_methods.nil?
        permissable_methods.concat permission_list.uniq.flatten
      end
    end
    
  end
  
end