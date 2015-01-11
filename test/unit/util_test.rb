class UtilTest < Minitest::Test
  def test_snake_casing
    assert_equal "foo/bar", Orchestra::Util.to_snake_case("Foo::Bar")
    assert_equal "foo_bar", Orchestra::Util.to_snake_case("FOOBar")
  end
end
