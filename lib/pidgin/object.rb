module Pidgin
  module Object
    module DomainSpecificLanguage
      module ClassMethods
        def eval(inlined_props={}, &block)
          object_klass = Kernel.const_get(self.name.split('::')[0..-2].join('::'))

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
            end

            def build
              object = @klass.new
              @properties.each { |name, property| object.instance_variable_set("@#{name}".to_sym, property) }
              object.freeze
            end
          end).new(object_klass, instances_of_props))

          Docile.dsl_eval(((Class.new do
            def initialize(klass, builder)
              @klass = klass
              @builder = builder
            end

            def method_missing(name, *args, &block)
              properties = @klass.class_variable_get(:@@properties)
              # TODO(mtwilliams): Handle sub-objects.
              super unless properties.any? { |prop| prop.name == name }
              property = (properties.select{ |prop| prop.name == name }).first
              # TODO(mtwilliams): Handle sub-properties.
              @builder.instance_variable_get(:@properties).merge!({property.name => property.type.new(args.first)})
            end
          end).new(object_klass, object_builder)), &block)

          object = object_builder.build
          return object
        end
      end

      def self.included(klass)
        klass.extend(ClassMethods)
      end
    end

    module ClassMethods
      def property(name, type, opts={})
        object_klass = Kernel.const_get(self.name)
        property = Property.new(name, type, opts)
        object_klass.class_variable_get(:@@properties) << property
        property
      end
    end

    def self.included(klass)
      klass.class_variable_set(:@@properties, [])
      klass.extend(ClassMethods)
      klass.const_set(:DSL, Class.new do
        include Pidgin::Object::DomainSpecificLanguage
      end)
    end
  end
end
