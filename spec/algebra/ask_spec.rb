$:.unshift File.expand_path("../..", __FILE__)
require 'spec_helper'
require 'algebra/algebra_helper'
require 'sparql/client'

include SPARQL::Algebra

describe SPARQL::Algebra::Query do
  EX = RDF::EX = RDF::Vocabulary.new('http://example.org/') unless const_defined?(:EX)

  context "ask" do
    {
      "data-r2/as/ask-1" => [
        %q{
          @prefix :   <http://example/> .
          @prefix xsd:        <http://www.w3.org/2001/XMLSchema#> .

          :x :p "1"^^xsd:integer .
          :x :p "2"^^xsd:integer .
          :x :p "3"^^xsd:integer .

          :y :p :a .
          :a :q :r .
        },
        %q{
          (prefix ((: <http://example/>))
          (ask
            (bgp (triple :x :p 1))))
        },
      ],
    }.each do |example, (source, query)|
      it "passes #{example}" do
        expect(
          sparql_query(
            form: :ask, sse: true,
            graphs: {default: {data: source, format: :ttl}},
            query: query)
        ).to eq RDF::Literal::TRUE
      end

      it "passes #{example} (with optimimzation)" do
        expect(
          sparql_query(
            form: :ask, sse: true, optimize: true,
            graphs: {default: {data: source, format: :ttl}},
            query: query)
        ).to eq RDF::Literal::TRUE
      end
    end
  end
end
