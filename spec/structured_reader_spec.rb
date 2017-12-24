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

  end
end
