module Permissable
  
  module Member
    
    def self.included(base)      
      base.send :include, InstanceMethods
      base.send :attr_protected, :member_identifier
    end
     
    # This module includes methods that should exist on ALL members.
    module InstanceMethods
      
      # The can? method returns a boolen value specifying whether or not this member can perform the specific method on resource
      def can?(method, resource)
        permissions_for(resource, method).exists?
      end
      
      # Alias to can? to get the inverse.
      def cannot?(method, resource); !can?(method, resource); end
      
      
      # This sets the member information for our permission lookup based on the current resource scope.
      # These attributes correspond to the correct member_id and member_type in our permissions table.
      def member_identifier(scope)
        
        @member_identifier ||= {}
        # The scope should be the classname of a resource we are getting identifiers for
        scope = scope.to_s.classify
        
        return @member_identifier[scope] unless @member_identifier[scope].nil?
        return { :member_id => self.id, :member_type => self.class.to_s } unless permissable_associations.has_key?(scope)
        
        assoc_key = permissable_associations[scope]
        assoc     = send "#{assoc_key}".to_sym
        
        @member_identifier[scope] = { :member_id => (assoc.is_a?(Array) ? assoc.collect{ |a| a.id } : assoc.id ), :member_type => assoc_key.to_s.classify }
        
      end
          
      # Provide an instance method to our associations
      def permissable_associations; self.class.permissable_associations; end
      
      private 
      
      # Looks up permissions for a particular resource.
      def permissions_for(resource, methods = nil)
        scope  = resource.class.to_s.classify
        return self.permissions unless permissable_associations.has_key?(scope)
        relation = Permission.where(member_identifier(scope)).for_resource(resource)
        relation = relation.with_permission_to(methods) unless methods.nil?
        relation
      end
      
    end
    
  end
  
end