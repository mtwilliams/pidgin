module Pidgin
  module DomainSpecificLanguage
    class Evaluator
      def initialize(dsl)
        @dsl = dsl
        @objects = {}
      end

      def method_missing(name, *args, &block)
        objects = @dsl.class_variable_get(:@@objects)
        collections = @dsl.class_variable_get(:@@collections)
        if collections.any? { |collection| collection.object.name == name }
          collection = (collections.select { |collection| collection.object.name == name }).first
          object = collection.object
          object_inst = Kernel.const_get("#{object.type}::DSL").eval(args.first, &block)
          @objects[object.name] ||= []
          @objects[object.name] << object_inst
        elsif (objects.any? { |object| object.name == name })
          object = (objects.select { |object| object.name == name }).first
          object_inst = Kernel.const_get("#{object.type}::DSL").eval(args.first, &block)
          raise "Tried to redefine `#{object.name}'!" if @objects.include? object.name
          @objects[object.name] = object_inst
        else
          super
        end
      end
    end

    module ClassMethods
      def object(name, type)
        dsl = Kernel.const_get(self.name)
        object = OpenStruct.new({:name => name, :type => type})
        dsl.class_variable_get(:@@objects) << object
        object
      end

      def collection(name, type)
        dsl = Kernel.const_get(self.name)
        # TODO(mtwilliams): Handle inflections better.
        collection = OpenStruct.new({:object => OpenStruct.new({:name => name, :type => type})})
        dsl.class_variable_get(:@@collections) << collection
        collection
      end

      def eval(code)
        dsl = Kernel.const_get(self.name)
        evaluator = Evaluator.new(dsl)
        evaluator.instance_eval(code)
        evaluator.instance_variable_get(:@objects).freeze
      end
    end

    def self.included(klass)
      klass.class_variable_set(:@@objects, [])
      klass.class_variable_set(:@@collections, [])
      klass.extend(ClassMethods)
    end
  end
end
