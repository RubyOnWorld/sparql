module SPARQL; module Algebra
  class Operator
    ##
    # The SPARQL logical `lcase` operator.
    #
    # [121] BuiltInCall ::= ... | 'LCASE' '(' Expression ')' 
    #
    # @example SPARQL Grammar
    #   PREFIX : <http://example.org/>
    #   SELECT ?s (LCASE(?str) AS ?lstr) WHERE {
    #     ?s :str ?str
    #   }
    #
    # @example SSE
    #   (prefix ((: <http://example.org/>))
    #    (project (?s ?lstr)
    #     (extend ((?lstr (lcase ?str)))
    #      (bgp (triple ?s :str ?str)))))
    #
    # @see https://www.w3.org/TR/sparql11-query/#func-lcase
    # @see https://www.w3.org/TR/xpath-functions/#func-lcase
    class LCase < Operator::Unary
      include Evaluatable

      NAME = :lcase

      ##
      # The LCASE function corresponds to the XPath fn:lower-case function. It returns a string literal whose lexical form is the lower case of the lexcial form of the argument.
      #
      # @param  [RDF::Literal] operand
      #   the operand
      # @return [RDF::Literal] literal of same type
      # @raise  [TypeError] if the operand is not a literal value
      def apply(operand, **options)
        case operand
          when RDF::Literal then RDF::Literal(operand.to_s.downcase, datatype: operand.datatype, language: operand.language)
          else raise TypeError, "expected an RDF::Literal::Numeric, but got #{operand.inspect}"
        end
      end

      ##
      #
      # Returns a partial SPARQL grammar for this operator.
      #
      # @return [String]
      def to_sparql(**options)
        "LCASE(" + operands.last.to_sparql(**options) + ")"
      end
    end # LCase
  end # Operator
end; end # SPARQL::Algebra
