module SPARQL; module Algebra
  class Operator
    ##
    # The SPARQL `bound` operator.
    #
    # [121] BuiltInCall ::= ... | 'BOUND' '(' Var ')' 
    #
    # @example SPARQL Grammar
    #   PREFIX  : <http://example.org/ns#>
    #   SELECT  ?a ?c
    #   WHERE
    #       { ?a :b ?c . 
    #         OPTIONAL
    #           { ?c :d ?e } . 
    #         FILTER (! bound(?e)) 
    #       }
    #
    # @example SSE
    #   (prefix ((: <http://example.org/ns#>))
    #     (project (?a ?c)
    #       (filter (! (bound ?e))
    #         (leftjoin
    #           (bgp (triple ?a :b ?c))
    #           (bgp (triple ?c :d ?e))))))
    #
    # @see https://www.w3.org/TR/sparql11-query/#func-bound
    class Bound < Operator::Unary
      include Evaluatable

      NAME = :bound

      ##
      # Initializes a new operator instance.
      #
      # @param  [RDF::Query::Variable] var
      #   a variable
      # @param  [Hash{Symbol => Object}] options
      #   any additional options (see {Operator#initialize})
      # @raise  [TypeError] if any operand is invalid
      def initialize(var, **options)
        super
      end

      ##
      # Returns `true` if `var` is bound to a value. Returns false otherwise. Variables with the value NaN or INF are considered bound.
      #
      # @param  [RDF::Query::Solution] bindings
      #   a query solution containing zero or more variable bindings
      # @param [Hash{Symbol => Object}] options ({})
      #   options passed from query
      # @return [RDF::Literal::Boolean] `true` or `false`
      # @raise  [TypeError] if the operand is not a variable
      def evaluate(bindings, **options)
        case var = operand
          when Variable
            bindings.respond_to?(:bound?) && bindings.bound?(var) ?
              RDF::Literal::TRUE : RDF::Literal::FALSE
          else raise TypeError, "expected an RDF::Query::Variable, but got #{var.inspect}"
        end
      end

      ##
      #
      # Returns a partial SPARQL grammar for this operator.
      #
      # @return [String]
      def to_sparql(**options)
        "bound(" + operands.first.to_sparql(**options) + ")"
      end
    end # Bound
  end # Operator
end; end # SPARQL::Algebra
