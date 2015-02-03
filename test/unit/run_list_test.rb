class RunListTest < Minitest::Test
  def test_all_are_required
    builder.input_names << :foo

    run_list = builder.build

    assert_equal %w(foo⇒bar bar⇒baz baz⇒qux qux⇒res), run_list.step_names
    assert_includes run_list.dependencies, :foo
  end

  def test_discards_unnecessary_steps
    builder['aba⇒cab'] = OpenStruct.new :required_dependencies => [:aba], :optional_dependencies => [], :provisions => [:cab]

    run_list = builder.build

    assert_equal %w(foo⇒bar bar⇒baz baz⇒qux qux⇒res), run_list.step_names
  end

  def test_does_not_discard_steps_that_would_override_defaults
    steps = {
      'foo' => OpenStruct.new(
        :optional_dependencies => [],
        :required_dependencies => [:bar],
        :provisions => [:baz],
      ),
      'qux' => OpenStruct.new(
        :optional_dependencies => [:baz],
        :required_dependencies => [],
        :provisions => [:res],
      ),
    }
    builder = assemble_builder steps
    builder.input_names.concat [:bar]

    builder.sort!
    builder.prune!
    run_list = builder.build

    assert_equal %w(foo qux), run_list.step_names
  end

  def test_supplying_dependencies
    builder.input_names << :baz

    run_list = builder.build

    assert_equal %w(baz⇒qux qux⇒res), run_list.step_names
    refute_includes run_list.dependencies, :foo
  end

  def test_steps_that_modify
    assemble_builder modifying_steps

    run_list = builder.build

    assert_equal %w(foo bar baz), run_list.step_names
  end

  def test_reorders_optional_deps_before_mandatory_deps_when_possible
    assemble_builder order_changes_because_of_optional_deps

    run_list = builder.build

    assert_equal %w(baz+foo bar+baz foo+bar final), run_list.step_names
    assert_equal [], run_list.required_dependencies
    assert_equal [:bar, :baz, :foo], run_list.optional_dependencies
  end

  def test_wrap_tsort_cycle_errors
    assemble_builder circular_dependency_tree

    error = assert_raises Orchestra::CircularDependencyError do
      builder.build
    end

    assert_equal(
      "Circular dependency detected! Check your dependencies/provides",
      error.message
    )
  end

  def test_evaluates_runlist_for_embedded_operations_before_outer_operation
    inner_operation = Orchestra::Operation.new do
      step :unnecessary do
        depends_on :bar
        provides :baz
        execute do foo end
      end

      result :short_circut_me do
        depends_on :baz
        provides :qux
        execute do foo * 2 end
      end
    end

    outer_steps = {
      'nooooOOOoo' => OpenStruct.new(
        :required_dependencies => [:foo],
        :provisions            => [:bar],
        :optional_dependencies => [],
      ),
      'embedded' => inner_operation,
    }

    run_list = Orchestra::RunList.build outer_steps, :qux, [:baz]
    assert_equal ['embedded'], run_list.step_names
  end

  private

  def assemble_builder steps = default_steps
    @builder ||= begin
      builder = Orchestra::RunList::Builder.new :res
      builder.merge! steps
      builder
    end
  end
  alias_method :builder, :assemble_builder

  def default_steps
    {
      'foo⇒bar' => OpenStruct.new(:required_dependencies => [:foo], :provisions => [:bar], optional_dependencies: []),
      'bar⇒baz' => OpenStruct.new(:required_dependencies => [:bar], :provisions => [:baz], optional_dependencies: []),
      'baz⇒qux' => OpenStruct.new(:required_dependencies => [:baz], :provisions => [:qux], optional_dependencies: []),
      'qux⇒res' => OpenStruct.new(:required_dependencies => [:qux], :provisions => [:res], optional_dependencies: []),
    }
  end

  def modifying_steps
    {
      'foo' => OpenStruct.new(:required_dependencies => [:shared], :provisions => [:shared], optional_dependencies: []),
      'bar' => OpenStruct.new(:required_dependencies => [:shared], :provisions => [:shared], optional_dependencies: []),
      'baz' => OpenStruct.new(:required_dependencies => [:shared], :provisions => [:shared, :res], optional_dependencies: []),
    }
  end

  def circular_dependency_tree
    {
      'foo+bar' => OpenStruct.new(
        :optional_dependencies => [:bar],
        :required_dependencies => [:foo],
        :provisions => [:aba]
      ),
      'bar+baz' => OpenStruct.new(
        :optional_dependencies => [:foo],
        :required_dependencies => [:bar],
        :provisions => [:cab],
      ),
      'final'   => OpenStruct.new(
        :optional_dependencies => [],
        :required_dependencies => [:aba, :cab],
        :provisions => [:res],
      )
    }
  end

  def order_changes_because_of_optional_deps
    {
      'foo+bar' => OpenStruct.new(
        :optional_dependencies => [],
        :required_dependencies => [:foo, :bar],
        :provisions => [:aba]
      ),
      'bar+baz' => OpenStruct.new(
        :optional_dependencies => [:bar],
        :required_dependencies => [:baz],
        :provisions => [:cab],
      ),
      'baz+foo' => OpenStruct.new(
        :optional_dependencies => [:baz, :foo],
        :required_dependencies => [],
        :provisions => [:bra],
      ),
      'final'   => OpenStruct.new(
        :optional_dependencies => [],
        :required_dependencies => [:aba, :cab, :bra],
        :provisions => [:res],
      ),
    }
  end
end
