module Permissable
  
  module Member
    
    def self.included(base)      
      base.send :include, InstanceMethods
      member_klass = (base.permissable_by_association) ? base.permissable_by_association.to_s.classify.constantize : base
      member_klass.class_eval do 
        has_many :permissions, :as => :member, :conditions => { :member_type => "#{self.to_s}" }
      end
      base.send :include, ((base.permissable_by_association) ? AssociatedMethods : MemberMethods)
    end
    
    # This module includes methods that should exist on ALL members.
    module InstanceMethods
      
      # When a member is initialized, its definitions are eager-loaded to cut down on database queries.
      # Once loaded all of the permission definitions are cached into the @permission_definitions variable.
      attr_accessor :permission_definitions
      
      # Can this member perform the requested action?
      def can?(method, resource)
        method = method.to_s       
        permissions.for_resource(resource).with_permission_to(method).exists?
      end
      
      # Set a permission
      def can!(methods, resource)
        methods = [methods].flatten.uniq
        
        members.each do |member|
          methods.each do |perm|
            next if resource.permissions.for_member(member).with_permission_to(perm).exists?
            new_permission = Permission.new({ :permission_type => method.to_s })
            new_permission.member   = m
            new_permission.resource = resource
            new_permission.save 
          end
        end        
      end
      
      def cannot?(methods, resource)
        !can?(methods, resource)
      end
      
      def cannot!(methods, resources)
        methods  = [methods].flatten.uniq
        existing = permissions.for_resource(resource).with_permission_to(methods).all.collect{ |perm| perm.id }
        Permission.destroy(existing)
      end
      
      def permissions_for(resource)
        permissions.for_resource(resource).all.collect{ |p| p.permission_type.to_sym }.uniq
      end
      
      def permissions_for?(resource)
        !permissions_for(resource).empty?
      end
      
      private
      
      def get_const(resource)
        resource.class.to_s.classify.constantize
      end
            
    end
    
    # This module gets included on member classes that are permissable directly.
    module MemberMethods
      alias_attribute :member_id, :id
      def members; [self]; end
    end
    
    # This module gets included on member classes that are permissable with an association.
    module AssociatedMethods
      
      attr_reader :permissions
      attr_reader :member_id
      
      def permissions
        return @permissions unless @permissions.nil?
        @permissions = Permission.where(:member_id => member_id, :member_type => association.to_s)
      end
      
      def association
        permissable_by_association.to_s.classify.constantize
      end
      
      def member_id
        @member_id || association.all.collect{ |a| a.attributes['id'] }
      end
      
      def members
        association.all
      end
      
    end
    
  end
  
end