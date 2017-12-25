require 'bundler/setup'

require 'structured_reader'

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

result = reader.read(document)

p result.length # ==> 3
p result[0].type # ==> "square"
p result[0].length # ==> 10
p result[2].diameter # ==> 4
