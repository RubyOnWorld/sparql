require 'digest'

module SPARQL; module Algebra
  class Operator
    ##
    # The SPARQL logical `sha1` operator.
    #
    # Returns the SHA384 checksum, as a hex digit string, calculated on the UTF-8 representation of the simple literal or lexical form of the `xsd:string`. Hex digits `SHOULD` be in lower case.
    #
    # [121] BuiltInCall ::= ... | 'SHA384' '(' Expression ')' 
    #
    # @example SPARQL Grammar
    #   PREFIX : <http://example.org/>
    #   SELECT (SHA384(?l) AS ?hash) WHERE {
    #    :s1 :str ?l
    #   }
    #
    # @example SSE
    #     (prefix ((: <http://example.org/>))
    #       (project (?hash)
    #         (extend ((?hash (sha384 ?l)))
    #           (bgp (triple :s1 :str ?l)))))
    #
    # @see https://www.w3.org/TR/sparql11-query/#func-sha384
    class SHA384 < Operator::Unary
      include Evaluatable

      NAME = :sha384

      ##
      # Returns the SHA384 checksum, as a hex digit string, calculated on the UTF-8 representation of the simple literal or lexical form of the xsd:string. Hex digits should be in lower case.
      #
      # @param  [RDF::Literal] operand
      #   the operand
      # @return [RDF::Literal]
      # @raise  [TypeError] if the operand is not a simple literal
      def apply(operand, **options)
        raise TypeError, "expected an RDF::Literal, but got #{operand.inspect}" unless operand.literal?
        raise TypeError, "expected simple literal or xsd:string, but got #{operand.inspect}" unless (operand.datatype || RDF::XSD.string) == RDF::XSD.string
        RDF::Literal(Digest::SHA384.new.hexdigest(operand.to_s))
      end

      ##
      #
      # Returns a partial SPARQL grammar for this operator.
      #
      # @return [String]
      def to_sparql(**options)
        "SHA384(" + operands.to_sparql(**options) + ")"
      end
    end # SHA384
  end # Operator
end; end # SPARQL::Algebra
