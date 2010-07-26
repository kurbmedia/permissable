# Author: Brent Kirby
# Copyright:: Copyright (c) 2010 kurb media, llc.
# License:: MIT License (http://www.opensource.org/licenses/mit-license.php)
#
# Permissable creates the ability to add a permissions system to "resources" based on a "member".
# It allows you to define a member using the +has_permissions_for+ method:
#
#  class User < ActiveRecord::Base
#    has_permissions_for [:section, :category, :entry], :to => [:read, :write, :moderate]
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
      
      # +has_permissions_for+ gives the class its called on the ability to effect various permission states on the resources
      # it specifies. It requires two parameters, a resource or array of resources to add permissions to, and an options
      # hash with instructions of how to handle the permissions.
      # The options hash consists of the following keys, but only the :to key is required.
      #
      # * +to+: This is a permission or array of permissions allowed. You can use any number of values
      #   and those values can be whatever you want. You must include at least one.
      #
      # * +through+: Allows you to scope permissions through one of the member's associations. For example, if your member is
      #   a User, and that user has_many Roles, you could set permissions :through => :roles. When looking up permissions
      #   Permissable will use the association instead of the main member object. This also applies to setting permissions.
      #   NOTE: The :through option uses the same value as your assocation. If the association is a has_many, the value will be
      #   plural. Likewise belongs_to or has_one associations will be singular. The best way to think of this is that the 
      #   :through attribute would be exactly the same as the method you would call on your model to find its associations.
      #
      def has_permissions_for(resources, options = {})
        raise Permissable::PermissionNotDefined, "has_permissions_for missing the :to option." unless options.has_key?(:to) and !options[:to].empty?
        
        write_inheritable_attribute(:permissable_associations, {}) if permissable_associations.nil?
        resources = [resources].flatten
        
        resources.each do |resource| 
          resource = resource.to_s.classify          
          
          # If there is an association on these resources, add those to our associations attribute
          # so our classes and sub classes will know about it.
          if options.has_key?(:through)
            
            permissable_associations[resource] = options[:through]
            assoc = options[:through].to_s.classify.constantize
            
            # Our association also creates a has_many association on our permissions table.
            assoc.class_eval do
              has_many(:permissions, :as => :member, :conditions => { :member_type => "#{self.to_s}" }) unless respond_to? :permissions
            end
                        
          end
          
          # Setup a has_many association of permissions on our resource.
          resource.constantize.class_eval do 
            include Permissable::Resource
            has_many(:permissions, :as => :resource, :conditions => { :resource_type => "#{self.to_s}" }) unless respond_to? :permissions
          end
          
        end
        
        # This class becomes a member to resources.
        include Permissable::Member
        
        # Members create a has_many association on permissions as a member.
        has_many(:permissions, :as => :member, :conditions => { :member_type => "#{self.to_s}" }) unless respond_to? :permissions
        
      end 
      
      # Each time has_permissions_for is called, different associations may exist.
      # This provides a way to store and update them all as necessary.
      def permissable_associations
        read_inheritable_attribute(:permissable_associations)
      end  
         
    end    
end

ActiveRecord::Base.send :include, Permissable