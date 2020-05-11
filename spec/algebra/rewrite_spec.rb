$:.unshift File.expand_path("../..", __FILE__)
require 'spec_helper'
require 'algebra/algebra_helper'
require 'sparql/client'

include SPARQL::Algebra

describe SPARQL::Algebra::Operator do
  let!(:ex) {RDF::Vocabulary.new('http://example.org/')}
  let!(:op) {Operator.new}

  describe "#to_binary" do
    it "raises exception if there are no expressions" do
      expect {op.send(:to_binary, Operator::Union)}.to raise_error("Operator#to_binary requires two or more expressions")
    end

    it "raises exception if there is one expressions" do
      expect(op.send(:to_binary, Operator::Union, Operator::BGP.new)).to eq Operator::BGP.new
    end

    context "with two expressions" do
      subject {op.send(:to_binary, Operator::Union, Operator::BGP.new, Operator::BGP.new)}
      it "returns a Union" do
        is_expected.to be_a(Operator::Union)
      end
      its(:operands) do
        is_expected.to eq [Operator::BGP.new, Operator::BGP.new]
      end
    end

    context "with three expressions" do
      subject {op.send(:to_binary, Operator::Union, Operator::BGP.new, Operator::BGP.new, Operator::BGP.new)}
      it "returns a Union" do
        is_expected.to be_a(Operator::Union)
      end
      its(:operands) do
        is_expected.to eq [Operator::BGP.new, Operator::Union.new(Operator::BGP.new, Operator::BGP.new)]
      end
    end
  end
  
  describe "#rewrite" do
    {
      "Remove BGP" => [
        %q{(prefix ((ex: <http://example.org/>))
             (bgp (triple ex:x1 ex:p2 ex:x2)))},
        %q{(prefix ((ex: <http://example.org/>))
             (bgp))},
      ],
      "Remove Named Graph" => [
        %q{(prefix ((ex: <http://example.org/>))
             (graph <a> (bgp (triple ex:x1 ex:p2 ex:x2))))},
        %q{(prefix ((ex: <http://example.org/>))
             (bgp))},
      ]
    }.each do |name, (given, expected)|
      it name do
        query = SPARQL::Algebra::Expression.parse(given)
        result = SPARQL::Algebra::Expression.parse(expected)
        rewritten = query.send(:rewrite) do |op|
          case op
          when Operator::Graph, RDF::Query
            Operator::BGP.new
          else
            op
          end
        end
        expect(rewritten.to_sxp).to eq result.to_sxp
      end
    end
    
    context "with default datasets" do
    end
    
    context "with named datasets" do
    end
  end
end
