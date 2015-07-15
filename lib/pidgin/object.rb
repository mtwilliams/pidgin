module Pidgin
  module Object
    module DomainSpecificLanguage
      module ClassMethods
        def eval(inlined_props={}, &block)
          inlined_props ||= {}
          object_klass = Kernel.const_get(self.name.split('::')[0..-2].join('::'))
          puts "Pidgin::Object::DomainSpecificLanguage.eval for #{object_klass}"

          # Handle inlined properties, adjusting |inlined_props| as we go along.
          instances_of_props = {}
          allowable_inlined_props = object_klass.class_variable_get(:@@properties)
                                      .select { |prop| prop.inline? }
          allowable_inlined_props.each do |allowable_inlined_prop|
            instances_of_prop = inlined_props.select { |name, _| name == allowable_inlined_prop.name }
            specified_at_least_once = instances_of_prop.length > 0
            specified_more_than_once = instances_of_prop.length > 1
            if specified_more_than_once
              # Freak out, because there's no 'good' way to handle the same inlined
              # propeter being specified twice. Note however, that this shouldn't
              # occur, at least if |inlined_props| is a hash.
              raise ArgumentError.new("The inlined property `#{allowable_inlined_prop.name}' was specified more than once?!")
            elsif specified_at_least_once
              instance_of_prop = instances_of_prop.first
              instances_of_sub_props = {}
              # TODO(mtwilliams): Refactor out the commonality between these.
              allowable_inlined_prop.sub_properties.each do |allowable_sub_prop|
                instances_of_sub_prop = inlined_props.select { |name, _| name == allowable_sub_prop.name }
                specified_at_least_once = instances_of_sub_prop.length > 0
                specified_more_than_once = instances_of_sub_prop.length > 1
                if specified_more_than_once
                  # Similar deal.
                  raise ArgumentError.new("The inlined sub-property `#{allowable_sub_prop.name}' was specified more than once?!")
                elsif specified_at_least_once
                  instance_of_sub_prop = instances_of_sub_prop.first
                  sub_prop = allowable_sub_prop.type.new(instance_of_sub_prop[1])
                  instances_of_sub_props.merge! Hash[allowable_sub_prop.name, sub_prop]
                end
                inlined_props.reject! { |name, _| name == allowable_sub_prop.name }
              end
              # TODO(mtwilliams): Refactor?
              case allowable_inlined_prop.type.name.to_sym
                when :nil
                  # TODO(mtwilliams): Freak out, proper.
                  raise "..."
                when :TrueClass
                  instances_of_props = instances_of_props.merge! Hash[allowable_inlined_prop.name, !!instance_of_prop[1]]
                when :FalseClass
                  instances_of_props = instances_of_props.merge! Hash[allowable_inlined_prop.name, !!!instance_of_prop[1]]
                else
                  prop = allowable_inlined_prop.type.new(instance_of_prop[1], instances_of_sub_props)
                  instances_of_props = instances_of_props.merge! Hash[allowable_inlined_prop.name, prop]
                end
              inlined_props.reject! { |name, _| name == allowable_inlined_prop.name }
            end
          end

          # If any arguments remain, then the user has done something wrong.
          raise ArgumentError.new("Unknown properties were supplied inline.") unless inlined_props.empty?

          # Use the builder pattern to create an instance of the object, however
          # proxy all of the DSL user's calls so they don't stomp on internals.
          object_builder = ((Class.new do
            def initialize(klass, properties)
              @klass = klass
              @properties = properties
              @sub_objects = {}
            end

            def build
              object_inst = @klass.new
              @sub_objects.each { |name, sub_object_inst|
                if sub_object_inst.is_a? Array
                  # TODO(mtwilliams): Handle inflections better... by using collection's name?
                  object_inst.instance_variable_set("@#{name}s".to_sym, sub_object_inst)
                else
                  object_inst.instance_variable_set("@#{name}".to_sym, sub_object_inst)
                end
              }
              @properties.each { |name, property| object_inst.instance_variable_set("@#{name}".to_sym, property) }
              object_inst.freeze
            end
          end).new(object_klass, instances_of_props))

          (Class.new do
            def initialize(klass, builder)
              @klass = klass
              @builder = builder
            end

            def method_missing(name, *args, &block)
              objects = @klass.class_variable_get(:@@objects)
              collections = @klass.class_variable_get(:@@collections)
              properties = @klass.class_variable_get(:@@properties)
              if objects.any? { |object| object.name == name }
                object = (objects.select { |object| object.name == name }).first
                object_inst = Kernel.const_get("#{object.type}::DSL").eval(args.first, &block)
                raise "Tried to redefine `#{object.name}'!" if @builder.instance_variable_get(:@sub_objects).include? object.name
                @builder.instance_variable_get(:@sub_objects)[object.name] = object_inst
                object_inst
              elsif collections.any? { |collection| collection.object.name == name }
                collection = (collections.select { |collection| collection.object.name == name }).first
                object = collection.object
                object_inst = Kernel.const_get("#{object.type}::DSL").eval(args.first, &block)
                @builder.instance_variable_get(:@sub_objects)[object.name] ||= []
                @builder.instance_variable_get(:@sub_objects)[object.name] << object_inst
                object_inst
              elsif properties.any? { |property| property.name == name }
                property = (properties.select{ |prop| prop.name == name }).first
                raise ArgumentError.new("Excepted sub-properties as a second argument!") if (args.length > 1) && !(args[1].is_a? Hash)
                property_inst = property.type.new(args[0], args[1])
                @builder.instance_variable_get(:@properties).merge!({property.name => property_inst})
                property_inst
              else
                super
              end
            end
          end).new(object_klass, object_builder).instance_eval(&block)

          object = object_builder.build
          return object
        end
      end

      def self.included(klass)
        klass.extend(ClassMethods)
      end
    end

    module ClassMethods
      def object(name, type)
        object_klass = Kernel.const_get(self.name)
        object = OpenStruct.new({:name => name, :type => type})
        object_klass.class_variable_get(:@@objects) << object
        object
      end

      def collection(name, type)
        object_klass = Kernel.const_get(self.name)
        collection = OpenStruct.new({:object => OpenStruct.new({:name => name, :type => type})})
        object_klass.class_variable_get(:@@collections) << collection
        collection
      end

      def property(name, type, opts={})
        object_klass = Kernel.const_get(self.name)
        property = Property.new(name, type, opts)
        object_klass.class_variable_get(:@@properties) << property
        property
      end
    end

    def self.included(klass)
      klass.class_variable_set(:@@objects, [])
      klass.class_variable_set(:@@collections, [])
      klass.class_variable_set(:@@properties, [])
      klass.extend(ClassMethods)
      klass.const_set(:DSL, Class.new do
        include Pidgin::Object::DomainSpecificLanguage
      end)
    end
  end
end
