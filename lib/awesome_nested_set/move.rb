module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      class Move
        attr_reader :target, :position, :instance

        delegate :left, :right, :quoted_left_column_name, :quoted_right_column_name, :quoted_parent_column_name, :parent_column_name, to: :instance

        def initialize(target, position, instance)
          @target = target
          @position = position
          @instance = instance
        end

        def move
          if not_root && !instance.move_possible?(target)
            raise ActiveRecord::ActiveRecordError, "Impossible move, target node cannot be inside moved tree."
          end

          bound, other_bound = get_boundaries

          # there would be no change
          return if bound == right || bound == left

          # we have defined the boundaries of two non-overlapping intervals,
          # so sorting puts both the intervals and their boundaries in order
          a, b, c, d = [left, right, bound, other_bound].sort

          # select the rows in the model between a and d, and apply a lock
          instance.class.base_class.select('id').lock(true).right_of(a).left_of_right_side(d)

          instance.nested_set_scope.where(*where_statement(a,d)).update_all(conditions(a,b,c,d))
        end

        private

        def where_statement(a,d)
          ["(#{quoted_left_column_name} BETWEEN :a AND :d) OR (#{quoted_right_column_name} BETWEEN :a AND :d)", {:a => a, :d => d}]
        end

        def conditions(a,b,c,d)
          [
           "#{quoted_left_column_name} = CASE " +
           "WHEN #{quoted_left_column_name} BETWEEN :a AND :b " +
           "THEN #{quoted_left_column_name} + :d - :b " +
           "WHEN #{quoted_left_column_name} BETWEEN :c AND :d " +
           "THEN #{quoted_left_column_name} + :a - :c " +
           "ELSE #{quoted_left_column_name} END, " +
           "#{quoted_right_column_name} = CASE " +
           "WHEN #{quoted_right_column_name} BETWEEN :a AND :b " +
           "THEN #{quoted_right_column_name} + :d - :b " +
           "WHEN #{quoted_right_column_name} BETWEEN :c AND :d " +
           "THEN #{quoted_right_column_name} + :a - :c " +
           "ELSE #{quoted_right_column_name} END, " +
           "#{quoted_parent_column_name} = CASE " +
           "WHEN #{instance.class.base_class.primary_key} = :id THEN :new_parent " +
           "ELSE #{quoted_parent_column_name} END",
           {:a => a, :b => b, :c => c, :d => d, :id => instance.id, :new_parent => new_parent}
          ]
        end

        def not_root
          position != :root
        end

        def new_parent
          case position
          when :child
            target.id
          else
            target[parent_column_name]
          end
        end

        def get_boundaries
          if (bound = target_bound) > right
            bound -= 1
            other_bound = right + 1
          else
            other_bound = left - 1
          end
          [bound, other_bound]
        end

        def target_bound
          case position
          when :child;  right(target)
          when :left;   left(target)
          when :right;  right(target) + 1
          else raise ActiveRecord::ActiveRecordError, "Position should be :child, :left, :right or :root ('#{position}' received)."
          end
        end
      end
    end
  end
end
