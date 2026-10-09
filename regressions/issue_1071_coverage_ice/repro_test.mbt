///|
test "issue 1071 non-unit main method" {
  assert_eq(@issue_1071_coverage_ice.CoverageIssue1071::main(), "dummy")
}
