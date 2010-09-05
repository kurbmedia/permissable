module Permissable
  
  class PermissionsCache
    
    attr_accessor :_permissions
    attr_accessor :_query_results
    
    def initialize(permission_list)
      @_permissions   = permission_list
      @_query_results = nil
    end
    
    def for_member(member)
      arr = create_result_array
      @_query_results = arr.find_all do |perm|  
        (member.key?(:member_type) ? true : perm.member_type == member[:member_type]) && [member[:member_id]].flatten.uniq.include?(perm.member_id)
      end
      
      return self
      
    end
    
    def for_resource(resource)
      arr = create_result_array
      resource = Permissable.flatten_resource(resource)
      @_query_results = arr.find_all do |perm|
        [resource[:resource_id]].flatten.include?(perm.resource_id) && [resource[:resource_type]].flatten.include?(perm.resource_type)
      end
      
      return self
      
    end
    
    def with_permission_to(methods)
      arr = create_result_array      
      @_query_results = arr.find_all do |perm|
        [methods].flatten.collect{ |m| m.to_s }.include?(perm.permission_type)
      end
      
      return self
      
    end
    
    def all
      results = @_query_results || []
      @_query_results = nil
      results
    end
    
    def exists?
      results = @_query_results || []
      @_query_results = nil
      !results.empty?
    end
    
    private
    
    def create_result_array
      (@_query_results.nil?) ? permissions : @_query_results
    end
    
    def permissions
      @_permissions
    end
    
  end
  
end