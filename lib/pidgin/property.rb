module Pidgin
  class Property
    def initialize(name, type, opts={})
      @name = name
      @type = type
      @inline = opts[:inline] || false
      @sub_properties = []
      (opts[:allow] || {}).each do |sub_prop_name, sub_prop_type|
        @sub_properties << Property.new(sub_prop_name, sub_prop_type)
      end
    end

    def name; @name; end
    def type; @type; end
    def inline?; @inline; end
    def sub_properties; @sub_properties; end
  end
end
