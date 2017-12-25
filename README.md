# StructuredReader

[![Build Status](https://travis-ci.org/mboeh/structured_reader.svg?branch=master)](https://travis-ci.org/mboeh/structured_reader) [![Gem Version](https://badge.fury.io/rb/structured_reader.svg)](https://badge.fury.io/rb/structured_reader)

This library allows you to create declarative rulesets (or schemas) for reading primitive data structures (hashes + arrays + strings + numbers) or JSON into validated data objects. Free yourself from `json.fetch(:widget).fetch(:box).fetch(:dimensions).fetch(:width)`. Get that good `widget.box.dimensions.width` without risking NoMethodErrors. Have confidence that if you're passed total unexpected nonsense, it won't be smoothed over by a convenient MagicHashyMash.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'structured_reader'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install structured_reader

## Usage

StructuredReader allows you to declare the expected structure of a JSON document (or any other data structure built on Ruby primitives). Readers are created with a simple domain-specific language (DSL) and are immutable. The declaration is evaluated at the time you create the reader, not every time it's used to read, so it's a good idea to assign it to a constant.

```ruby
require 'structured_reader'

READER = StructuredReader.json do |o|
  o.collection :widgets do |w|
    w.string :type, "widgetType"
    w.number :price
    w.string :description, nullable: true
    w.array :tags, of: :string
    w.object :dimensions, nullable: true do |dims|
      dims.number :weight
      dims.number :width
      dims.number :height
    end
    w.time :last_updated_at, "lastUpdated"
  end
  o.object :pagination, strict: true do |pg|
    pg.string :next_url, "nextUrl", nullable: true
    pg.number :total_items, "totalItems"
  end
end
```

Readers provide a `read` method, which takes either a Hash or a JSON string (which will be parsed and is expected to result in a Hash).

```ruby
document = {
  widgets: [
    {
      widgetType: "squorzit",
      price: 99.99,
      description: "who can even say?",
      tags: ["mysterious", "magical"],
      dimensions: {
        weight: 10,
        width: 5,
        height: 9001
      },
      lastUpdated: "2017-12-24 01:01 AM PST"
    },
    {
      widgetType: "frobulator",
      price: 0.79,
      tags: [],
      comment: "a bonus text",
      lastUpdated: "2017-12-24 01:05 AM PST"
    }
  ],
  pagination: {
    nextUrl: nil,
    totalItems: 2
  }
}

result = READER.read(document)
```

Hashes (objects) are parsed into Ruby Structs. Fields present in the object but not in the declaration are ignored. You can change this behavior by passing `strict: true` to `object`.

```ruby
p result.widgets.length # ==> 2
p result.widgets[0].dimensions.height # ==> 9001
p result.widgets[0].tags # ==> ["mysterious", "magical"]
p result.widgets[1].last_updated_at # ==> #<DateTime: 2017-12-24T01:05:00-08:00 ((2458112j,32700s,0n),-28800s,2299161j)>
p result.widgets[1].comment # ! ==> NoMethodError
```

## Reader Types

* `string`: The classic.
* `number`: Like in JSON, this can be an integer or a float.
* `object`: Must define at least one field.
* `array`: An array containing elements of a single type. Use `one_of` to support arrays of mixed types.
* `collection`: Shorthand for an `array` of `objects`.
* `one_of`: Takes several other reader types and tests them in order, returning the first one that succeeds.
* `literal`: Validates an exact, literal value (e.g. the field must contain "foo" and nothing but "foo"). Can be used with `one_of` to implement discriminated unions; see below.
* `null`: Shorthand for `literal nil`.
* `time`: Expects a String and parses it using DateTime.parse. I am currently thinking about a clean way to declare subtypes of string along the lines of "parsable with a provided parser".
* `raw`: Always validates and returns the unmodified value. May be useful if you have a "payload" or "attributes" structure that you want to pass along to somewhere else.
* `custom`: Define your own personal pan parser.

Reead the specs for more details.

## Advanced Declarations

### Discriminated Unions

It is common to have JSON data structures that use a type field to distinguish between objects with different fields:

```ruby
document = [
  {
    type: "square",
    length: 10,
  },
  {
    type: "rectangle",
    width: 5,
    height: 10,
  },
  {
    type: "circle",
    diameter: 4,
  },
]
```

This can be typed as a _discriminated union_ (or _tagged union_). The `one_of` and `literal` methods can be combined to validate and read this data. (A shorthand method for doing this may be implemented in the future.)

```ruby
reader = StructuredReader.json(root: :array) do |a|
  a.one_of do |shape|
    shape.object do |sq|
      sq.literal :type, value: "square"
      sq.number :length
    end
    shape.object do |rc|
      rc.literal :type, value: "rectangle"
      rc.number :width
      rc.number :height
    end
    shape.object do |cr|
      cr.literal :type, value: "circle"
      cr.number :diameter
    end
  end
end
```

Each element of the array is tested against each option, and the one that succeeds is used. If none match, `StructuredReader::WrongTypeError` will be raised. (If you need a fallback, consider the `raw` type.)

There are some performance implications here. In general, declarations are tested against the data in order. In this case, each element will be tested first to see if it is a square, then to see if it is a rectangle, then to see if it is a circle. It's a good idea when using `one_of` to ensure that the type field (or some other distinguishing field) is declared first, so the tests can fail as fast as possible.

```ruby
result = reader.read(document)

p result.length # ==> 3
p result[0].type # ==> "square"
p result[0].length # ==> 10
p result[2].diameter # ==> 4
p result[0].diameter # ! ==> NoMethodError
```

## Defining Custom Types

The API for this is somewhat experimental. The best reference at this time is the specs.

## Caveats/Missing Features

### Stack depth

The depth of data structures you can read is limited by stack space, because the reading is done by mutual recursion. If you really have to parse a structure too deep for the stack, you can combine multiple layers of readers by using the `raw` type to pluck subdocuments out in unmodified form and then use a second reader to parse that.

### Performance

Unbenchmarked, unoptimized. It should be OK, though.

## Out Of Scope/Unfeatures

* Complex validation support. You can do a lot with `custom` fields, but I advise not pushing business logic into the serialization layer.
* Exact feature compatibility with JSON Schema. Same reason, really. You can use this library to validate JSON, but that's not its purpose.
* Inheritance/subtyping. Too much complexity for not much practical use. I might decide otherwise if I keep running into places it'd be useful.
* Tuples/fixed-length arrays. I don't see these in the wild very frequently, and I'm not a fan. `array`/`one_of` should suffice, and `custom` is there if you need it.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mboeh/structured_reader.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
