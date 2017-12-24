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

# This uses filename globbing for now, not proper XPath-style wildcards
context = StructuredReader::JSONReader::SelectionContext.new(".widgets\\[*\\].price")

result = reader.read(document, context)

p result
