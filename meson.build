project('valafmt', ['c', 'vala'],
          version: '0.1.0',
    meson_version: '>= 1.10.0',
  default_options: [ 'warning_level=2', 'werror=false', ],
)

valac = meson.get_compiler('vala')

tree_sitter_dep = dependency('tree-sitter')

tree_sitter_vala_sub = subproject('tree-sitter-vala', default_options: ['tests=false', 'default_library=static'])
tree_sitter_vala_dep = tree_sitter_vala_sub.get_variable('tree_sitter_vala_dep')

subdir('src')
if get_option('enable_tests')
  subdir('tests')
endif
