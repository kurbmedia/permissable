module Permissable
  
  module Member
    
    def self.included(base)      
      base.send :include, InstanceMethods
      base.send :attr_protected, :member_identifier
      base.send :attr_protected, :permissions_cache
      base.send :attr_protected, :association_scopes
    end
     
    # This module includes methods that should exist on ALL members.
    module InstanceMethods
      
      # The can? method returns a boolen value specifying whether or not this member can perform the specific method on resource
      def can?(methods, resource, chain = true)
        unless allow_permission_with_method.nil?
          if self.respond_to? "#{allow_permission_with_method}"
            return true if (send "#{allow_permission_with_method}")
          end
        end
        
        if chain
          methods = [methods].flatten.collect{ |m| m.to_sym }
          methods = find_methods_from_chain(methods)
        end
        
        permissions_for?(resource, methods)
        
      end
      
      # Alias to can? to get the inverse.
      def cannot?(method, resource); !can?(method, resource); end
      
      # Assign permissions to a member if they don't already exist.
      # TODO: There has to be a friendlier way to mass assign permissions to roles rather than
      # looping each one for existence and then saving separately.
      def can!(methods, resources)
        
        # This method should return all of the new permissions that were created, so we build a 
        # response array to return
        result_response = []
        
        # Load all permissions fresh so we can kill dupes.
        saved_permissions = lookup_permissions!([resources].flatten.collect{ |r| (r.respond_to? :base_class) ? r.base_class.to_s : r.class.base_class.to_s.classify }.uniq)
        saved_permissions = saved_permissions.all
        
        # Store new permissions in an array so we can squeeze into one transaction.
        permissions_to_add    = []
        permissions_to_update = []
        
        [resources].flatten.uniq.each do |resource|
          
          # Kind of unecessary but since some methods allow you to specify a Classname directly, this just
          # safegaurds against trying to do the same here.
          next if resource.is_a?(Class)
          
          # Get the member identifier for this resource
          identifier = member_identifier(resource)
          
          [methods].flatten.each do |method|
            
            resource_type = (resource.respond_to?(:base_class) ? resource.base_class.to_s : resource.class.base_class.to_s)
            
            # Create a new permission for each member (once if its self, multiple times if its associated)
            [identifier[:member_id]].flatten.uniq.each do |member_id|              
              perm = saved_permissions.detect{ |p| p.member_id == member_id && p.member_type == identifier[:member_type] && p.resource_id == resource.id && p.resource_type == resource_type }  || Permission.new(:member_id => member_id, :member_type => identifier[:member_type])
              perm.permission_type = method.to_s.downcase
              perm.resource        = resource if perm.new_record?
              
              if perm.new_record?
                puts "NEW RECORD!!!!!"
                permissions_to_add << perm.attributes
              else
                puts "OLD RECORD!!!"
                permissions_to_update << perm if perm.changed?
              end
              
            end
          end
        end
        
        
        unless permissions_to_add.empty?
          Permission.transaction do
            permissions_to_add.each do |attrs|
              perm = Permission.new(attrs)
              perm.save(:validate => false)
            end
          end
        end
        
        unless permissions_to_update.empty?
          types = permissions_to_update.collect{ |p| p.permission_type.to_s }.uniq
          types.each do |type|
            to_update = permissions_to_update.find_all{ |perm| perm.permission_type.to_s == type }
            Permission.update_all({ :permission_type => type }, { :id => to_update.collect{ |perm| perm.id }.uniq })
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
        
        @association_scopes ||= {}
        assoc_key = permissable_associations[scope]
        @association_scopes[assoc_key] ||= send("#{assoc_key}".to_sym)
        assoc = @association_scopes[assoc_key]
        
        @member_identifier[scope] = { :member_id => (assoc.is_a?(Array) ? assoc.collect{ |a| a.id } : assoc.id ), :member_type => assoc_key.to_s.classify }
        
      end
          
      # Provide an instance method to our associations
      def permissable_associations; self.class.permissable_associations || {}; end
      # Find our permission override if available
      def allow_permission_with_method; self.class.permissable_options[:allow_permission_with_method]; end
      # See if there is a permissions chain
      def permission_chain; self.class.permissable_options[:permission_chain] || {}; end
      
      def permissions_for(resource)
        fetch_permissions_for(resource).all.collect{ |perm| perm.permission_type.to_sym }
      end
      
      def lookup_permissions!(resource_types = nil)

        resource_types ||= self.class.permissable_resources.collect{ |r| r.to_s.classify }
        member_ids   = []
        member_types = []
        
        resource_types.each do |type|
          identifier = member_identifier(type)
          member_ids   << identifier[:member_id]
          member_types << identifier[:member_type]
        end
        
        member_ids   = member_ids.uniq; member_types = member_types.uniq;
        member_ids   = member_ids.first unless member_ids.size > 1
        member_types = member_types.first unless member_types.size > 1
        
        @permissions_cache ||= PermissionsCache.new(Permission.where(:member_id => member_ids, :member_type => member_types, :resource_type => resource_types).all)
        
      end
      
      private 
      
      def find_methods_from_chain(methods)
        
        return methods if permission_chain.empty?
        allowed_methods = []
        
        methods.each do |method|
          permission_chain.each_pair do |key, value|
            value = [value].flatten.collect{ |v| v.to_sym }
            allowed_methods << key.to_sym if value.include?(method)
          end
        end
        
        allowed_methods << methods
        allowed_methods.flatten.uniq
        
      end
      
      # Looks up permissions for a particular resource.
      def fetch_permissions_for(resource, methods = nil)
        scope  = fetch_scope(resource)
        
        lookup_with =  is_cached? ? @permissions_cache : Permission
        relation = lookup_with.for_member(member_identifier(scope)).for_resource(resource)
        relation = relation.with_permission_to(methods) unless methods.nil?
        return relation
        
      end
      
      def fetch_scope(resource)
        return resource if resource.is_a?(String)
        (resource.respond_to? :base_class) ? resource.base_class.to_s : resource.class.base_class.to_s.classify
      end
      
      # Look to see if we have a permissions cache.
      def is_cached?
        !@permissions_cache.nil?
      end
      
      def permissions_for?(resource, methods = nil)
        fetch_permissions_for(resource, methods).exists?
      end
      
      # Returns the member responsible for this resource. This can either be an instance of self, or an instance or 
      # array of assocated instances.
      def permissable_member(resource)
        scope  = fetch_scope(resource)
        (permissable_associations.has_key?(scope)) ? send("#{permissable_associations[scope]}".to_sym) : self
      end
      
    end
    
  end
  
end