# Author: Brent Kirby
# Copyright:: Copyright (c) 2010 kurb media, llc.
# License:: MIT License (http://www.opensource.org/licenses/mit-license.php)
#
# Permissable creates the ability to add a permissions system to "resources" based on a "member".
# It allows you to define a member using the +permissable+ method:
#
#  class User < ActiveRecord::Base
#    permissable do |configure|
#      configure.permission_for :read, :posts, :categories
#      configure.permission_for [:read, :write, :moderate], :comments
#    end
#  end
#
# Permissable uses a single "permissions" table (and subsuquently a Permission model), with a polymorphic relationship
# between both the member and the resource.

require 'permissable/member'
require 'permissable/permission'
require 'permissable/resource'

module Permissable
    
    class << self
            
      def included(base)
        base.extend ClassMethods
      end     
      
    end
    
    class PermissableError < StandardError
    end
    
    class PermissionNotDefined < PermissableError
    end
    
    class ResourceNotPermissable < PermissableError
    end
    
    module ClassMethods
      
      # +permissable+ gives the class its called on the ability to effect various permission states on the resources
      # it specifies. It accepts an options hash and a block. The following options are supported:
      #
      # * with: This is an association of the primary member class. This allows you to use an association to determine
      #   which permissions are available. One example of this would be to assign permission to Roles of a User class.
      #   In this case, when doing lookups, it will use the permissions assigned to each Role the user belongs to.
      #   The with option accepts the association in the same manner as you would define it in active record.
      #   ie: has_many roles would be: :with => :roles. belongs_to role would be :with => :role
      def permissable(options = {})
        
        write_inheritable_attribute :permissable_by_association, (options[:with] || false)
        class_inheritable_reader :permissable_by_association
        
        write_inheritable_attribute :has_permissions_for, []
        class_inheritable_accessor :has_permissions_for

        # The class that called permissable becomes a member.
        include Permissable::Member
        
        # Yield the permissions block to add permissions.
        yield self
        
      end
      
      # +permission_for+ is called via the permissable block
      def permission_for(methods, *resources)
        
        methods = [methods].flatten
        
        # Add each resource to the member class' permissions list.
        has_permissions_for.concat(resources).flatten.uniq
        
        resources.uniq.each do |resource|          
          #Include the Resource module to each resource class.
          resource.to_s.classify.constantize.class_eval{ include Permissable::Resource }
          resource.to_s.classify.constantize.send :set_permissions!, methods
        end
        
      end   
         
    end    
end

ActiveRecord::Base.send :include, Permissable