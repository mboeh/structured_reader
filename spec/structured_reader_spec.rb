require "spec_helper"

RSpec.describe StructuredReader do
  it "has a version number" do
    expect(StructuredReader::VERSION).not_to be nil
  end

  context ".json" do

    def reader(&blk)
      StructuredReader.json(&blk)
    end

    it "raises an exception if the declaration is empty" do
      object = {}
      expect{
        reader{}.read(object)
      }.to raise_error(StructuredReader::DeclarationError)
    end

    context "reading an object" do

      it "can read a nil" do
        object = { nul: nil }
        result = reader do |o|
          o.null :nul
        end.read(object)

        expect(result.nul).to be nil
      end

      it "can read a nullable field" do
        object = { str: nil }
        result = reader do |o|
          o.string :str, nullable: true
        end.read(object)

        expect(result.str).to be nil
      end

      it "can read a string" do
        object = { str: "bar" }
        result = reader do |o|
          o.string :str
        end.read(object)

        expect(result.str).to eq("bar")
      end

      it "can read an integer" do
        object = { num: 1 }
        result = reader do |o|
          o.number :num
        end.read(object)

        expect(result.num).to eq(1)
      end

      it "can read a float" do
        object = { num: 1.0 }
        result = reader do |o|
          o.number :num
        end.read(object)

        expect(result.num).to eq(1.0)
      end

      it "can read an array" do
        object = { ary: ["foo", "bar", "baz"] }
        result = reader do |o|
          o.array :ary do |a|
            a.string
          end
        end.read(object)

        expect(result.ary).to eq(["foo", "bar", "baz"])
      end

      it "can read a collection" do
        object = { coll: [{ foo: "bar" }] }
        result = reader do |o|
          o.collection :coll do |a|
            a.string :foo
          end
        end.read(object)

        expect(result.coll[0].foo).to eq("bar")
      end

      it "can read a nested object" do
        object = { obj: { foo: "bar" } }
        result = reader do |o|
          o.object :obj do |o2|
            o2.string :foo
          end
        end.read(object)

        expect(result.obj.foo).to eq("bar")
      end

      it "can enforce a strict set of fields" do
        rdr = reader do |o|
          o.object :obj, strict: true do |obj|
            obj.string :foo
          end
        end

        result = rdr.read({obj: {foo: "bar"}})

        expect(result.obj.foo).to eq("bar")

        expect{
          rdr.read({obj: {foo: "bar", baz: "bat"}})
        }.to raise_error(StructuredReader::WrongTypeError)
      end

    end

    context "reading an array" do

      it "can read an array of strings" do
        object = { ary: ["foo", "bar", "baz"] }
        result = reader do |o|
          o.array :ary, of: :string
        end.read(object)

        expect(result.ary).to eq(["foo", "bar", "baz"])
      end

      it "can read an array of objects" do
        object = { ary: [{ foo: "bar" }] }
        result = reader do |o|
          o.array :ary do |a|
            a.object do |o2|
              o2.string :foo
            end
          end
        end.read(object)

        expect(result.ary[0].foo).to eq("bar")
      end

    end

    context "reading a raw value" do

      it "returns the literal, unmodified value" do
        object = { raw: [ { yep: 1 }, { what_of_it: ["woot"] }, true ] }
        result = reader do |o|
          o.raw :raw
        end.read(object)

        expect(result.raw).to eq(object[:raw])
      end

    end

    context "reading a literal value" do

      it "returns the literal, unmodified value if it matches the provided value" do
        object = { lit: "yes" }
        result = reader do |o|
          o.literal :lit, value: "yes"
        end.read(object)

        expect(result.lit).to eq("yes")
      end

      it "rejects any other value" do
        object = { lit: "no" }

        expect{
          reader do |o|
            o.literal :lit, value: "yes"
          end.read(object)
        }.to raise_error(StructuredReader::WrongTypeError)
      end

    end

    context "reading any_of" do

      it "raises an exception if no options are provided" do
        expect{
          reader do |o|

          end.read({})
        }.to raise_error(StructuredReader::DeclarationError)
      end

      it "accepts any of the declared options" do
        rdr = reader do |o|
          o.one_of :vary do |v|
            v.string
            v.number
            v.array of: :string
          end
        end

        expect(
          rdr.read({vary: "foo"}).vary
        ).to eq("foo")
        expect(
          rdr.read({vary: 1}).vary
        ).to eq(1)
        expect(
          rdr.read({vary: ["hi", "there"]}).vary
        ).to eq(["hi", "there"])
      end

      it "rejects undeclared options" do
        rdr = reader do |o|
          o.one_of :vary do |v|
            v.string
          end
        end

        expect{
          rdr.read({vary: 1})
        }.to raise_error(StructuredReader::WrongTypeError)
      end

    end

    context "reading a discriminated union" do

      it "works" do
        object = {
          shapes: [
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
        }
        rdr = reader do |o|
          o.array :shapes do |a|
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
        end

        result = rdr.read(object)

        expect(result.shapes.length).to eq(3)
        expect(result.shapes[0].type).to eq("square")
        expect(result.shapes[0].length).to eq(10)
        expect(result.shapes[1].width).to eq(5)
        expect(result.shapes[2].diameter).to eq(4)
      end

    end

  end
end
