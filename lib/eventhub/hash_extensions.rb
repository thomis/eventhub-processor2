# HashExtensions module
module HashExtensions
  # ClassMethods module
  module ClassMethods
  end

  # InstanceMethods module
  module InstanceMethods
    # get value from provided key path
    # e.g. hash.get(%w(event_hub plate.queue1 retry_s))
    # "a" => { "b" => { "c" => { "value"}}}
    def get(arg)
      path = arg.is_a?(String) ? arg.split('.') : arg
      path.inject(self, :[])
    end

    # set value from provided key path, e.h. hash.set('a.b.c','new value')
    # if overwrite is false, value will be set if it was nil previously
    def set(arg, value, overwrite = true)
      *key_path, last = arg.is_a?(String) ? arg.split('.') : arg
      if overwrite
        key_path.inject(self) { |h, key| h.key?(key) ? h[key] :  h[key] = {} } [last] = value
      else
        key_path.inject(self) { |h, key| h.key?(key) ? h[key] :  h[key] = {} } [last] ||= value
      end
    end

    # get all keys with path,
    # { 'a' => 'v1', 'b' => { 'c' => 'v2'}}.all_keys_with_path => ['a','b.c']
    def all_keys_with_path(parent = nil)
      a = []
      each do |k, v|
        if v.is_a?(Hash)
          a << v.all_keys_with_path([parent, k].compact.join('.'))
        else
          a << [parent, k].compact.join('.').to_s
        end
      end
      a.flatten
    end
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
end

HashExtensions.included(Hash)
