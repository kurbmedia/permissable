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
      
      # Assign permissions to a member if they don't already exist.
      # TODO: There has to be a friendlier way to mass assign permissions to roles rather than
      # looping each one for existence and then saving separately.
      def can!(methods, resources)
        [resources].flatten.each do |resource|
          
          # Kind of unecessary but since some methods allow you to specify a Classname directly, this just
          # safegaurds against trying to do the same here.
          next if resource.is_a?(Class)
          
          # Get the member identifier for this resource
          identifier = member_identifier(resource)
          
          [methods].flatten.each do |method|
            # Permission already exists, continue.
            next if can?(method, resource)
            
            # Create a new permission for each member (once if its self, multiple times if its associated)
            [identifier[:member_id]].flatten.each do |member_id|
              perm = Permission.new(:member_id => member_id, :member_type => identifier[:member_type], :permission_type => method.to_s.downcase)
              perm.resource = resource
              perm.save
            end
          end
        end
        
      end
      
      # This sets the member information for our permission lookup based on the current resource scope.
      # These attributes correspond to the correct member_id and member_type in our permissions table.
      def member_identifier(resource)
        
        @member_identifier ||= {}
        scope = fetch_scope(resource)
        
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
        scope  = fetch_scope(resource)
        return self.permissions.with_permission_to(methods) unless permissable_associations.has_key?(scope)
        relation = Permission.where(member_identifier(scope)).for_resource(resource)
        relation = relation.with_permission_to(methods) unless methods.nil?
        relation
      end
      
      # Returns the member responsible for this resource. This can either be an instance of self, or an instance or 
      # array of assocated instances.
      def permissable_member(resource)
        scope  = fetch_scope(resource)
        (permissable_associations.has_key?(scope)) ? send("#{permissable_associations[scope]}".to_sym) : self
      end
      
      def fetch_scope(resource)
        return resource if resource.is_a?(String)
        (resource.is_a?(Class)) ? resource.to_s : resource.class.to_s.classify
      end
      
    end
    
  end
  
end