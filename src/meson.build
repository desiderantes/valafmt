version_conf = configuration_data()
version_conf.set('VERSION', meson.project_version())
version_vala = configure_file(
  input: 'config.vala.in',
  output: 'config.vala',
  configuration: version_conf,
)

valafmt_core_sources = files(
  'engine/config.vala',
  'engine/formatting_engine.vala',
  'cst/cst_helpers.vala',
  'cst/cst_comment_formatter.vala',
  'cst/cst_width_measurer.vala',
  'cst/cst_layout_context.vala',
  'cst/cst_type_formatter.vala',
  'cst/cst_declaration_formatter.vala',
  'cst/cst_statement_formatter.vala',
  'cst/cst_expression_formatter.vala',
  'cst/cst_pretty_printer.vala',
  'linter/linter.vala',
) + [version_vala]

valafmt_deps = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  tree_sitter_vala_dep,
]

valafmt_core_lib = static_library('valafmt_core', valafmt_core_sources,
  vala_args: ['--target-glib=2.58', '--enable-experimental'],
  dependencies: valafmt_deps,
  install: false,
)

valafmt_core_dep = declare_dependency(
  link_with: valafmt_core_lib,
  dependencies: valafmt_deps,
  include_directories: include_directories('.'),
)

valafmt_bin = executable('valafmt', files('main.vala'),
  vala_args: ['--target-glib=2.58', '--enable-experimental'],
  dependencies: [valafmt_core_dep],
  install: true,
)
