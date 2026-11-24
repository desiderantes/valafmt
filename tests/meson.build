test_deps = [
  valafmt_core_dep,
  dependency('gio-2.0'),
]

test_vala_args = ['--target-glib=2.58', '--enable-experimental']

test_support_lib = static_library('valafmt_test_support',
  files('test_support.vala'),
  vala_args: test_vala_args,
  dependencies: test_deps,
  install: false,
)

test_support_dep = declare_dependency(
  link_with: test_support_lib,
  dependencies: test_deps,
  include_directories: include_directories('.'),
)

golden_checker_exe = executable('check_golden',
  files('check_golden.vala'),
  vala_args: test_vala_args,
  dependencies: [test_support_dep],
  install: false,
)

fixtures = [
  'indent',
  'max_len',
  'no_trailing_spaces',
  'eol_last',
  'no_multiple_empty_lines',
  'continuation_indent',
  'brace_style',
  'cuddled_else_catch',
  'space_before_blocks',
  'no_padded_blocks',
  'curly',
  'space_keyword',
  'switch_case_indent',
  'try_catch',
  'space_before_function_paren',
  'no_spaces_inside_paren',
  'comma_spacing',
  'closing_paren_newline',
  'method_chain_newline',
  'semi',
  'one_var_per_declaration',
  'type_clause_wrap',
  'space_infix_ops',
  'space_unary_ops',
  'cast_spacing',
  'owned_unowned_space',
  'property_body_newline',
  'object_property_newline',
  'nullable_type_spacing',
  'enum_value_newline',
  'attribute_placement',
  'throws_space',
  'control_flow',
  'modifier_order',
  'generics',
  'class_modifiers',
  'showcase',
  'error_domain',
]

foreach fixture_name : fixtures
  input_file = files('fixtures' / fixture_name / 'input.vala')
  expected_file = files('fixtures' / fixture_name / 'expected.vala')

  test(fixture_name, golden_checker_exe,
    args: ['--tap', valafmt_bin.full_path(), input_file, expected_file],
    protocol: 'tap',
    depends: [valafmt_bin],
  )
endforeach

test_suites = {
  'cli_integration': 'test_cli.vala',
  'linter_integration': 'test_linter.vala',
  'cst_regressions': 'test_regressions.vala',
  'performance_smoke': 'test_performance.vala',
  'concurrency_smoke': 'test_concurrency.vala',
  'idempotency_sampler': 'test_idempotency_sampler.vala',
  'comment_matrix': 'test_comment_matrix.vala',
}

test_env = [
  'VALAFMT_BIN=' + valafmt_bin.full_path(),
  'VALAFMT_FIXTURES_DIR=' + (meson.current_source_dir() / 'fixtures'),
]

foreach suite_name, suite_src : test_suites
  suite_exe = executable('run_' + suite_name,
    files(suite_src),
    vala_args: test_vala_args,
    dependencies: [test_support_dep],
    install: false,
  )

  test(suite_name, suite_exe,
    args: ['--tap'],
    protocol: 'tap',
    env: test_env,
    depends: [valafmt_bin],
  )
endforeach
