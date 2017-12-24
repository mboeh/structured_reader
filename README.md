# StructuredReader

This library allows you to create declarative rulesets (or schemas) for reading primitive data structures (hashes + arrays + strings + numbers) or JSON into validated data objects.

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

```ruby
require 'structured_reader'

reader = StructuredReader.json do |o|
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
  o.object :pagination do |pg|
    pg.string :next_url, "nextUrl", nullable: true
    pg.number :total_items, "totalItems"
  end
end

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
      lastUpdated: "2017-12-24 01:05 AM PST"
    }
  ],
  pagination: {
    nextUrl: nil,
    totalItems: 2
  }
}

result = reader.read(document)

p result.widgets.length # ==> 2
p result.widgets[0].dimensions.height # ==> 9001
p result.widgets[0].tags # ==> ["mysterious", "magical"]
p result.widgets[1].last_updated_at # ==> #<DateTime: 2017-12-24T01:05:00-08:00 ((2458112j,32700s,0n),-28800s,2299161j)>
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mboeh/structured_reader.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
