module Permissable
  
  module Member
    
    def self.included(base)
      
      base.send :include, InstanceMethods
      
      if base.permissable_by_association
        base.send :include, AssociatedMethods
        # Add a has many to our association so it can find permissions.
        base.permissable_by_association.to_s.classify.constantize.class_eval do
          has_many :permissions, :as => :member, :conditions => { :member_type => "#{self.to_s}" }
        end
      else
        base.send :include, MemberMethods
      end
    end
    
    # This module includes methods that should exist on ALL members.
    module InstanceMethods
      
      # Can this member perform the requested action?
      def can?(method, resource)
        method = method.to_s
        permissions.for_resource(resource).with_permission_to(method).exists?
      end
      
      # Set a permission
      def can!(method, resource)
        method    = method.to_s.downcase
        klassname = permissable_by_association ? permissable_by_association.to_s.classify : self.class.to_s
        
        members.each do |m|
          next if resource.permissions.for_member_and_resource(m,resource).exists?
          new_permission = Permission.new()
          new_permission.member   = m
          new_permission.resource = resource
          new_permission.permission_type = method
          new_permission.save 
        end
        
      end
      
      def permissions_for(resource)
        if resource.is_a?(Class)
          permissions_scope[resource.to_s]
        else
          permissions.for_resource(resource).all.collect{ |p| p.permission_type.to_sym }.uniq
        end
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