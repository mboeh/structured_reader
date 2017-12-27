require 'bundler/setup'

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
        height: nil
      },
      lastUpdated: "2017-12-24 01:01 AM PST"
    },
    {
      widgetType: "frobulator",
      price: "0.79",
      tags: [123, { foo: "bar" }],
      lastUpdated: nil
    }
  ],
  pagination: {
    nextUrl: nil,
    totalItems: 2
  }
}

result = reader.validate(document)

p result.ok?
p result.errors
