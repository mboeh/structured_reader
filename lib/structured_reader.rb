# frozen_string_literal: true

require "structured_reader/version"
require "json"
require "date"

module StructuredReader
  Error = Class.new(StandardError)
  WrongTypeError = Class.new(Error)
  DeclarationError = Class.new(Error)

  def self.json(&blk)
    JSONReader.new(&blk)
  end

  class JSONReader

    def initialize(&blk)
      @root_reader = ObjectReader.new(&blk)
    end

    def read(document, context = Context.new)
      if document.kind_of?(String)
        document = JSON.parse document
      end
      @root_reader.read(document, context)
    end

    class ObjectReader

      class ReaderBuilder

        def initialize(base)
          @base = base
        end

        def method_missing(type, name, field_name = name.to_s, *args, **kwargs, &blk)
          if Readers.has_reader?(type)
            @base.field name, field_name, Readers.reader(type, *args, **kwargs, &blk)
          else
            super
          end
        end

        def respond_to_missing?(type)
          READERS.has_reader?(type) || super
        end

      end

      def initialize(strict: false)
        @readers = {}
        @strict = strict
        yield ReaderBuilder.new(self)
        if @readers.empty?
          raise DeclarationError, "must define at least one field to read"
        end
        @object_klass = Struct.new(*@readers.keys)
        freeze
      end

      def read(fragment, context)
        if fragment.kind_of?(Hash)
          result = @object_klass.new
          @readers.each do |key, (field, reader)|
            value = fragment[field] || fragment[field.to_sym]
            context.push(".#{field}") do |sub_context|
              result[key] = reader.read(value, sub_context)
            end
          end
          if @strict && ((excess_keys = fragment.keys.map(&:to_sym) - @readers.keys)).any?
            return context.flunk(fragment, "found strictly forbidden keys #{excess_keys.inspect}")
          end
          result.freeze

          context.accept(result)
        else
          return context.flunk(fragment, "expected a Hash")
        end
      end

      def field(key, field_name, reader)
        @readers[key.to_sym] = [field_name, reader]
      end

    end

    class ArrayReader

      class ReaderBuilder

        def initialize(base)
          @base = base
        end

        def method_missing(type, *args, **kwargs, &blk)
          if Readers.has_reader?(type)
            @base.member Readers.reader(type, *args, **kwargs, &blk)
          else
            super
          end
        end

        def respond_to_missing?(type)
          Readers.has_reader?(type) || super
        end

      end

      def initialize(of: nil, &blk)
        if block_given?
          yield ReaderBuilder.new(self)
        elsif of
          ReaderBuilder.new(self).send(of)
        end

        unless @member_reader
          raise DeclarationError, "array must have a member type"
        end
      end

      def member(reader)
        @member_reader = reader
      end

      def read(fragment, context)
        if fragment.kind_of?(Array)
          context.accept(fragment.map.with_index do |member, idx|
            context.push("[#{idx}]") do |sub_context|
              @member_reader.read(member, sub_context)
            end
          end)
        else
          context.flunk(fragment, "expected an Array")
        end
      end

    end

    class CollectionReader < ArrayReader

      def initialize(**args, &blk)
        super do |a|
          a.object(&blk)
        end
      end

    end

    class NumberReader

      def initialize(**_)

      end

      def read(fragment, context)
        if fragment.kind_of?(Numeric)
          context.accept fragment
        else
          context.flunk(fragment, "expected a Numeric")
        end
      end

    end

    class StringReader

      def initialize(**_)

      end

      def read(fragment, context)
        if fragment.kind_of?(String)
          context.accept maybe_parse(fragment, context)
        else
          context.flunk(fragment, "expected a String")
        end
      end

      def maybe_parse(fragment, _context)
        fragment
      end

    end

    class TimeReader < StringReader

      def maybe_parse(fragment, context)
        begin
          context.accept DateTime.parse(fragment)
        rescue ArgumentError
          context.flunk(fragment, "could not be converted to a DateTime")
        end
      end

    end

    class LiteralReader

      def initialize(value:)
        @value = value
      end

      def read(fragment, context)
        if fragment == @value
          context.accept fragment
        else
          context.flunk(fragment, "expected #{@value.inspect}")
        end
      end

    end

    class NullReader < LiteralReader

      def initialize(**_)
        super value: nil
      end

    end

    class RawReader

      def initialize(**_)

      end

      def read(fragment, context)
        context.accept fragment
      end

    end

    class OneOfReader

      class ReaderBuilder

        def initialize(base)
          @base = base
        end

        def method_missing(type, *args, **kwargs, &blk)
          if Readers.has_reader?(type)
            @base.option Readers.reader(type, *args, **kwargs, &blk)
          else
            super
          end
        end

        def respond_to_missing?(type)
          Readers.has_reader?(type) || super
        end

      end

      def initialize(**_)
        @readers = []
        yield ReaderBuilder.new(self)
        if @readers.empty?
          raise DeclarationError, "must define at least one option"
        end
        freeze
      end

      def read(fragment, context)
        @readers.each do |reader|
          if reader.read(fragment, ValidatorContext.new).empty?
            return context.accept(reader.read(fragment, context))
          end
        end

        context.flunk(fragment, "was not any of the expected options")
      end

      def option(reader)
        @readers << reader
      end

    end

    class Context

      def initialize(where = "")
        @where = where.dup.freeze
      end

      def accept(fragment)
        fragment
      end

      def flunk(fragment, reason)
        raise WrongTypeError, "#{reason}, got a #{fragment.class} (at #{@where})"
      end

      def push(path, &blk)
        yield self.class.new(@where + path)
      end

    end

    class ValidatorContext

      def initialize(where = "", errors = [])
        @where = where.dup.freeze
        @errors = errors
      end

      def accept(fragment)
        @errors
      end

      def flunk(fragment, reason)
        @errors << [@where, reason]
      end

      def push(path)
        yield self.class.new(@where + path, @errors)
      end

    end

    class SelectionContext

      def initialize(target, where = "", found = [])
        @target = target
        @where = where
        @found = found
      end

      def accept(fragment)
        if File.fnmatch(@target, @where)
          @found << fragment
          fragment
        else
          if @found.any?
            @found.first
          else
            unless @where.empty?
              fragment
            end
          end
        end
      end

      def flunk(fragment, reason)
        nil
      end

      def push(path)
        if @found.empty?
          yield self.class.new(@target, @where + path, @found)
        end
      end

    end

    module Readers
      extend self

      READERS = {
        array: ArrayReader,
        collection: CollectionReader,
        string: StringReader,
        time: TimeReader,
        object: ObjectReader,
        number: NumberReader,
        one_of: OneOfReader,
        null: NullReader,
        raw: RawReader,
        literal: LiteralReader,
      }

      def reader(type, *args, **kwargs, &blk)
        if kwargs[:nullable]
          kwargs = kwargs.dup
          kwargs.delete :nullable
          OneOfReader.new do |o|
            o.null
            o.send(type, *args, **kwargs, &blk)
          end
        else
          READERS.fetch(type).new(*args, **kwargs, &blk)
        end
      end

      def has_reader?(type)
        READERS.has_key?(type)
      end
    end

  end

end
